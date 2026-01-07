// ============================================================================
// services/chat_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import 'notification_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear o obtener conversación existente
  Future<ChatConversation> getOrCreateConversation({
    required String userId,
    required String userName,
    required String userEmail,
  }) async {
    try {
      // Buscar conversación abierta existente
      final querySnapshot = await _firestore
          .collection('support_conversations')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Ya existe una conversación abierta
        return ChatConversation.fromMap(querySnapshot.docs.first.data());
      }

      // Crear nueva conversación
      final conversationId = _firestore.collection('support_conversations').doc().id;
      
      final conversation = ChatConversation(
        id: conversationId,
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        status: 'open',
        createdAt: DateTime.now(),
        category: 'general',
      );

      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .set(conversation.toMap());

      // Enviar mensaje automático de bienvenida
      await sendMessage(
        conversationId: conversationId,
        senderId: 'system',
        senderName: 'Equipo de Soporte',
        senderType: 'support',
        message: '¡Hola! Gracias por contactarnos. ¿En qué podemos ayudarte?',
      );

      return conversation;
    } catch (e) {
      print('Error al crear conversación: $e');
      throw Exception('No se pudo crear la conversación');
    }
  }

  // Enviar un mensaje
  Future<bool> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String senderType,
    required String message,
    String? imageUrl,
  }) async {
    try {
      final messageId = _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .collection('messages')
          .doc()
          .id;

      final chatMessage = ChatMessage(
        id: messageId,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderType: senderType,
        message: message,
        timestamp: DateTime.now(),
        imageUrl: imageUrl,
      );

      // Guardar mensaje
      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .collection('messages')
          .doc(messageId)
          .set(chatMessage.toMap());

      // Actualizar último mensaje de la conversación
      final updateData = {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': message,
      };

      // Si el mensaje es del soporte, incrementar contador de no leídos del usuario
      if (senderType == 'support') {
        updateData['unreadCount'] = FieldValue.increment(1);
        
        // Obtener información de la conversación para enviar notificación
        final conversationDoc = await _firestore
            .collection('support_conversations')
            .doc(conversationId)
            .get();
        
        if (conversationDoc.exists) {
          final conversation = ChatConversation.fromMap(conversationDoc.data()!);
          
          // Obtener el token FCM del usuario
          final userDoc = await _firestore
              .collection('users')
              .doc(conversation.userId)
              .get();
          
          if (userDoc.exists) {
            final fcmToken = userDoc.data()?['fcmToken'];
            
            if (fcmToken != null) {
              // Enviar notificación push
              await _sendPushNotification(
                token: fcmToken,
                title: senderName,
                body: message,
                conversationId: conversationId,
              );
            }
          }
        }
      }

      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .update(updateData);

      return true;
    } catch (e) {
      print('Error al enviar mensaje: $e');
      return false;
    }
  }

  // Enviar notificación push
  Future<void> _sendPushNotification({
    required String token,
    required String title,
    required String body,
    required String conversationId,
  }) async {
    try {
      // Aquí usarías Firebase Cloud Functions o un servidor para enviar la notificación
      // Por ahora, guardaremos en una colección para que Cloud Functions lo procese
      await _firestore.collection('notifications_queue').add({
        'token': token,
        'title': title,
        'body': body,
        'data': {
          'type': 'chat_message',
          'conversationId': conversationId,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'processed': false,
      });
    } catch (e) {
      print('Error al encolar notificación: $e');
    }
  }

  // Obtener mensajes de una conversación
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    return _firestore
        .collection('support_conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener conversación por ID
  Stream<ChatConversation?> getConversation(String conversationId) {
    return _firestore
        .collection('support_conversations')
        .doc(conversationId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return ChatConversation.fromMap(snapshot.data()!);
    });
  }

  // Obtener todas las conversaciones del usuario
  Stream<List<ChatConversation>> getUserConversations(String userId) {
    return _firestore
        .collection('support_conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatConversation.fromMap(doc.data()))
          .toList();
    });
  }

  // Marcar mensajes como leídos
  Future<void> markAsRead(String conversationId, String userId) async {
    try {
      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .update({
        'unreadCount': 0,
      });

      // Marcar todos los mensajes del soporte como leídos
      final messagesSnapshot = await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderType', isEqualTo: 'support')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error al marcar como leído: $e');
    }
  }

  // Cerrar conversación
  Future<void> closeConversation(String conversationId) async {
    try {
      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .update({
        'status': 'closed',
      });
    } catch (e) {
      print('Error al cerrar conversación: $e');
    }
  }

  // Reabrir conversación
  Future<void> reopenConversation(String conversationId) async {
    try {
      await _firestore
          .collection('support_conversations')
          .doc(conversationId)
          .update({
        'status': 'open',
      });
    } catch (e) {
      print('Error al reabrir conversación: $e');
    }
  }

  // Obtener cantidad de mensajes no leídos
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('support_conversations')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .get();

      int total = 0;
      for (var doc in snapshot.docs) {
        final conversation = ChatConversation.fromMap(doc.data());
        total += conversation.unreadCount;
      }
      return total;
    } catch (e) {
      print('Error al contar no leídos: $e');
      return 0;
    }
  }
}