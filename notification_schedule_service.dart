// ============================================================================
// services/notification_schedule_service.dart - Servicio de Programación de Notificaciones
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../models/notification_template_model.dart';
import '../models/notification_preference_model.dart';
import 'notification_preference_service.dart';

class NotificationScheduleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();

  // Obtener plantillas activas
  Stream<List<NotificationTemplate>> getActiveTemplates() {
    return _firestore
        .collection('notification_templates')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationTemplate.fromFirestore(doc))
              .toList();
        });
  }

  // Obtener plantilla por tipo
  Stream<NotificationTemplate?> getTemplateByType(NotificationTemplateType type) {
    return _firestore
        .collection('notification_templates')
        .where('type', isEqualTo: type.value)
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;
          return NotificationTemplate.fromFirestore(docs.first);
        });
  }

  // Obtener plantilla por ID
  Future<NotificationTemplate?> getTemplateById(String templateId) async {
    try {
      final doc = await _firestore.collection('notification_templates').doc(templateId).get();
      if (!doc.exists) return null;
      return NotificationTemplate.fromFirestore(doc);
    } catch (e) {
      print('Error getting template by ID: $e');
      return null;
    }
  }

  // Crear nueva plantilla
  Future<bool> createTemplate(NotificationTemplate template) async {
    try {
      await _firestore
          .collection('notification_templates')
          .doc(template.id)
          .set(template.toMap());
      return true;
    } catch (e) {
      print('Error creating notification template: $e');
      return false;
    }
  }

  // Actualizar plantilla
  Future<bool> updateTemplate(NotificationTemplate template) async {
    try {
      final updatedTemplate = template.copyWith(
        version: template.version + 1,
        updatedAt: DateTime.now(),
      );
      
      await _firestore
          .collection('notification_templates')
          .doc(template.id)
          .set(updatedTemplate.toMap());
      return true;
    } catch (e) {
      print('Error updating notification template: $e');
      return false;
    }
  }

  // Eliminar plantilla (desactivar)
  Future<bool> deactivateTemplate(String templateId) async {
    try {
      await _firestore
          .collection('notification_templates')
          .doc(templateId)
          .update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      print('Error deactivating notification template: $e');
      return false;
    }
  }

  // Enviar notificación personalizada
  Future<Map<String, dynamic>> sendPersonalizedNotification({
    required String userId,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> variables,
    NotificationChannel channel = NotificationChannel.push,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Verificar si el usuario puede recibir esta notificación
      final canReceive = await _preferenceService.canReceiveNotification(
        userId,
        _getNotificationTypeFromTemplateType(templateType),
        channel,
      );
      
      if (!canReceive) {
        return {
          'success': false,
          'message': 'Usuario no puede recibir este tipo de notificación',
        };
      }

      // Obtener plantilla
      final template = await getTemplateByType(templateType).first;
      if (template == null) {
        return {
          'success': false,
          'message': 'No se encontró plantilla para este tipo de notificación',
        };
      }

      // Validar variables requeridas
      if (!template.validateVariables(variables)) {
        final missing = template.getMissingVariables(variables);
        return {
          'success': false,
          'message': 'Faltan variables requeridas: ${missing.join(', ')}',
        };
      }

      // Renderizar plantilla
      final rendered = template.render(variables);

      // Crear analytics
      final analytics = NotificationAnalytics.create(
        userId: userId,
        type: _getNotificationTypeFromTemplateType(templateType),
        channel: channel,
        metadata: metadata ?? {},
      );

      // Guardar analytics
      await _firestore
          .collection('notification_analytics')
          .doc(analytics.id)
          .set(analytics.toMap());

      // Aquí iría la lógica real de envío (integración con FCM, email service, etc.)
      final sent = await _sendNotification(
        userId: userId,
        title: rendered['title'],
        body: rendered['body'],
        imageUrl: rendered['imageUrl'],
        data: rendered['data'],
        channel: channel,
        analyticsId: analytics.id,
      );

      if (sent) {
        // Marcar como entregado
        final updatedAnalytics = analytics.copyWith(
          isDelivered: true,
        );
        await _firestore
            .collection('notification_analytics')
            .doc(analytics.id)
            .update(updatedAnalytics.toMap());

        return {
          'success': true,
          'message': 'Notificación enviada exitosamente',
          'analyticsId': analytics.id,
        };
      } else {
        return {
          'success': false,
          'message': 'Error al enviar la notificación',
          'analyticsId': analytics.id,
        };
      }
    } catch (e) {
      print('Error sending personalized notification: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Enviar notificación en lote
  Future<Map<String, dynamic>> sendBatchNotification({
    required List<String> userIds,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> variables,
    NotificationChannel channel = NotificationChannel.push,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      int successful = 0;
      int failed = 0;
      final List<String> failedUsers = [];

      for (final userId in userIds) {
        final result = await sendPersonalizedNotification(
          userId: userId,
          templateType: templateType,
          variables: variables,
          channel: channel,
          metadata: metadata,
        );

        if (result['success']) {
          successful++;
        } else {
          failed++;
          failedUsers.add(userId);
        }
      }

      return {
        'success': true,
        'successful': successful,
        'failed': failed,
        'failedUsers': failedUsers,
        'total': userIds.length,
      };
    } catch (e) {
      print('Error sending batch notification: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Programar notificación
  Future<bool> scheduleNotification({
    required String userId,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> variables,
    required DateTime scheduledAt,
    NotificationChannel channel = NotificationChannel.push,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final scheduledNotification = {
        'userId': userId,
        'templateType': templateType.value,
        'variables': variables,
        'channel': channel.value,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'metadata': metadata ?? {},
        'isSent': false,
        'createdAt': Timestamp.now(),
      };

      await _firestore
          .collection('scheduled_notifications')
          .add(scheduledNotification);

      return true;
    } catch (e) {
      print('Error scheduling notification: $e');
      return false;
    }
  }

  // Obtener notificaciones programadas
  Stream<List<Map<String, dynamic>>> getScheduledNotifications(String userId) {
    return _firestore
        .collection('scheduled_notifications')
        .where('userId', isEqualTo: userId)
        .where('isSent', isEqualTo: false)
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          }).toList();
        });
  }

  // Cancelar notificación programada
  Future<bool> cancelScheduledNotification(String scheduledId) async {
    try {
      await _firestore
          .collection('scheduled_notifications')
          .doc(scheduledId)
          .delete();
      return true;
    } catch (e) {
      print('Error cancelling scheduled notification: $e');
      return false;
    }
  }

  // Procesar notificaciones programadas (para ejecución periódica)
  Future<void> processScheduledNotifications() async {
    try {
      final now = Timestamp.now();
      
      final scheduledQuery = await _firestore
          .collection('scheduled_notifications')
          .where('isSent', isEqualTo: false)
          .where('scheduledAt', isLessThanOrEqualTo: now)
          .get();

      for (final doc in scheduledQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final result = await sendPersonalizedNotification(
          userId: data['userId'],
          templateType: NotificationTemplateType.fromString(data['templateType']),
          variables: data['variables'] as Map<String, dynamic>,
          channel: NotificationChannel.fromString(data['channel']),
          metadata: data['metadata'] as Map<String, dynamic>?,
        );

        if (result['success']) {
          // Marcar como enviada
          await _firestore
              .collection('scheduled_notifications')
              .doc(doc.id)
              .update({
            'isSent': true,
            'sentAt': Timestamp.now(),
          });
        }
      }
    } catch (e) {
      print('Error processing scheduled notifications: $e');
    }
  }

  // Crear campaña de notificaciones
  Future<bool> createCampaign(NotificationCampaign campaign) async {
    try {
      await _firestore
          .collection('notification_campaigns')
          .doc(campaign.id)
          .set(campaign.toMap());
      return true;
    } catch (e) {
      print('Error creating notification campaign: $e');
      return false;
    }
  }

  // Obtener campañas
  Stream<List<NotificationCampaign>> getCampaigns({bool? isActive}) {
    Query query = _firestore
        .collection('notification_campaigns')
        .orderBy('createdAt', descending: true);
    
    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }
    
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationCampaign.fromFirestore(doc))
          .toList();
    });
  }

  // Ejecutar campaña
  Future<Map<String, dynamic>> executeCampaign(String campaignId) async {
    try {
      final campaignDoc = await _firestore
          .collection('notification_campaigns')
          .doc(campaignId)
          .get();
      
      if (!campaignDoc.exists) {
        return {
          'success': false,
          'message': 'Campaña no encontrada',
        };
      }

      final campaign = NotificationCampaign.fromFirestore(campaignDoc);
      
      if (!campaign.isReadyToSend) {
        return {
          'success': false,
          'message': 'La campaña no está lista para enviarse',
        };
      }

      // Obtener plantilla
      final template = await getTemplateById(campaign.templateId);
      if (template == null) {
        return {
          'success': false,
          'message': 'Plantilla no encontrada',
        };
      }

      // Enviar notificaciones en lote
      final result = await sendBatchNotification(
        userIds: campaign.targetUserIds,
        templateType: template.type,
        variables: campaign.campaignVariables,
        metadata: {
          'campaignId': campaign.id,
          'campaignName': campaign.name,
        },
      );

      // Actualizar campaña
      final updatedCampaign = campaign.copyWith(
        sentAt: DateTime.now(),
        successfulSends: campaign.successfulSends + (result['successful'] ?? 0) as int,
        failedSends: campaign.failedSends + (result['failed'] ?? 0) as int,
        isCompleted: true,
        isActive: false,
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('notification_campaigns')
          .doc(campaign.id)
          .set(updatedCampaign.toMap());

      return {
        'success': true,
        'message': 'Campaña ejecutada exitosamente',
        'result': result,
      };
    } catch (e) {
      print('Error executing campaign: $e');
      return {
        'success': false,
        'message': 'Error: $e',
      };
    }
  }

  // Evaluar reglas de notificación
  Future<List<Map<String, dynamic>>> evaluateRules(
    String userId,
    Map<String, dynamic> context,
  ) async {
    try {
      final rulesQuery = await _firestore
          .collection('notification_rules')
          .where('isActive', isEqualTo: true)
          .orderBy('priority', descending: true)
          .get();

      final triggeredRules = <Map<String, dynamic>>[];

      for (final doc in rulesQuery.docs) {
        final rule = NotificationRule.fromFirestore(doc);
        
        if (rule.evaluateConditions(context)) {
          triggeredRules.add({
            'ruleId': rule.id,
            'ruleName': rule.name,
            'templateType': rule.templateType,
            'actions': rule.actions,
          });
        }
      }

      return triggeredRules;
    } catch (e) {
      print('Error evaluating notification rules: $e');
      return [];
    }
  }

  // Método auxiliar para enviar notificación (integración real)
  Future<bool> _sendNotification({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    required Map<String, dynamic> data,
    required NotificationChannel channel,
    required String analyticsId,
  }) async {
    try {
      switch (channel) {
        case NotificationChannel.push:
          return await _sendPushNotification(
            userId: userId,
            title: title,
            body: body,
            imageUrl: imageUrl,
            data: {...data, 'analyticsId': analyticsId},
          );
        case NotificationChannel.email:
          return await _sendEmailNotification(
            userId: userId,
            title: title,
            body: body,
            data: data,
          );
        case NotificationChannel.sms:
          return await _sendSMSNotification(
            userId: userId,
            title: title,
            body: body,
            data: data,
          );
        case NotificationChannel.in_app:
          return await _sendInAppNotification(
            userId: userId,
            title: title,
            body: body,
            imageUrl: imageUrl,
            data: data,
          );
      }
    } catch (e) {
      print('Error sending notification: $e');
      return false;
    }
  }

  // Métodos de envío específicos (implementaciones básicas)
  Future<bool> _sendPushNotification({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    required Map<String, dynamic> data,
  }) async {
    // Aquí iría la integración real con Firebase Cloud Messaging
    // Por ahora, solo simulamos el envío
    print('📱 Push notification sent to $userId: $title - $body');
    return true;
  }

  Future<bool> _sendEmailNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // Aquí iría la integración real con un servicio de email
    print('📧 Email notification sent to $userId: $title');
    return true;
  }

  Future<bool> _sendSMSNotification({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    // Aquí iría la integración real con un servicio de SMS
    print('📱 SMS notification sent to $userId: $title');
    return true;
  }

  Future<bool> _sendInAppNotification({
    required String userId,
    required String title,
    required String body,
    String? imageUrl,
    required Map<String, dynamic> data,
  }) async {
    // Aquí iría la lógica para mostrar notificación en la app
    print('🔔 In-app notification sent to $userId: $title - $body');
    return true;
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

  // Obtener campañas del usuario actual
  Stream<List<NotificationCampaign>> getCurrentUserCampaigns() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    
    return _firestore
        .collection('notification_campaigns')
        .where('targetUserIds', arrayContains: user.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => NotificationCampaign.fromFirestore(doc))
              .toList();
        });
  }

  // Obtener notificaciones programadas del usuario actual
  Stream<List<Map<String, dynamic>>> getCurrentUserScheduledNotifications() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);
    return getScheduledNotifications(user.uid);
  }
}
