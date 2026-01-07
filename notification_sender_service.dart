// ============================================================================
// services/notification_sender_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSenderService {
  static final NotificationSenderService _instance = NotificationSenderService._internal();
  factory NotificationSenderService() => _instance;
  NotificationSenderService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Envía una notificación de actualización de estado de pedido
  Future<void> sendOrderStatusNotification({
    required String orderId,
    required String userId,
    required String businessName,
    required String status,
    String? customMessage,
  }) async {
    try {
      // Obtener el token FCM del usuario
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ Usuario no encontrado: $userId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final String? fcmToken = userData['fcmToken'];
      
      if (fcmToken == null) {
        print('❌ Usuario no tiene token FCM: $userId');
        return;
      }

      // Verificar si el usuario tiene activadas las notificaciones de pedidos
      final preferences = userData['notificationPreferences'] as Map<String, dynamic>?;
      if (preferences != null && !(preferences['order_updates'] ?? true)) {
        print('🔕 Usuario tiene desactivadas las notificaciones de pedidos');
        return;
      }

      // Crear el payload de la notificación
      final Map<String, dynamic> notificationData = {
        'title': _getOrderNotificationTitle(status),
        'body': customMessage ?? _getOrderNotificationMessage(status, businessName),
        'data': {
          'type': 'order_update',
          'orderId': orderId,
          'status': status,
          'businessName': businessName,
          'userId': userId,
        },
        'sound': 'default',
        'priority': 'high',
      };

      // Guardar la notificación en Firestore para histórico
      await _saveNotificationToHistory(
        userId: userId,
        type: 'order_update',
        title: notificationData['title'],
        body: notificationData['body'],
        data: notificationData['data'],
      );

      // Enviar la notificación (esto normalmente se haría en Cloud Functions)
      await _sendPushNotification(fcmToken, notificationData);
      
      print('✅ Notificación de estado de pedido enviada: $orderId - $status');
    } catch (e) {
      print('❌ Error al enviar notificación de pedido: $e');
    }
  }

  /// Envía una notificación de promoción
  Future<void> sendPromotionNotification({
    required String promotionId,
    required String businessId,
    required String title,
    required String description,
    required String businessName,
    List<String>? targetUserIds, // Si es null, se envía a todos los usuarios
  }) async {
    try {
      List<String> userIdsToSend = [];
      
      if (targetUserIds != null) {
        // Enviar a usuarios específicos
        userIdsToSend = targetUserIds;
      } else {
        // Enviar a todos los usuarios que tienen activadas las promociones
        userIdsToSend = await _getUsersWithPromotionPreferences();
      }

      for (final userId in userIdsToSend) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;
        final String? fcmToken = userData['fcmToken'];
        
        if (fcmToken == null) continue;

        // Verificar preferencias
        final preferences = userData['notificationPreferences'] as Map<String, dynamic>?;
        if (preferences != null && !(preferences['promotions'] ?? true)) {
          continue;
        }

        final Map<String, dynamic> notificationData = {
          'title': '🎁 $title',
          'body': '$businessName: $description',
          'data': {
            'type': 'promotion',
            'promotionId': promotionId,
            'businessId': businessId,
            'businessName': businessName,
            'title': title,
          },
          'sound': 'default',
          'priority': 'medium',
        };

        // Guardar en histórico
        await _saveNotificationToHistory(
          userId: userId,
          type: 'promotion',
          title: notificationData['title'],
          body: notificationData['body'],
          data: notificationData['data'],
        );

        // Enviar notificación
        await _sendPushNotification(fcmToken, notificationData);
      }
      
      print('✅ Notificación de promoción enviada a ${userIdsToSend.length} usuarios');
    } catch (e) {
      print('❌ Error al enviar notificación de promoción: $e');
    }
  }

  /// Envía una notificación de chat
  Future<void> sendChatNotification({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String message,
    required String senderName,
  }) async {
    try {
      // Obtener información del receptor
      final receiverDoc = await _firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        print('❌ Receptor no encontrado: $receiverId');
        return;
      }

      final receiverData = receiverDoc.data() as Map<String, dynamic>;
      final String? fcmToken = receiverData['fcmToken'];
      
      if (fcmToken == null) {
        print('❌ Receptor no tiene token FCM: $receiverId');
        return;
      }

      // Verificar preferencias de chat
      final preferences = receiverData['notificationPreferences'] as Map<String, dynamic>?;
      if (preferences != null && !(preferences['chat_messages'] ?? true)) {
        print('🔕 Usuario tiene desactivadas las notificaciones de chat');
        return;
      }

      final Map<String, dynamic> notificationData = {
        'title': '💬 Nuevo mensaje de $senderName',
        'body': message,
        'data': {
          'type': 'chat_message',
          'conversationId': conversationId,
          'senderId': senderId,
          'senderName': senderName,
        },
        'sound': 'default',
        'priority': 'high',
      };

      // Guardar en histórico
      await _saveNotificationToHistory(
        userId: receiverId,
        type: 'chat_message',
        title: notificationData['title'],
        body: notificationData['body'],
        data: notificationData['data'],
      );

      // Enviar notificación
      await _sendPushNotification(fcmToken, notificationData);
      
      print('✅ Notificación de chat enviada: $conversationId');
    } catch (e) {
      print('❌ Error al enviar notificación de chat: $e');
    }
  }

  /// Envía una notificación del sistema
  Future<void> sendSystemNotification({
    required String title,
    required String message,
    String subtype = 'general',
    List<String>? targetUserIds,
  }) async {
    try {
      List<String> userIdsToSend = [];
      
      if (targetUserIds != null) {
        userIdsToSend = targetUserIds;
      } else {
        // Enviar a todos los usuarios
        userIdsToSend = await _getAllUserIds();
      }

      for (final userId in userIdsToSend) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) continue;

        final userData = userDoc.data() as Map<String, dynamic>;
        final String? fcmToken = userData['fcmToken'];
        
        if (fcmToken == null) continue;

        // Verificar preferencias del sistema
        final preferences = userData['notificationPreferences'] as Map<String, dynamic>?;
        if (preferences != null && !(preferences['system_updates'] ?? false)) {
          continue;
        }

        final Map<String, dynamic> notificationData = {
          'title': '⚙️ $title',
          'body': message,
          'data': {
            'type': 'system_update',
            'subtype': subtype,
          },
          'sound': 'default',
          'priority': 'low',
        };

        // Guardar en histórico
        await _saveNotificationToHistory(
          userId: userId,
          type: 'system_update',
          title: notificationData['title'],
          body: notificationData['body'],
          data: notificationData['data'],
        );

        // Enviar notificación
        await _sendPushNotification(fcmToken, notificationData);
      }
      
      print('✅ Notificación del sistema enviada a ${userIdsToSend.length} usuarios');
    } catch (e) {
      print('❌ Error al enviar notificación del sistema: $e');
    }
  }

  Future<List<String>> _getUsersWithPromotionPreferences() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('notificationPreferences.promotions', isEqualTo: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error al obtener usuarios con preferencias de promociones: $e');
      return [];
    }
  }

  Future<List<String>> _getAllUserIds() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Error al obtener todos los usuarios: $e');
      return [];
    }
  }

  Future<void> _saveNotificationToHistory({
    required String userId,
    required String type,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notification_history')
          .add({
        'type': type,
        'title': title,
        'body': body,
        'data': data,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      print('❌ Error al guardar notificación en histórico: $e');
    }
  }

  Future<void> _sendPushNotification(String fcmToken, Map<String, dynamic> notificationData) async {
    // NOTA: Esta función normalmente se implementaría en Cloud Functions
    // Por ahora, solo guardamos el intento de envío en Firestore
    // para que una Cloud Function lo procese
    
    try {
      await _firestore.collection('pending_notifications').add({
        'fcmToken': fcmToken,
        'notification': notificationData,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'attempts': 0,
      });
      
      print('📤 Notificación en cola para envío: ${notificationData['title']}');
    } catch (e) {
      print('❌ Error al encolar notificación: $e');
    }
  }

  String _getOrderNotificationTitle(String status) {
    switch (status) {
      case 'pending':
        return '📦 Pedido Pendiente';
      case 'confirmed':
        return '✅ Pedido Confirmado';
      case 'preparing':
        return '👨‍🍳 Pedido en Preparación';
      case 'ready_for_pickup':
        return '🚚 Pedido Listo para Envío';
      case 'on_way':
        return '🏃 Pedido en Camino';
      case 'delivered':
        return '🎉 Pedido Entregado';
      case 'cancelled':
        return '❌ Pedido Cancelado';
      default:
        return '📋 Pedido Actualizado';
    }
  }

  String _getOrderNotificationMessage(String status, String businessName) {
    switch (status) {
      case 'pending':
        return 'Tu pedido de $businessName está siendo procesado';
      case 'confirmed':
        return 'Tu pedido de $businessName ha sido confirmado';
      case 'preparing':
        return 'Tu pedido de $businessName está siendo preparado';
      case 'ready_for_pickup':
        return 'Tu pedido de $businessName está listo para ser enviado';
      case 'on_way':
        return 'Tu pedido de $businessName está en camino';
      case 'delivered':
        return '¡Tu pedido de $businessName ha sido entregado!';
      case 'cancelled':
        return 'Tu pedido de $businessName ha sido cancelado';
      default:
        return 'Tu pedido de $businessName ha sido actualizado';
    }
  }

  /// Marca una notificación como leída
  Future<void> markNotificationAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notification_history')
          .doc(notificationId)
          .update({'read': true});
      
      print('✅ Notificación marcada como leída: $notificationId');
    } catch (e) {
      print('❌ Error al marcar notificación como leída: $e');
    }
  }

  /// Obtiene el historial de notificaciones de un usuario
  Stream<QuerySnapshot> getNotificationHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notification_history')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Obtiene el conteo de notificaciones no leídas
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notification_history')
          .where('read', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error al obtener conteo de notificaciones no leídas: $e');
      return 0;
    }
  }
}
