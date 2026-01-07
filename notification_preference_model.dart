// ============================================================================
// models/notification_preference_model.dart - Modelo de Preferencias de Notificaciones
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NotificationCategory {
  orders('orders', 'Pedidos'),
  promotions('promotions', 'Promociones'),
  loyalty('loyalty', 'Lealtad'),
  recommendations('recommendations', 'Recomendaciones'),
  social('social', 'Social'),
  system('system', 'Sistema'),
  reminders('reminders', 'Recordatorios');

  const NotificationCategory(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationCategory fromString(String value) {
    return NotificationCategory.values.firstWhere(
      (category) => category.value == value,
      orElse: () => NotificationCategory.orders,
    );
  }
}

enum NotificationType {
  order_status('order_status', 'Estado del Pedido'),
  order_delivered('order_delivered', 'Pedido Entregado'),
  promotion_new('promotion_new', 'Nueva Promoción'),
  promotion_expiring('promotion_expiring', 'Promoción por Expirar'),
  loyalty_points('loyalty_points', 'Puntos de Lealtad'),
  loyalty_tier_upgrade('loyalty_tier_upgrade', 'Upgrade de Nivel'),
  loyalty_reward('loyalty_reward', 'Recompensa Disponible'),
  recommendation('recommendation', 'Recomendación Personalizada'),
  review_request('review_request', 'Solicitud de Reseña'),
  referral('referral', 'Invitación Amigo'),
  reminder_cart('reminder_cart', 'Carrito Abandonado'),
  reminder_favorite('reminder_favorite', 'Negocio Favorito'),
  system_update('system_update', 'Actualización del Sistema'),
  security('security', 'Seguridad');

  const NotificationType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationType.order_status,
    );
  }
}

enum NotificationChannel {
  push('push', 'Push'),
  email('email', 'Email'),
  sms('sms', 'SMS'),
  in_app('in_app', 'In-App');

  const NotificationChannel(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationChannel fromString(String value) {
    return NotificationChannel.values.firstWhere(
      (channel) => channel.value == value,
      orElse: () => NotificationChannel.push,
    );
  }
}

enum NotificationFrequency {
  immediate('immediate', 'Inmediato'),
  daily('daily', 'Diario'),
  weekly('weekly', 'Semanal'),
  never('never', 'Nunca');

