// ============================================================================
// services/notification_preference_service.dart - Servicio de Preferencias de Notificaciones
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_preference_model.dart';
import '../models/notification_template_model.dart';

class NotificationPreferenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener perfil de notificaciones del usuario
  Stream<NotificationProfile?> getUserProfile(String userId) {
    return _firestore
        .collection('notification_profiles')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;
          return NotificationProfile.fromFirestore(docs.first);
        });
  }

  // Crear perfil de notificaciones para nuevo usuario
  Future<NotificationProfile> createUserProfile(String userId) async {
    try {
      final profile = NotificationProfile.create(userId: userId);
      
      await _firestore
          .collection('notification_profiles')
          .doc(profile.id)
          .set(profile.toMap());
      
      // Crear preferencias por defecto
      await _createDefaultPreferences(userId);
      
      return profile;
    } catch (e) {
      print('Error creating notification profile: $e');
      rethrow;
    }
  }

  // Crear preferencias por defecto
  Future<void> _createDefaultPreferences(String userId) async {
    final defaultPreferences = [
      // Pedidos
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.orders,
        type: NotificationType.order_status,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.orders,
        type: NotificationType.order_delivered,
      ),
      
      // Promociones
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.promotions,
        type: NotificationType.promotion_new,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.promotions,
        type: NotificationType.promotion_expiring,
      ),
      
      // Lealtad
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.loyalty,
        type: NotificationType.loyalty_points,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.loyalty,
        type: NotificationType.loyalty_tier_upgrade,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.loyalty,
        type: NotificationType.loyalty_reward,
      ),
      
      // Recomendaciones
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.recommendations,
        type: NotificationType.recommendation,
      ),
      
      // Social
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.social,
        type: NotificationType.review_request,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.social,
        type: NotificationType.referral,
      ),
      
      // Recordatorios
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.reminders,
        type: NotificationType.reminder_cart,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.reminders,
        type: NotificationType.reminder_favorite,
      ),
      
      // Sistema
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.system,
        type: NotificationType.system_update,
      ),
      NotificationPreference.create(
        userId: userId,
        category: NotificationCategory.system,
        type: NotificationType.security,
      ),
    ];

    final batch = _firestore.batch();
    
    for (final preference in defaultPreferences) {
      final docRef = _firestore.collection('notification_preferences').doc(preference.id);
      batch.set(docRef, preference.toMap());
    }
    
    await batch.commit();
  }

  // Actualizar perfil de notificaciones
  Future<bool> updateProfile(NotificationProfile profile) async {
    try {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection('notification_profiles')
          .doc(profile.id)
          .set(updatedProfile.toMap());
      
      return true;
    } catch (e) {
      print('Error updating notification profile: $e');
      return false;
    }
  }

  // Obtener preferencias específicas del usuario
  Stream<List<NotificationPreference>> getUserPreferences(String userId) {
    return _firestore
        .collection('notification_preferences')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationPreference.fromFirestore(doc))
              .toList();
        });
  }

  // Obtener preferencia específica
  Stream<NotificationPreference?> getPreference(
    String userId,
    NotificationCategory category,
    NotificationType type,
  ) {
    return _firestore
        .collection('notification_preferences')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category.value)
        .where('type', isEqualTo: type.value)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;
          return NotificationPreference.fromFirestore(docs.first);
        });
  }

  // Actualizar preferencia específica
  Future<bool> updatePreference(NotificationPreference preference) async {
    try {
      final updatedPreference = preference.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection('notification_preferences')
          .doc(preference.id)
          .set(updatedPreference.toMap());
      
      return true;
    } catch (e) {
      print('Error updating notification preference: $e');
      return false;
    }
  }

  // Habilitar/deshabilitar categoría completa
  Future<bool> toggleCategory(
    String userId,
    NotificationCategory category,
    bool enabled,
  ) async {
    try {
      final profileQuery = await _firestore
          .collection('notification_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (profileQuery.docs.isEmpty) return false;
      
      final profile = NotificationProfile.fromFirestore(profileQuery.docs.first);
      final updatedProfile = profile.copyWith(
        categorySettings: {...profile.categorySettings}..[category] = enabled,
        updatedAt: DateTime.now(),
      );
      
      await updateProfile(updatedProfile);
      
      // También actualizar todas las preferencias individuales de la categoría
      final preferencesQuery = await _firestore
          .collection('notification_preferences')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: category.value)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in preferencesQuery.docs) {
        final preference = NotificationPreference.fromFirestore(doc);
        final updatedPreference = preference.copyWith(
          isEnabled: enabled,
          updatedAt: DateTime.now(),
        );
        batch.update(doc.reference, updatedPreference.toMap());
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      print('Error toggling notification category: $e');
      return false;
    }
  }

  // Habilitar/deshabilitar canal globalmente
  Future<bool> toggleChannel(
    String userId,
    NotificationChannel channel,
    bool enabled,
  ) async {
    try {
      final profileQuery = await _firestore
          .collection('notification_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (profileQuery.docs.isEmpty) return false;
      
      final profile = NotificationProfile.fromFirestore(profileQuery.docs.first);
      final updatedProfile = profile.copyWith(
        globalChannelSettings: {...profile.globalChannelSettings}..[channel] = enabled,
        updatedAt: DateTime.now(),
      );
      
      await updateProfile(updatedProfile);
      
      // También actualizar todas las preferencias individuales
      final preferencesQuery = await _firestore
          .collection('notification_preferences')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      
      for (final doc in preferencesQuery.docs) {
        final preference = NotificationPreference.fromFirestore(doc);
        final updatedPreference = preference.copyWith(
          channelSettings: {...preference.channelSettings}..[channel] = enabled,
          updatedAt: DateTime.now(),
        );
        batch.update(doc.reference, updatedPreference.toMap());
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      print('Error toggling notification channel: $e');
      return false;
    }
  }

  // Verificar si usuario puede recibir notificación
  Future<bool> canReceiveNotification(
    String userId,
    NotificationType type,
    NotificationChannel channel,
  ) async {
    try {
      // Obtener perfil
      final profileQuery = await _firestore
          .collection('notification_profiles')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (profileQuery.docs.isEmpty) return false;
      
      final profile = NotificationProfile.fromFirestore(profileQuery.docs.first);
      
      // Verificar si está en horas silenciosas
      if (profile.isInQuietHours()) {
        return false;
      }
      
      // Verificar si el canal está habilitado globalmente
      if (!profile.isChannelGloballyEnabled(channel)) {
        return false;
      }
      
      // Obtener preferencia específica
      final preferenceQuery = await _firestore
          .collection('notification_preferences')
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: type.value)
          .limit(1)
          .get();
      
      if (preferenceQuery.docs.isEmpty) return false;
      
      final preference = NotificationPreference.fromFirestore(preferenceQuery.docs.first);
      
      // Verificar si la categoría está habilitada
      if (!profile.isCategoryEnabled(preference.category)) {
        return false;
      }
      
      // Verificar si la preferencia está habilitada
      if (!preference.isEnabled) {
        return false;
      }
      
      // Verificar si el canal específico está habilitado
      if (!preference.isChannelEnabled(channel)) {
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  // Obtener estadísticas de notificaciones del usuario
  Future<Map<String, dynamic>> getUserNotificationStats(String userId) async {
    try {
      final analyticsQuery = await _firestore
          .collection('notification_analytics')
          .where('userId', isEqualTo: userId)
          .get();
      
      final analytics = analyticsQuery.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();
      
      // Calcular estadísticas
      final totalSent = analytics.length;
      final totalDelivered = analytics.where((a) => a.isDelivered).length;
      final totalOpened = analytics.where((a) => a.isOpened).length;
      final totalClicked = analytics.where((a) => a.isClicked).length;
      
      // Estadísticas por tipo
      final statsByType = <String, Map<String, dynamic>>{};
      for (final analytic in analytics) {
        final type = analytic.type.displayName;
        final typeStats = statsByType[type] ?? {
          'sent': 0,
          'delivered': 0,
          'opened': 0,
          'clicked': 0,
        };
        typeStats['sent'] = (typeStats['sent'] ?? 0) + 1;
        if (analytic.isDelivered) typeStats['delivered'] = (typeStats['delivered'] ?? 0) + 1;
        if (analytic.isOpened) typeStats['opened'] = (typeStats['opened'] ?? 0) + 1;
        if (analytic.isClicked) typeStats['clicked'] = (typeStats['clicked'] ?? 0) + 1;
        statsByType[type] = typeStats;
      }
      
      // Estadísticas por canal
      final statsByChannel = <String, Map<String, dynamic>>{};
      for (final analytic in analytics) {
        final channel = analytic.channel.displayName;
        final channelStats = statsByChannel[channel] ?? {
          'sent': 0,
          'delivered': 0,
          'opened': 0,
          'clicked': 0,
        };
        channelStats['sent'] = (channelStats['sent'] ?? 0) + 1;
        if (analytic.isDelivered) channelStats['delivered'] = (channelStats['delivered'] ?? 0) + 1;
        if (analytic.isOpened) channelStats['opened'] = (channelStats['opened'] ?? 0) + 1;
        if (analytic.isClicked) channelStats['clicked'] = (channelStats['clicked'] ?? 0) + 1;
        statsByChannel[channel] = channelStats;
      }
      
      // Tiempos promedio
      final avgTimeToOpen = analytics
          .where((a) => a.timeToOpen != null)
          .map((a) => a.timeToOpen!.inSeconds)
          .toList();
      
      final avgTimeToClick = analytics
          .where((a) => a.timeToClick != null)
          .map((a) => a.timeToClick!.inSeconds)
          .toList();
      
      return {
        'totalSent': totalSent,
        'totalDelivered': totalDelivered,
        'totalOpened': totalOpened,
        'totalClicked': totalClicked,
        'deliveryRate': totalSent > 0 ? totalDelivered / totalSent : 0.0,
        'openRate': totalDelivered > 0 ? totalOpened / totalDelivered : 0.0,
        'clickRate': totalOpened > 0 ? totalClicked / totalOpened : 0.0,
        'avgTimeToOpen': avgTimeToOpen.isNotEmpty 
            ? avgTimeToOpen.reduce((a, b) => a + b) / avgTimeToOpen.length 
            : 0.0,
        'avgTimeToClick': avgTimeToClick.isNotEmpty 
            ? avgTimeToClick.reduce((a, b) => a + b) / avgTimeToClick.length 
            : 0.0,
        'statsByType': statsByType,
        'statsByChannel': statsByChannel,
      };
    } catch (e) {
      print('Error getting notification stats: $e');
      return {};
    }
  }

  // Obtener historial de notificaciones del usuario
  Stream<List<NotificationAnalytics>> getUserNotificationHistory(
    String userId, {
    int limit = 50,
    NotificationType? type,
    NotificationChannel? channel,
  }) {
    Query query = _firestore
        .collection('notification_analytics')
        .where('userId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .limit(limit);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type.value);
    }
    
    if (channel != null) {
      query = query.where('channel', isEqualTo: channel.value);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationAnalytics.fromFirestore(doc))
          .toList();
    });
  }

  // Marcar notificación como abierta
  Future<bool> markNotificationAsOpened(String analyticsId) async {
    try {
      final docRef = _firestore.collection('notification_analytics').doc(analyticsId);
      final doc = await docRef.get();
      
      if (!doc.exists) return false;
      
      final analytics = NotificationAnalytics.fromFirestore(doc);
      final updatedAnalytics = analytics.copyWith(
        openedAt: DateTime.now(),
        isOpened: true,
        timeToOpen: DateTime.now().difference(analytics.sentAt),
      );
      
      await docRef.update(updatedAnalytics.toMap());
      
      return true;
    } catch (e) {
      print('Error marking notification as opened: $e');
      return false;
    }
  }

  // Marcar notificación como clickeada
  Future<bool> markNotificationAsClicked(String analyticsId) async {
    try {
      final docRef = _firestore.collection('notification_analytics').doc(analyticsId);
      final doc = await docRef.get();
      
      if (!doc.exists) return false;
      
      final analytics = NotificationAnalytics.fromFirestore(doc);
      final updatedAnalytics = analytics.copyWith(
        clickedAt: DateTime.now(),
        isClicked: true,
        timeToClick: DateTime.now().difference(analytics.sentAt),
      );
      
      await docRef.update(updatedAnalytics.toMap());
      
      return true;
    } catch (e) {
      print('Error marking notification as clicked: $e');
      return false;
    }
  }

  // Obtener preferencias del usuario actual
  Stream<NotificationProfile?> getCurrentUserProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return getUserProfile(user.uid);
  }

  // Obtener preferencias del usuario actual
  Stream<List<NotificationPreference>> getCurrentUserPreferences() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getUserPreferences(user.uid);
  }

  // Obtener estadísticas del usuario actual
  Future<Map<String, dynamic>> getCurrentUserStats() async {
    final user = _auth.currentUser;
    if (user == null) return {};
    return getUserNotificationStats(user.uid);
  }

  // Obtener historial del usuario actual
  Stream<List<NotificationAnalytics>> getCurrentUserHistory({
    int limit = 50,
    NotificationType? type,
    NotificationChannel? channel,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getUserNotificationHistory(user.uid, limit: limit, type: type, channel: channel);
  }

  // Obtener predicción de engagement del usuario actual
  Future<Map<String, dynamic>> getCurrentUserPrediction() async {
    final user = _auth.currentUser;
    if (user == null) return {};
    
    // Simulación de predicción (en producción esto usaría ML)
    final stats = await getUserNotificationStats(user.uid);
    final openRate = stats['openRate'] ?? 0.0;
    final clickRate = stats['clickRate'] ?? 0.0;
    
    // Calcular engagement predicho basado en estadísticas históricas
    final predictedEngagement = (openRate + clickRate) / 2;
    
    // Generar recomendaciones basadas en el comportamiento
    final recommendations = <String>[];
    if (openRate < 0.5) {
      recommendations.add('Optimizar horarios de envío');
    }
    if (clickRate < 0.3) {
      recommendations.add('Personalizar contenido');
    }
    if (stats['totalSent'] > 10) {
      recommendations.add('Reducir frecuencia de envío');
    }
    
    return {
      'predictedEngagement': predictedEngagement,
      'confidence': 0.8, // Simulado
      'recommendations': recommendations,
      'optimalSendTimes': {
        'peakHour': 19, // 7 PM
        'peakDay': 'friday',
      },
      'engagementRate': predictedEngagement,
    };
  }
}
