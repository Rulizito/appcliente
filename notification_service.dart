// ============================================================================
// services/notification_service.dart - Servicio de Notificaciones Mejorado
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'notification_preference_service.dart';
import 'notification_schedule_service.dart';
import 'notification_analytics_service.dart';
import '../models/notification_preference_model.dart';
import '../models/notification_template_model.dart';

// Handler para notificaciones en segundo plano (debe ser top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Manejando mensaje en segundo plano: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  
  // Servicios de notificaciones personalizadas
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();
  final NotificationScheduleService _scheduleService = NotificationScheduleService();
  final NotificationAnalyticsService _analyticsService = NotificationAnalyticsService();
  
  // Callbacks separados para pedidos y chat
  Function(String)? onOrderNotificationTap;
  Function(String)? onChatNotificationTap;

  Future<void> initialize() async {
    print('🔔 Inicializando servicio de notificaciones...');
    
    // Configurar handler de segundo plano
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Solicitar permisos
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Usuario autorizó las notificaciones');
      
      // Obtener token FCM
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📱 Token FCM obtenido: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      }

      // Configurar notificaciones locales
      await _initializeLocalNotifications();

      // Escuchar cambios de token
      _messaging.onTokenRefresh.listen(_saveTokenToFirestore);

      // Escuchar mensajes en primer plano
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Escuchar cuando se abre la app desde una notificación
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

      // Verificar si la app se abrió desde una notificación
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationOpen(initialMessage);
      }

    } else if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ Usuario denegó las notificaciones');
    } else {
      print('⚠️ Permisos de notificación no otorgados');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Crear canal de notificaciones para Android - Pedidos
    const androidChannel = AndroidNotificationChannel(
      'delivery_orders_channel',
      'Pedidos de Delivery',
      description: 'Notificaciones sobre el estado de tus pedidos',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    // Crear canal de notificaciones para Android - Chat
    const chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat de Soporte',
      description: 'Notificaciones de mensajes del equipo de soporte',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': 'clientes', // Para diferenciar de la app de negocios
        }, SetOptions(merge: true));
        
        print('✅ Token FCM guardado en Firestore');
      }
    } catch (e) {
      print('❌ Error al guardar token FCM: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Mensaje recibido en primer plano: ${message.notification?.title}');
    
    // Mostrar notificación local cuando la app está en primer plano
    _showLocalNotification(
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? '',
      message.data,
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    print('🔔 Notificación abierta: ${message.data}');
    
    final String? type = message.data['type'];
    final String? orderId = message.data['orderId'];
    final String? conversationId = message.data['conversationId'];

    // Manejar notificación de chat
    if (type == 'chat_message' && conversationId != null) {
      print('💬 Abriendo chat: $conversationId');
      if (onChatNotificationTap != null) {
        onChatNotificationTap!(conversationId);
      }
      return;
    }

    // Manejar notificación de pedido
    if (orderId != null) {
      print('📦 Abriendo pedido: $orderId');
      if (onOrderNotificationTap != null) {
        onOrderNotificationTap!(orderId);
      }
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    print('👆 Notificación local tocada: ${response.payload}');
    
    if (response.payload == null) return;

    // El payload contiene el tipo y el ID separados por ":"
    // Formato: "chat:conversationId" o "order:orderId"
    final parts = response.payload!.split(':');
    if (parts.length != 2) {
      // Si no tiene el formato esperado, asumimos que es un orderId (compatibilidad)
      if (onOrderNotificationTap != null) {
        onOrderNotificationTap!(response.payload!);
      }
      return;
    }

    final type = parts[0];
    final id = parts[1];

    if (type == 'chat' && onChatNotificationTap != null) {
      onChatNotificationTap!(id);
    } else if (type == 'order' && onOrderNotificationTap != null) {
      onOrderNotificationTap!(id);
    }
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    final String? type = data['type'];
    
    // Determinar el canal según el tipo de notificación
    final String channelId = type == 'chat_message' 
        ? 'chat_channel' 
        : 'delivery_orders_channel';
    
    final String channelName = type == 'chat_message'
        ? 'Chat de Soporte'
        : 'Pedidos de Delivery';
    
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: type == 'chat_message'
          ? 'Notificaciones de mensajes del equipo de soporte'
          : 'Notificaciones sobre el estado de tus pedidos',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: type == 'chat_message' 
          ? const Color(0xFF4CAF50)  // Verde para chat
          : const Color(0xFFFF0000),  // Rojo para pedidos
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Determinar el payload según el tipo
    String? payload;
    if (type == 'chat_message' && data['conversationId'] != null) {
      payload = 'chat:${data['conversationId']}';
    } else if (data['orderId'] != null) {
      payload = 'order:${data['orderId']}';
    }

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Método para limpiar el token cuando el usuario cierra sesión
  Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
        });
      }
    } catch (e) {
      print('Error al limpiar token: $e');
    }
  }

  // Enviar notificación de lealtad con personalización
  Future<Map<String, dynamic>> sendLoyaltyNotification({
    required String userId,
    required String type,
    required Map<String, dynamic> loyaltyData,
  }) async {
    NotificationTemplateType templateType;
    switch (type) {
      case 'points_earned':
        templateType = NotificationTemplateType.loyalty_points_earned;
        break;
      case 'tier_upgrade':
        templateType = NotificationTemplateType.loyalty_tier_upgrade;
        break;
      case 'reward_available':
        templateType = NotificationTemplateType.loyalty_reward_available;
        break;
      default:
        templateType = NotificationTemplateType.loyalty_points_earned;
    }

    return await sendPersonalizedNotification(
      userId: userId,
      templateType: templateType,
      variables: loyaltyData,
      metadata: {
        'type': 'loyalty',
        'loyaltyType': type,
      },
    );
  }

  // Enviar notificación personalizada usando el nuevo sistema
  Future<Map<String, dynamic>> sendPersonalizedNotification({
    required String userId,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> variables,
    NotificationChannel channel = NotificationChannel.push,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Usar el servicio de programación para enviar notificación personalizada
      final result = await _scheduleService.sendPersonalizedNotification(
        userId: userId,
        templateType: templateType,
        variables: variables,
        channel: channel,
        metadata: metadata,
      );

      // Si el envío fue exitoso, mostrar notificación local también
      if (result['success'] && channel == NotificationChannel.push) {
        final rendered = result['rendered'] ?? {};
        await _showLocalNotification(
          rendered['title'] ?? 'Notificación',
          rendered['body'] ?? '',
          {
            'type': _getNotificationTypeFromTemplateType(templateType).value,
            ...rendered['data'] ?? {},
          },
        );
      }

      return result;
    } catch (e) {
      print('Error sending personalized notification: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Enviar notificación de promoción con personalización
  Future<Map<String, dynamic>> sendPromotionNotification({
    required String userId,
    required String promotionTitle,
    required String promotionDescription,
    required String promotionId,
    String? businessName,
    String? discountCode,
    DateTime? expiryDate,
  }) async {
    final variables = {
      'promotionTitle': promotionTitle,
      'promotionDescription': promotionDescription,
      'promotionId': promotionId,
      'businessName': businessName ?? 'Tu negocio favorito',
      'discountCode': discountCode ?? '',
      'expiryDate': expiryDate != null 
          ? DateFormat('dd MMM yyyy').format(expiryDate)
          : '',
    };

    return await sendPersonalizedNotification(
      userId: userId,
      templateType: NotificationTemplateType.promotion_new,
      variables: variables,
      metadata: {
        'type': 'promotion',
        'promotionId': promotionId,
      },
    );
  }

  // Enviar notificación de recordatorio con personalización
  Future<Map<String, dynamic>> sendReminderNotification({
    required String userId,
    required String reminderType,
    required Map<String, dynamic> reminderData,
  }) async {
    NotificationTemplateType templateType;
    switch (reminderType) {
      case 'cart_abandoned':
        templateType = NotificationTemplateType.cart_abandoned;
        break;
      case 'favorite_business':
        templateType = NotificationTemplateType.favorite_business_update;
        break;
      default:
        templateType = NotificationTemplateType.cart_abandoned;
    }

    return await sendPersonalizedNotification(
      userId: userId,
      templateType: templateType,
      variables: reminderData,
      metadata: {
        'type': 'reminder',
        'reminderType': reminderType,
      },
    );
  }

  // Programar notificación para el futuro
  Future<bool> scheduleNotification({
    required String userId,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> variables,
    required DateTime scheduledAt,
    NotificationChannel channel = NotificationChannel.push,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      return await _scheduleService.scheduleNotification(
        userId: userId,
        templateType: templateType,
        variables: variables,
        scheduledAt: scheduledAt,
        channel: channel,
        metadata: metadata,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
      return false;
    }
  }

  // Cancelar notificación programada
  Future<bool> cancelScheduledNotification(String scheduledId) async {
    try {
      return await _scheduleService.cancelScheduledNotification(scheduledId);
    } catch (e) {
      print('Error cancelling scheduled notification: $e');
      return false;
    }
  }

  // Evaluar reglas de notificación y enviar automáticamente
  Future<void> evaluateAndSendNotifications(
    String userId,
    Map<String, dynamic> context,
  ) async {
    try {
      final triggeredRules = await _scheduleService.evaluateRules(userId, context);
      
      for (final rule in triggeredRules) {
        final templateType = rule['templateType'] as NotificationTemplateType;
        final actions = rule['actions'] as Map<String, dynamic>;
        
        await sendPersonalizedNotification(
          userId: userId,
          templateType: templateType,
          variables: actions['variables'] as Map<String, dynamic>,
          channel: NotificationChannel.values.firstWhere(
            (channel) => actions['channels']?.contains(channel.value) ?? false,
            orElse: () => NotificationChannel.push,
          ),
          metadata: {
            'triggeredByRule': rule['ruleId'],
            'context': context,
          },
        );
      }
    } catch (e) {
      print('Error evaluating notification rules: $e');
    }
  }

  // Obtener estadísticas del usuario actual
  Future<Map<String, dynamic>> getCurrentUserStats() async {
    try {
      return await _preferenceService.getCurrentUserStats();
    } catch (e) {
      print('Error getting current user stats: $e');
      return {};
    }
  }

  // Obtener predicción de engagement del usuario actual
  Future<Map<String, dynamic>> getCurrentUserPrediction() async {
    try {
      return await _preferenceService.getCurrentUserPrediction();
    } catch (e) {
      print('Error getting current user prediction: $e');
      return {};
    }
  }

  // Verificar si el usuario puede recibir notificaciones
  Future<bool> canUserReceiveNotification({
    required String userId,
    required NotificationType type,
    required NotificationChannel channel,
  }) async {
    try {
      return await _preferenceService.canReceiveNotification(
        userId,
        type,
        channel,
      );
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  // Método auxiliar para convertir TemplateType a NotificationType
  NotificationType _getNotificationTypeFromTemplateType(NotificationTemplateType templateType) {
    switch (templateType) {
      case NotificationTemplateType.order_status_update:
        return NotificationType.order_status;
      case NotificationTemplateType.order_delivered:
        return NotificationType.order_delivered;
      case NotificationTemplateType.order_cancelled:
        return NotificationType.order_status;
      case NotificationTemplateType.promotion_new:
        return NotificationType.promotion_new;
      case NotificationTemplateType.promotion_expiring:
        return NotificationType.promotion_expiring;
      case NotificationTemplateType.loyalty_points_earned:
        return NotificationType.loyalty_points;
      case NotificationTemplateType.loyalty_tier_upgrade:
        return NotificationType.loyalty_tier_upgrade;
      case NotificationTemplateType.loyalty_reward_available:
        return NotificationType.loyalty_reward;
      case NotificationTemplateType.business_recommendation:
        return NotificationType.recommendation;
      case NotificationTemplateType.review_request:
        return NotificationType.review_request;
      case NotificationTemplateType.referral_invite:
        return NotificationType.referral;
      case NotificationTemplateType.cart_abandoned:
        return NotificationType.reminder_cart;
      case NotificationTemplateType.favorite_business_update:
        return NotificationType.reminder_favorite;
      case NotificationTemplateType.system_maintenance:
        return NotificationType.system_update;
      case NotificationTemplateType.security_alert:
        return NotificationType.security;
    }
  }

  // Método para probar notificaciones (desarrollo)
  Future<void> testNotification() async {
    await _showLocalNotification(
      '🧪 Notificación de Prueba',
      'Esta es una notificación de prueba del sistema',
      {'orderId': 'test123', 'type': 'order_update'},
    );
  }

  // Métodos para pedidos programados (añadidos para compatibilidad)
  Future<void> sendScheduledOrderStatusUpdate(Map<String, dynamic> order, String status) async {
    final title = 'Pedido Programado: $status';
    final body = 'Tu pedido programado #${order['id']} ha sido actualizado a: $status';
    
    await _showLocalNotification(
      title,
      body,
      {'orderId': order['id'], 'type': 'scheduled_order_update', 'status': status},
    );
  }

  Future<void> sendScheduledOrderCancellation(Map<String, dynamic> order, String reason) async {
    final title = 'Pedido Programado Cancelado';
    final body = 'Tu pedido #${order['id']} ha sido cancelado. Motivo: $reason';
    
    await _showLocalNotification(
      title,
      body,
      {'orderId': order['id'], 'type': 'scheduled_order_cancelled', 'reason': reason},
    );
  }

  Future<void> sendScheduledOrderConfirmation(Map<String, dynamic> order) async {
    final title = '¡Pedido Programado Confirmado!';
    final body = 'Tu pedido #${order['id']} ha sido programado para ${order['scheduledDateTime']}';
    
    await _showLocalNotification(
      title,
      body,
      {'orderId': order['id'], 'type': 'scheduled_order_confirmation'},
    );
  }
}