  const NotificationFrequency(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationFrequency fromString(String value) {
    return NotificationFrequency.values.firstWhere(
      (frequency) => frequency.value == value,
      orElse: () => NotificationFrequency.immediate,
    );
  }
}

class NotificationPreference {
  final String id;
  final String userId;
  final NotificationCategory category;
  final NotificationType type;
  final Map<NotificationChannel, bool> channelSettings;
  final NotificationFrequency frequency;
  final bool isEnabled;
  final Map<String, dynamic> customSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationPreference({
    required this.id,
    required this.userId,
    required this.category,
    required this.type,
    required this.channelSettings,
    required this.frequency,
    required this.isEnabled,
    required this.customSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreference.create({
    required String userId,
    required NotificationCategory category,
    required NotificationType type,
  }) {
    return NotificationPreference(
      id: FirebaseFirestore.instance.collection('notification_preferences').doc().id,
      userId: userId,
      category: category,
      type: type,
      channelSettings: {
        NotificationChannel.push: true,
        NotificationChannel.email: false,
        NotificationChannel.sms: false,
        NotificationChannel.in_app: true,
      },
      frequency: NotificationFrequency.immediate,
      isEnabled: true,
      customSettings: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory NotificationPreference.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse channel settings
    final channelSettingsMap = data['channelSettings'] as Map<String, dynamic>? ?? {};
    final channelSettings = <NotificationChannel, bool>{};
    for (final entry in channelSettingsMap.entries) {
      final channel = NotificationChannel.fromString(entry.key);
      channelSettings[channel] = entry.value as bool;
    }

    return NotificationPreference(
      id: doc.id,
      userId: data['userId'] ?? '',
      category: NotificationCategory.fromString(data['category'] ?? ''),
      type: NotificationType.fromString(data['type'] ?? ''),
      channelSettings: channelSettings,
      frequency: NotificationFrequency.fromString(data['frequency'] ?? ''),
      isEnabled: data['isEnabled'] ?? true,
      customSettings: data['customSettings'] as Map<String, dynamic>? ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'category': category.value,
      'type': type.value,
      'channelSettings': channelSettings.map((key, value) => MapEntry(key.value, value)),
      'frequency': frequency.value,
      'isEnabled': isEnabled,
      'customSettings': customSettings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  NotificationPreference copyWith({
    String? id,
    String? userId,
    NotificationCategory? category,
    NotificationType? type,
    Map<NotificationChannel, bool>? channelSettings,
    NotificationFrequency? frequency,
    bool? isEnabled,
    Map<String, dynamic>? customSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      category: category ?? this.category,
      type: type ?? this.type,
      channelSettings: channelSettings ?? this.channelSettings,
      frequency: frequency ?? this.frequency,
      isEnabled: isEnabled ?? this.isEnabled,
      customSettings: customSettings ?? this.customSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Métodos de utilidad
  bool isChannelEnabled(NotificationChannel channel) {
    return isEnabled && (channelSettings[channel] ?? false);
  }

  void enableChannel(NotificationChannel channel, bool enabled) {
    channelSettings[channel] = enabled;
  }

  void enableAllChannels(bool enabled) {
    for (final channel in NotificationChannel.values) {
      channelSettings[channel] = enabled;
    }
  }
}

class NotificationProfile {
  final String id;
  final String userId;
  final Map<NotificationCategory, bool> categorySettings;
  final Map<NotificationChannel, bool> globalChannelSettings;
  final NotificationFrequency defaultFrequency;
  final bool quietHoursEnabled;
  final TimeOfDay quietHoursStart;
  final TimeOfDay quietHoursEnd;
  final Map<String, dynamic> advancedSettings;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationProfile({
    required this.id,
    required this.userId,
    required this.categorySettings,
    required this.globalChannelSettings,
    required this.defaultFrequency,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.advancedSettings,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationProfile.create({
    required String userId,
  }) {
    return NotificationProfile(
      id: FirebaseFirestore.instance.collection('notification_profiles').doc().id,
      userId: userId,
      categorySettings: {
        for (final category in NotificationCategory.values) category: true
      },
      globalChannelSettings: {
        NotificationChannel.push: true,
        NotificationChannel.email: false,
        NotificationChannel.sms: false,
        NotificationChannel.in_app: true,
      },
      defaultFrequency: NotificationFrequency.immediate,
      quietHoursEnabled: false,
      quietHoursStart: const TimeOfDay(hour: 22, minute: 0),
      quietHoursEnd: const TimeOfDay(hour: 8, minute: 0),
      advancedSettings: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory NotificationProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse category settings
    final categorySettingsMap = data['categorySettings'] as Map<String, dynamic>? ?? {};
    final categorySettings = <NotificationCategory, bool>{};
    for (final entry in categorySettingsMap.entries) {
      final category = NotificationCategory.fromString(entry.key);
      categorySettings[category] = entry.value as bool;
    }

    // Parse global channel settings
    final globalChannelSettingsMap = data['globalChannelSettings'] as Map<String, dynamic>? ?? {};
    final globalChannelSettings = <NotificationChannel, bool>{};
    for (final entry in globalChannelSettingsMap.entries) {
      final channel = NotificationChannel.fromString(entry.key);
      globalChannelSettings[channel] = entry.value as bool;
    }

    // Parse quiet hours
    final quietHoursStartData = data['quietHoursStart'] as Map<String, dynamic>? ?? {};
    final quietHoursEndData = data['quietHoursEnd'] as Map<String, dynamic>? ?? {};

    return NotificationProfile(
      id: doc.id,
      userId: data['userId'] ?? '',
      categorySettings: categorySettings,
      globalChannelSettings: globalChannelSettings,
      defaultFrequency: NotificationFrequency.fromString(data['defaultFrequency'] ?? ''),
      quietHoursEnabled: data['quietHoursEnabled'] ?? false,
      quietHoursStart: TimeOfDay(
        hour: quietHoursStartData['hour'] ?? 22,
        minute: quietHoursStartData['minute'] ?? 0,
      ),
      quietHoursEnd: TimeOfDay(
        hour: quietHoursEndData['hour'] ?? 8,
        minute: quietHoursEndData['minute'] ?? 0,
      ),
      advancedSettings: data['advancedSettings'] as Map<String, dynamic>? ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categorySettings': categorySettings.map((key, value) => MapEntry(key.value, value)),
      'globalChannelSettings': globalChannelSettings.map((key, value) => MapEntry(key.value, value)),
      'defaultFrequency': defaultFrequency.value,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStart': {
        'hour': quietHoursStart.hour,
        'minute': quietHoursStart.minute,
      },
      'quietHoursEnd': {
        'hour': quietHoursEnd.hour,
        'minute': quietHoursEnd.minute,
      },
      'advancedSettings': advancedSettings,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  NotificationProfile copyWith({
    String? id,
    String? userId,
    Map<NotificationCategory, bool>? categorySettings,
    Map<NotificationChannel, bool>? globalChannelSettings,
    NotificationFrequency? defaultFrequency,
    bool? quietHoursEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    Map<String, dynamic>? advancedSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      categorySettings: categorySettings ?? this.categorySettings,
      globalChannelSettings: globalChannelSettings ?? this.globalChannelSettings,
      defaultFrequency: defaultFrequency ?? this.defaultFrequency,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      advancedSettings: advancedSettings ?? this.advancedSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Métodos de utilidad
  bool isCategoryEnabled(NotificationCategory category) {
    return categorySettings[category] ?? false;
  }

  bool isChannelGloballyEnabled(NotificationChannel channel) {
    return globalChannelSettings[channel] ?? false;
  }

  bool isInQuietHours() {
    if (!quietHoursEnabled) return false;
    
    final now = DateTime.now();
    final start = quietHoursStart;
    final end = quietHoursEnd;
    
    // Caso normal: start < end (ej: 22:00 a 08:00)
    if (start.hour < end.hour || 
        (start.hour == end.hour && start.minute <= end.minute)) {
      return (now.hour > start.hour || 
              (now.hour == start.hour && now.minute >= start.minute)) &&
             (now.hour < end.hour || 
              (now.hour == end.hour && now.minute <= end.minute));
    }
    // Caso especial: start > end (ej: 22:00 a 08:00 del día siguiente)
    else {
      return (now.hour > start.hour || 
              (now.hour == start.hour && now.minute >= start.minute)) ||
             (now.hour < end.hour || 
              (now.hour == end.hour && now.minute <= end.minute));
    }
  }

  void enableCategory(NotificationCategory category, bool enabled) {
    categorySettings[category] = enabled;
  }

  void enableChannelGlobally(NotificationChannel channel, bool enabled) {
    globalChannelSettings[channel] = enabled;
  }
}

class NotificationAnalytics {
  final String id;
  final String userId;
  final NotificationType type;
  final NotificationChannel channel;
  final DateTime sentAt;
  final DateTime? openedAt;
  final DateTime? clickedAt;
  final bool isDelivered;
  final bool isOpened;
  final bool isClicked;
  final Map<String, dynamic> metadata;
  final Duration? timeToOpen;
  final Duration? timeToClick;

  const NotificationAnalytics({
    required this.id,
    required this.userId,
    required this.type,
    required this.channel,
    required this.sentAt,
    this.openedAt,
    this.clickedAt,
    required this.isDelivered,
    required this.isOpened,
    required this.isClicked,
    required this.metadata,
    this.timeToOpen,
    this.timeToClick,
  });

  factory NotificationAnalytics.create({
    required String userId,
    required NotificationType type,
    required NotificationChannel channel,
    required Map<String, dynamic> metadata,
  }) {
    final now = DateTime.now();
    return NotificationAnalytics(
      id: FirebaseFirestore.instance.collection('notification_analytics').doc().id,
      userId: userId,
      type: type,
      channel: channel,
      sentAt: now,
      isDelivered: false,
      isOpened: false,
      isClicked: false,
      metadata: metadata,
    );
  }

  factory NotificationAnalytics.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationAnalytics(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: NotificationType.fromString(data['type'] ?? ''),
      channel: NotificationChannel.fromString(data['channel'] ?? ''),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      clickedAt: (data['clickedAt'] as Timestamp?)?.toDate(),
      isDelivered: data['isDelivered'] ?? false,
      isOpened: data['isOpened'] ?? false,
      isClicked: data['isClicked'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      timeToOpen: data['timeToOpen'] != null 
          ? Duration(milliseconds: data['timeToOpen'])
          : null,
      timeToClick: data['timeToClick'] != null 
          ? Duration(milliseconds: data['timeToClick'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.value,
      'channel': channel.value,
      'sentAt': Timestamp.fromDate(sentAt),
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'clickedAt': clickedAt != null ? Timestamp.fromDate(clickedAt!) : null,
      'isDelivered': isDelivered,
      'isOpened': isOpened,
      'isClicked': isClicked,
      'metadata': metadata,
      'timeToOpen': timeToOpen?.inMilliseconds,
      'timeToClick': timeToClick?.inMilliseconds,
    };
  }

  NotificationAnalytics copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    NotificationChannel? channel,
    DateTime? sentAt,
    DateTime? openedAt,
    DateTime? clickedAt,
    bool? isDelivered,
    bool? isOpened,
    bool? isClicked,
    Map<String, dynamic>? metadata,
    Duration? timeToOpen,
    Duration? timeToClick,
  }) {
    return NotificationAnalytics(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      channel: channel ?? this.channel,
      sentAt: sentAt ?? this.sentAt,
      openedAt: openedAt ?? this.openedAt,
      clickedAt: clickedAt ?? this.clickedAt,
      isDelivered: isDelivered ?? this.isDelivered,
      isOpened: isOpened ?? this.isOpened,
      isClicked: isClicked ?? this.isClicked,
      metadata: metadata ?? this.metadata,
      timeToOpen: timeToOpen ?? this.timeToOpen,
      timeToClick: timeToClick ?? this.timeToClick,
    );
  }

  // Métodos de utilidad
  void markAsOpened() {
    final now = DateTime.now();
    final updatedAnalytics = copyWith(
      openedAt: now,
      isOpened: true,
      timeToOpen: now.difference(sentAt),
    );
    // Aquí iría la lógica para actualizar en Firestore
  }

  void markAsClicked() {
    final now = DateTime.now();
    final updatedAnalytics = copyWith(
      clickedAt: now,
      isClicked: true,
      timeToClick: now.difference(sentAt),
    );
    // Aquí iría la lógica para actualizar en Firestore
  }

  void markAsDelivered() {
    final updatedAnalytics = copyWith(
      isDelivered: true,
    );
    // Aquí iría la lógica para actualizar en Firestore
  }

  double get engagementRate {
    if (!isDelivered) return 0.0;
    int actions = (isOpened ? 1 : 0) + (isClicked ? 1 : 0);
    return actions / 2.0; // Máximo 2 acciones posibles
  }
}
