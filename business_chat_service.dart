import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_model.dart';
import '../models/business_model.dart' as business_model;
import '../models/user_model.dart' as user_model;

class BusinessChatService {
  static final BusinessChatService _instance = BusinessChatService._internal();
  factory BusinessChatService() => _instance;
  BusinessChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Streams para actualizaciones en tiempo real
  Stream<List<BusinessChatConversation>> getCustomerConversations(String customerId) {
    return _firestore
        .collection('business_chats')
        .where('customerId', isEqualTo: customerId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BusinessChatConversation.fromMap(doc.data()))
            .toList());
  }

  Stream<List<BusinessChatConversation>> getBusinessConversations(String businessId) {
    return _firestore
        .collection('business_chats')
        .where('businessId', isEqualTo: businessId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BusinessChatConversation.fromMap(doc.data()))
            .toList());
  }

  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('chat_messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()))
            .toList());
  }

  Stream<TypingIndicator?> getTypingIndicator(String conversationId) {
    return _firestore
        .collection('typing_indicators')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return TypingIndicator.fromMap(snapshot.data()!);
        });
  }

  // Crear o obtener conversación
  Future<BusinessChatConversation> getOrCreateConversation(
    String customerId,
    String businessId,
  ) async {
    try {
      // Buscar conversación existente
      final existingSnapshot = await _firestore
          .collection('business_chats')
          .where('customerId', isEqualTo: customerId)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isNotEmpty) {
        return BusinessChatConversation.fromMap(existingSnapshot.docs.first.data());
      }

      // Obtener información del cliente y negocio
      final customerDoc = await _firestore.collection('users').doc(customerId).get();
      final businessDoc = await _firestore.collection('businesses').doc(businessId).get();

      if (!customerDoc.exists || !businessDoc.exists) {
        throw Exception('Cliente o negocio no encontrado');
      }

      final customerData = customerDoc.data()!;
      final businessData = businessDoc.data()!;

      // Crear nueva conversación
      final conversation = BusinessChatConversation(
        id: _firestore.collection('business_chats').doc().id,
        customerId: customerId,
        customerName: customerData['name'] ?? 'Cliente',
        customerAvatar: customerData['avatar'] ?? '',
        businessId: businessId,
        businessName: businessData['name'] ?? 'Negocio',
        businessLogo: businessData['logo'] ?? '',
        lastMessageTime: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('business_chats')
          .doc(conversation.id)
          .set(conversation.toMap());

      return conversation;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  // Enviar mensaje
  Future<ChatMessage> sendMessage({
    required String conversationId,
    required String content,
    required String senderId,
    required String senderName,
    required String senderType,
    MessageType type = MessageType.text,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final message = ChatMessage(
        id: _firestore.collection('chat_messages').doc().id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderType: senderType,
        message: content,
        timestamp: DateTime.now(),
        type: type,
        imageUrl: imageUrl,
        metadata: metadata,
      );

      // Guardar mensaje
      await _firestore
          .collection('chat_messages')
          .doc(message.id)
          .set(message.toMap());

      // Actualizar conversación
      await _updateConversationLastMessage(conversationId, content, DateTime.now());

      // Enviar notificación push
      await _sendNotification(conversationId, message);

      return message;
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String conversationId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chat_messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('senderId', isNotEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Actualizar contador de no leídos en conversación
      await _updateUnreadCount(conversationId, 0);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Indicador de escritura
  Future<void> setTypingIndicator({
    required String conversationId,
    required String userId,
    required String userName,
    required String userType,
    required bool isTyping,
  }) async {
    try {
      final indicator = TypingIndicator(
        conversationId: conversationId,
        userId: userId,
        userName: userName,
        userType: userType,
        isTyping: isTyping,
        timestamp: DateTime.now(),
      );

      if (isTyping) {
        await _firestore
            .collection('typing_indicators')
            .doc(conversationId)
            .set(indicator.toMap());

        // Auto-eliminar después de 3 segundos
        Timer(const Duration(seconds: 3), () {
          _firestore
              .collection('typing_indicators')
              .doc(conversationId)
              .delete();
        });
      } else {
        await _firestore
            .collection('typing_indicators')
            .doc(conversationId)
            .delete();
      }
    } catch (e) {
      print('Error setting typing indicator: $e');
    }
  }

  // Actualizar estado en línea del usuario
  Future<void> updateUserOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('chat_users').doc(userId).set({
        'id': userId,
        'isOnline': isOnline,
        'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  // Obtener estado en línea de usuario
  Stream<ChatUser?> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('chat_users')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          return ChatUser.fromMap(snapshot.data()!);
        });
  }

  // Eliminar conversación
  Future<void> deleteConversation(String conversationId) async {
    try {
      final batch = _firestore.batch();

      // Eliminar mensajes
      final messages = await _firestore
          .collection('chat_messages')
          .where('conversationId', isEqualTo: conversationId)
          .get();

      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }

      // Eliminar conversación
      batch.delete(
          _firestore.collection('business_chats').doc(conversationId));

      // Eliminar indicador de escritura
      batch.delete(
          _firestore.collection('typing_indicators').doc(conversationId));

      await batch.commit();
    } catch (e) {
      print('Error deleting conversation: $e');
    }
  }

  // Archivar conversación
  Future<void> archiveConversation(String conversationId) async {
    try {
      await _firestore
          .collection('business_chats')
          .doc(conversationId)
          .update({'isActive': false});
    } catch (e) {
      print('Error archiving conversation: $e');
    }
  }

  // Métodos privados
  Future<void> _updateConversationLastMessage(
    String conversationId,
    String lastMessage,
    DateTime timestamp,
  ) async {
    try {
      await _firestore
          .collection('business_chats')
          .doc(conversationId)
          .update({
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(timestamp),
      });
    } catch (e) {
      print('Error updating conversation: $e');
    }
  }

  Future<void> _updateUnreadCount(String conversationId, int count) async {
    try {
      await _firestore
          .collection('business_chats')
          .doc(conversationId)
          .update({'unreadCount': count});
    } catch (e) {
      print('Error updating unread count: $e');
    }
  }

  Future<void> _sendNotification(String conversationId, ChatMessage message) async {
    try {
      // Obtener detalles de la conversación
      final conversationDoc = await _firestore
          .collection('business_chats')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) return;

      final conversation = BusinessChatConversation.fromMap(conversationDoc.data()!);

      // Determinar destinatario
      String recipientId;
      String recipientName;
      String recipientType;

      if (message.senderType == 'customer') {
        recipientId = conversation.businessId;
        recipientName = conversation.businessName;
        recipientType = 'business';
      } else {
        recipientId = conversation.customerId;
        recipientName = conversation.customerName;
        recipientType = 'customer';
      }

      // Incrementar contador de no leídos
      if (message.senderType != recipientType) {
        final currentDoc = await _firestore
            .collection('business_chats')
            .doc(conversationId)
            .get();
        
        final currentData = currentDoc.data()!;
        final currentUnread = currentData['unreadCount'] ?? 0;
        
        await _updateUnreadCount(conversationId, currentUnread + 1);
      }

      // Crear notificación
      final notification = {
        'id': _firestore.collection('notifications').doc().id,
        'userId': recipientId,
        'title': 'Nuevo mensaje de ${message.senderName}',
        'body': message.message,
        'type': 'chat_message',
        'data': {
          'conversationId': conversationId,
          'senderId': message.senderId,
          'senderName': message.senderName,
          'senderType': message.senderType,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      await _firestore.collection('notifications').add(notification);

      // Aquí se integraría con Firebase Cloud Messaging
      // para enviar notificaciones push
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Obtener estadísticas de chat
  Future<Map<String, dynamic>> getChatStats(String userId, String userType) async {
    try {
      QuerySnapshot conversations;

      if (userType == 'customer') {
        conversations = await _firestore
            .collection('business_chats')
            .where('customerId', isEqualTo: userId)
            .get();
      } else {
        conversations = await _firestore
            .collection('business_chats')
            .where('businessId', isEqualTo: userId)
            .get();
      }

      final totalConversations = conversations.docs.length;
      final activeConversations = conversations.docs
          .where((doc) => doc['isActive'] == true)
          .length;
      
      int totalMessages = 0;
      int totalUnread = 0;

      for (final doc in conversations.docs) {
        final messages = await _firestore
            .collection('chat_messages')
            .where('conversationId', isEqualTo: doc.id)
            .get();
        
        totalMessages += messages.docs.length;
        totalUnread += (doc['unreadCount'] as int?) ?? 0;
      }

      return {
        'totalConversations': totalConversations,
        'activeConversations': activeConversations,
        'totalMessages': totalMessages,
        'totalUnread': totalUnread,
        'averageMessagesPerConversation': totalConversations > 0 
            ? (totalMessages / totalConversations).round() 
            : 0,
      };
    } catch (e) {
      print('Error getting chat stats: $e');
      return {};
    }
  }

  // Buscar conversaciones
  Future<List<BusinessChatConversation>> searchConversations(
    String userId,
    String userType,
    String query,
  ) async {
    try {
      QuerySnapshot conversations;

      if (userType == 'customer') {
        conversations = await _firestore
            .collection('business_chats')
            .where('customerId', isEqualTo: userId)
            .get();
      } else {
        conversations = await _firestore
            .collection('business_chats')
            .where('businessId', isEqualTo: userId)
            .get();
      }

      final results = <BusinessChatConversation>[];
      final lowerQuery = query.toLowerCase();

      for (final doc in conversations.docs) {
        final conversation = BusinessChatConversation.fromMap(doc.data() as Map<String, dynamic>);
        
        if (conversation.businessName.toLowerCase().contains(lowerQuery) ||
            conversation.customerName.toLowerCase().contains(lowerQuery) ||
            (conversation.lastMessage?.toLowerCase().contains(lowerQuery) ?? false)) {
          results.add(conversation);
        }
      }

      return results;
    } catch (e) {
      print('Error searching conversations: $e');
      return [];
    }
  }

  // Obtener conversaciones con mensajes no leídos
  Future<List<BusinessChatConversation>> getUnreadConversations(
    String userId,
    String userType,
  ) async {
    try {
      QuerySnapshot conversations;

      if (userType == 'customer') {
        conversations = await _firestore
            .collection('business_chats')
            .where('customerId', isEqualTo: userId)
            .where('unreadCount', isGreaterThan: 0)
            .orderBy('lastMessageTime', descending: true)
            .get();
      } else {
        conversations = await _firestore
            .collection('business_chats')
            .where('businessId', isEqualTo: userId)
            .where('unreadCount', isGreaterThan: 0)
            .orderBy('lastMessageTime', descending: true)
            .get();
      }

      return conversations.docs
          .map((doc) => BusinessChatConversation.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting unread conversations: $e');
      return [];
    }
  }
}
