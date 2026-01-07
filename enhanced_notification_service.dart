// ============================================================================
// services/enhanced_notification_service.dart
// ============================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EnhancedNotificationService {
  static final EnhancedNotificationService _instance = EnhancedNotificationService._internal();
  factory EnhancedNotificationService() => _instance;
  EnhancedNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Callbacks para diferentes tipos de notificaciones
  Function(String)? onOrderNotificationTap;
  Function(String)? onChatNotificationTap;
  Function(String)? onPromotionNotificationTap;
  Function(String)? onSystemNotificationTap;

  // Preferencias de notificaciones del usuario
  Map<String, bool> _notificationPreferences = {
    'order_updates': true,
    'promotions': true,
    'chat_messages': true,
    'system_updates': false,
  };

  Future<void> initialize() async {
    print('🔔 Inicializando servicio de notificaciones mejorado...');
    
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

      // Cargar preferencias del usuario
      await _loadNotificationPreferences();

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

    // Crear canales de notificaciones específicos
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return;

    // Canal para actualizaciones de pedidos
    const orderChannel = AndroidNotificationChannel(
      'order_updates_channel',
      'Actualizaciones de Pedidos',
      description: 'Notificaciones sobre el estado de tus pedidos',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin.createNotificationChannel(orderChannel);

    // Canal para promociones
    const promotionChannel = AndroidNotificationChannel(
      'promotions_channel',
      'Promociones y Ofertas',
      description: 'Notificaciones de promociones y ofertas especiales',
      importance: Importance.low,
      playSound: true,
      enableVibration: false,
    );
    await androidPlugin.createNotificationChannel(promotionChannel);

    // Canal para chat
    const chatChannel = AndroidNotificationChannel(
      'chat_channel',
      'Chat de Soporte',
      description: 'Notificaciones de mensajes del equipo de soporte',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin.createNotificationChannel(chatChannel);

    // Canal para actualizaciones del sistema
    const systemChannel = AndroidNotificationChannel(
      'system_channel',
      'Actualizaciones del Sistema',
      description: 'Notificaciones importantes del sistema',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin.createNotificationChannel(systemChannel);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .set({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': 'clientes',
          'appVersion': '1.0.0', // Podrías obtener esto dinámicamente
          'deviceInfo': 'Android', // Podrías obtener más detalles del dispositivo
        }, SetOptions(merge: true));
        
        print('✅ Token FCM guardado en Firestore');
      }
    } catch (e) {
      print('❌ Error al guardar token FCM: $e');
    }
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data['notificationPreferences'] != null) {
            _notificationPreferences = Map<String, bool>.from(
              data['notificationPreferences']
            );
            print('📋 Preferencias de notificaciones cargadas');
          }
        }
      }
    } catch (e) {
      print('❌ Error al cargar preferencias: $e');
    }
  }

  Future<void> updateNotificationPreferences(Map<String, bool> preferences) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _notificationPreferences = preferences;
        
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationPreferences': preferences,
          'preferencesUpdatedAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Preferencias de notificaciones actualizadas');
      }
    } catch (e) {
      print('❌ Error al actualizar preferencias: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Mensaje recibido en primer plano: ${message.notification?.title}');
    
    // Verificar si el usuario quiere recibir este tipo de notificación
    if (!_shouldShowNotification(message.data)) {
      print('🔕 Notificación filtrada por preferencias del usuario');
      return;
    }
    
    // Mostrar notificación local cuando la app está en primer plano
    _showLocalNotification(
      message.notification?.title ?? 'Notificación',
      message.notification?.body ?? '',
      message.data,
    );
  }

  bool _shouldShowNotification(Map<String, dynamic>? data) {
    if (data == null) return true;
    
    final String? type = data['type'];
    
    switch (type) {
      case 'order_update':
        return _notificationPreferences['order_updates'] ?? true;
      case 'promotion':
        return _notificationPreferences['promotions'] ?? true;
      case 'chat_message':
        return _notificationPreferences['chat_messages'] ?? true;
      case 'system_update':
        return _notificationPreferences['system_updates'] ?? false;
      default:
        return true;
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    print('🔔 Notificación abierta: ${message.data}');
    
    final String? type = message.data['type'];
    final String? orderId = message.data['orderId'];
    final String? conversationId = message.data['conversationId'];
    final String? promotionId = message.data['promotionId'];

    switch (type) {
      case 'chat_message':
        if (conversationId != null && onChatNotificationTap != null) {
          print('💬 Abriendo chat: $conversationId');
          onChatNotificationTap!(conversationId);
        }
        break;
        
      case 'promotion':
        if (promotionId != null && onPromotionNotificationTap != null) {
          print('🎁 Abriendo promoción: $promotionId');
          onPromotionNotificationTap!(promotionId);
        }
        break;
        
      case 'system_update':
        if (onSystemNotificationTap != null) {
          print('⚙️ Abriendo actualización del sistema');
          onSystemNotificationTap!('system_update');
        }
        break;
        
      case 'order_update':
      default:
        if (orderId != null && onOrderNotificationTap != null) {
          print('📦 Abriendo pedido: $orderId');
          onOrderNotificationTap!(orderId);
        }
        break;
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    print('👆 Notificación local tocada: ${response.payload}');
    
    if (response.payload == null) return;

    // El payload contiene el tipo y el ID separados por ":"
    // Formato: "chat:conversationId", "order:orderId", "promotion:promotionId", "system:type"
    final parts = response.payload!.split(':');
    if (parts.length != 2) {
      // Compatibilidad con formato antiguo
      if (onOrderNotificationTap != null) {
        onOrderNotificationTap!(response.payload!);
      }
      return;
    }

    final type = parts[0];
    final id = parts[1];

    switch (type) {
      case 'chat':
        if (onChatNotificationTap != null) {
          onChatNotificationTap!(id);
        }
        break;
      case 'promotion':
        if (onPromotionNotificationTap != null) {
          onPromotionNotificationTap!(id);
        }
        break;
      case 'system':
        if (onSystemNotificationTap != null) {
          onSystemNotificationTap!(id);
        }
        break;
      case 'order':
      default:
        if (onOrderNotificationTap != null) {
          onOrderNotificationTap!(id);
        }
        break;
    }
  }

  Future<void> _showLocalNotification(
    String title,
    String body,
    Map<String, dynamic> data,
  ) async {
    final String? type = data['type'];
    
    // Determinar el canal según el tipo de notificación
    String channelId;
    String channelName;
    String channelDescription;
    Color notificationColor;
    
    switch (type) {
      case 'promotion':
        channelId = 'promotions_channel';
        channelName = 'Promociones y Ofertas';
        channelDescription = 'Notificaciones de promociones y ofertas especiales';
        notificationColor = const Color(0xFF9C27B0); // Púrpura
        break;
      case 'chat_message':
        channelId = 'chat_channel';
        channelName = 'Chat de Soporte';
        channelDescription = 'Notificaciones de mensajes del equipo de soporte';
        notificationColor = const Color(0xFF4CAF50); // Verde
        break;
      case 'system_update':
        channelId = 'system_channel';
        channelName = 'Actualizaciones del Sistema';
        channelDescription = 'Notificaciones importantes del sistema';
        notificationColor = const Color(0xFF2196F3); // Azul
        break;
      case 'order_update':
      default:
        channelId = 'order_updates_channel';
        channelName = 'Actualizaciones de Pedidos';
        channelDescription = 'Notificaciones sobre el estado de tus pedidos';
        notificationColor = const Color(0xFFFF0000); // Rojo
        break;
    }
    
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: type == 'promotion' ? Importance.low : Importance.high,
      priority: type == 'promotion' ? Priority.low : Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: notificationColor,
      autoCancel: true,
      ongoing: false,
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
    switch (type) {
      case 'chat_message':
        payload = data['conversationId'] != null ? 'chat:${data['conversationId']}' : null;
        break;
      case 'promotion':
        payload = data['promotionId'] != null ? 'promotion:${data['promotionId']}' : null;
        break;
      case 'system_update':
        payload = 'system:${data['subtype'] ?? 'general'}';
        break;
      case 'order_update':
      default:
        payload = data['orderId'] != null ? 'order:${data['orderId']}' : null;
        break;
    }

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Métodos específicos para enviar notificaciones locales
  
  Future<void> sendOrderStatusNotification({
    required String orderId,
    required String businessName,
    required String status,
    String? customMessage,
  }) async {
    if (!(_notificationPreferences['order_updates'] ?? true)) return;
    
    final statusInfo = _getOrderStatusInfo(status);
    
    await _showLocalNotification(
      '📦 Pedido $statusInfo',
      customMessage ?? 'Tu pedido de $businessName está $statusInfo',
      {
        'type': 'order_update',
        'orderId': orderId,
        'status': status,
        'businessName': businessName,
      },
    );
  }

  Future<void> sendPromotionNotification({
    required String promotionId,
    required String title,
    required String description,
    required String businessName,
  }) async {
    if (!(_notificationPreferences['promotions'] ?? true)) return;
    
    await _showLocalNotification(
      '🎁 $title',
      '$businessName: $description',
      {
        'type': 'promotion',
        'promotionId': promotionId,
        'businessName': businessName,
        'title': title,
      },
    );
  }

  Future<void> sendChatNotification({
    required String conversationId,
    required String message,
    required String senderName,
  }) async {
    if (!(_notificationPreferences['chat_messages'] ?? true)) return;
    
    await _showLocalNotification(
      '💬 Nuevo mensaje de $senderName',
      message,
      {
        'type': 'chat_message',
        'conversationId': conversationId,
        'senderName': senderName,
      },
    );
  }

  Map<String, String> _getOrderStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {'text': 'Pendiente', 'emoji': '⏳'};
      case 'confirmed':
        return {'text': 'Confirmado', 'emoji': '✅'};
      case 'preparing':
        return {'text': 'Preparando', 'emoji': '👨‍🍳'};
      case 'ready_for_pickup':
        return {'text': 'Listo para envío', 'emoji': '🚚'};
      case 'on_way':
        return {'text': 'En camino', 'emoji': '🏃'};
      case 'delivered':
        return {'text': 'Entregado', 'emoji': '🎉'};
      case 'cancelled':
        return {'text': 'Cancelado', 'emoji': '❌'};
      default:
        return {'text': 'Actualizado', 'emoji': '📋'};
    }
  }

  // Método para limpiar el token cuando el usuario cierra sesión
  Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': FieldValue.delete(),
        });
        
        await _messaging.deleteToken();
        print('🗑️ Token FCM eliminado');
      }
    } catch (e) {
      print('❌ Error al eliminar token FCM: $e');
    }
  }

  // Métodos de prueba para desarrollo
  Future<void> testOrderNotification() async {
    await sendOrderStatusNotification(
      orderId: 'test123',
      businessName: 'Pizza Palace',
      status: 'on_way',
      customMessage: 'Tu pedido está a 10 minutos de llegar',
    );
  }

  Future<void> testPromotionNotification() async {
    await sendPromotionNotification(
      promotionId: 'promo123',
      title: '2x1 en Pizzas',
      description: 'Aprovecha esta oferta por tiempo limitado',
      businessName: 'Pizza Palace',
    );
  }

  Future<void> testChatNotification() async {
    await sendChatNotification(
      conversationId: 'chat123',
      message: '¿En qué podemos ayudarte?',
      senderName: 'Soporte',
    );
  }

  // Getters
  Map<String, bool> get notificationPreferences => _notificationPreferences;
}
