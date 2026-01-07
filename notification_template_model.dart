// ============================================================================
// models/notification_template_model.dart - Modelo de Plantillas de Notificaciones
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationTemplateType {
  order_status_update('order_status_update', 'Actualización de Estado de Pedido'),
  order_delivered('order_delivered', 'Pedido Entregado'),
  order_cancelled('order_cancelled', 'Pedido Cancelado'),
  promotion_new('promotion_new', 'Nueva Promoción'),
  promotion_expiring('promotion_expiring', 'Promoción por Expirar'),
  loyalty_points_earned('loyalty_points_earned', 'Puntos Ganados'),
  loyalty_tier_upgrade('loyalty_tier_upgrade', 'Upgrade de Nivel'),
  loyalty_reward_available('loyalty_reward_available', 'Recompensa Disponible'),
  business_recommendation('business_recommendation', 'Recomendación de Negocio'),
  review_request('review_request', 'Solicitud de Reseña'),
  referral_invite('referral_invite', 'Invitación de Referido'),
  cart_abandoned('cart_abandoned', 'Carrito Abandonado'),
  favorite_business_update('favorite_business_update', 'Actualización de Negocio Favorito'),
  system_maintenance('system_maintenance', 'Mantenimiento del Sistema'),
  security_alert('security_alert', 'Alerta de Seguridad');

  const NotificationTemplateType(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationTemplateType fromString(String value) {
    return NotificationTemplateType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => NotificationTemplateType.order_status_update,
    );
  }
}

enum NotificationPriority {
  low('low', 'Baja'),
  normal('normal', 'Normal'),
  high('high', 'Alta'),
  urgent('urgent', 'Urgente');

  const NotificationPriority(this.value, this.displayName);
  final String value;
  final String displayName;

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => NotificationPriority.normal,
    );
  }
}

class NotificationTemplate {
  final String id;
  final String name;
  final NotificationTemplateType type;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic> defaultData;
  final NotificationPriority priority;
  final List<String> requiredVariables;
  final List<String> optionalVariables;
  final Map<String, String> variableDescriptions;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const NotificationTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.title,
    required this.body,
    this.imageUrl,
    required this.defaultData,
    required this.priority,
    required this.requiredVariables,
    required this.optionalVariables,
    required this.variableDescriptions,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory NotificationTemplate.create({
    required String name,
    required NotificationTemplateType type,
    required String title,
    required String body,
    NotificationPriority priority = NotificationPriority.normal,
    String? imageUrl,
    String? createdBy,
  }) {
    return NotificationTemplate(
      id: FirebaseFirestore.instance.collection('notification_templates').doc().id,
      name: name,
      type: type,
      title: title,
      body: body,
      imageUrl: imageUrl,
      defaultData: {},
      priority: priority,
      requiredVariables: [],
      optionalVariables: [],
      variableDescriptions: {},
      isActive: true,
      version: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  factory NotificationTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      type: NotificationTemplateType.fromString(data['type'] ?? ''),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      imageUrl: data['imageUrl'],
      defaultData: data['defaultData'] as Map<String, dynamic>? ?? {},
      priority: NotificationPriority.fromString(data['priority'] ?? ''),
      requiredVariables: List<String>.from(data['requiredVariables'] ?? []),
      optionalVariables: List<String>.from(data['optionalVariables'] ?? []),
      variableDescriptions: Map<String, String>.from(data['variableDescriptions'] ?? {}),
      isActive: data['isActive'] ?? true,
      version: data['version'] ?? 1,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.value,
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'defaultData': defaultData,
      'priority': priority.value,
      'requiredVariables': requiredVariables,
      'optionalVariables': optionalVariables,
      'variableDescriptions': variableDescriptions,
      'isActive': isActive,
      'version': version,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  NotificationTemplate copyWith({
    String? id,
    String? name,
    NotificationTemplateType? type,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? defaultData,
    NotificationPriority? priority,
    List<String>? requiredVariables,
    List<String>? optionalVariables,
    Map<String, String>? variableDescriptions,
    bool? isActive,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return NotificationTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      defaultData: defaultData ?? this.defaultData,
      priority: priority ?? this.priority,
      requiredVariables: requiredVariables ?? this.requiredVariables,
      optionalVariables: optionalVariables ?? this.optionalVariables,
      variableDescriptions: variableDescriptions ?? this.variableDescriptions,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Métodos de utilidad
  Map<String, dynamic> render(Map<String, dynamic> variables) {
    final mergedData = Map<String, dynamic>.from(defaultData);
    mergedData.addAll(variables);
    
    return {
      'title': _renderText(title, mergedData),
      'body': _renderText(body, mergedData),
      'imageUrl': _renderText(imageUrl ?? '', mergedData),
      'data': mergedData,
    };
  }

  String _renderText(String text, Map<String, dynamic> variables) {
    String result = text;
    
    for (final entry in variables.entries) {
      final placeholder = '{{${entry.key}}}';
      result = result.replaceAll(placeholder, entry.value.toString());
    }
    
    return result;
  }

  bool validateVariables(Map<String, dynamic> variables) {
    for (final requiredVar in requiredVariables) {
      if (!variables.containsKey(requiredVar) || variables[requiredVar] == null) {
        return false;
      }
    }
    return true;
  }

  List<String> getMissingVariables(Map<String, dynamic> variables) {
    final missing = <String>[];
    
    for (final requiredVar in requiredVariables) {
      if (!variables.containsKey(requiredVar) || variables[requiredVar] == null) {
        missing.add(requiredVar);
      }
    }
    
    return missing;
  }
}

class NotificationCampaign {
  final String id;
  final String name;
  final String description;
  final String templateId;
  final List<String> targetUserIds;
  final Map<String, dynamic> campaignVariables;
  final DateTime scheduledAt;
  final DateTime? sentAt;
  final bool isActive;
  final bool isCompleted;
  final int totalRecipients;
  final int successfulSends;
  final int failedSends;
  final Map<String, dynamic> performanceMetrics;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const NotificationCampaign({
    required this.id,
    required this.name,
    required this.description,
    required this.templateId,
    required this.targetUserIds,
    required this.campaignVariables,
    required this.scheduledAt,
    this.sentAt,
    required this.isActive,
    required this.isCompleted,
    required this.totalRecipients,
    required this.successfulSends,
    required this.failedSends,
    required this.performanceMetrics,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory NotificationCampaign.create({
    required String name,
    required String description,
    required String templateId,
    required List<String> targetUserIds,
    required Map<String, dynamic> campaignVariables,
    required DateTime scheduledAt,
    String? createdBy,
  }) {
    return NotificationCampaign(
      id: FirebaseFirestore.instance.collection('notification_campaigns').doc().id,
      name: name,
      description: description,
      templateId: templateId,
      targetUserIds: targetUserIds,
      campaignVariables: campaignVariables,
      scheduledAt: scheduledAt,
      isActive: true,
      isCompleted: false,
      totalRecipients: targetUserIds.length,
      successfulSends: 0,
      failedSends: 0,
      performanceMetrics: {},
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  factory NotificationCampaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationCampaign(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      templateId: data['templateId'] ?? '',
      targetUserIds: List<String>.from(data['targetUserIds'] ?? []),
      campaignVariables: data['campaignVariables'] as Map<String, dynamic>? ?? {},
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] ?? true,
      isCompleted: data['isCompleted'] ?? false,
      totalRecipients: data['totalRecipients'] ?? 0,
      successfulSends: data['successfulSends'] ?? 0,
      failedSends: data['failedSends'] ?? 0,
      performanceMetrics: data['performanceMetrics'] as Map<String, dynamic>? ?? {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'templateId': templateId,
      'targetUserIds': targetUserIds,
      'campaignVariables': campaignVariables,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'sentAt': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'isActive': isActive,
      'isCompleted': isCompleted,
      'totalRecipients': totalRecipients,
      'successfulSends': successfulSends,
      'failedSends': failedSends,
      'performanceMetrics': performanceMetrics,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  NotificationCampaign copyWith({
    String? id,
    String? name,
    String? description,
    String? templateId,
    List<String>? targetUserIds,
    Map<String, dynamic>? campaignVariables,
    DateTime? scheduledAt,
    DateTime? sentAt,
    bool? isActive,
    bool? isCompleted,
    int? totalRecipients,
    int? successfulSends,
    int? failedSends,
    Map<String, dynamic>? performanceMetrics,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return NotificationCampaign(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      templateId: templateId ?? this.templateId,
      targetUserIds: targetUserIds ?? this.targetUserIds,
      campaignVariables: campaignVariables ?? this.campaignVariables,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      totalRecipients: totalRecipients ?? this.totalRecipients,
      successfulSends: successfulSends ?? this.successfulSends,
      failedSends: failedSends ?? this.failedSends,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Métodos de utilidad
  double get successRate {
    if (totalRecipients == 0) return 0.0;
    return successfulSends / totalRecipients;
  }

  double get failureRate {
    if (totalRecipients == 0) return 0.0;
    return failedSends / totalRecipients;
  }

  bool get isReadyToSend {
    return isActive && !isCompleted && DateTime.now().isAfter(scheduledAt);
  }

  void markAsCompleted() {
    final updatedCampaign = copyWith(
      isCompleted: true,
      isActive: false,
      sentAt: DateTime.now(),
    );
    // Aquí iría la lógica para actualizar en Firestore
  }

  void updateSendCounts(int successful, int failed) {
    final updatedCampaign = copyWith(
      successfulSends: successfulSends + successful,
      failedSends: failedSends + failed,
      updatedAt: DateTime.now(),
    );
    // Aquí iría la lógica para actualizar en Firestore
  }
}

class NotificationRule {
  final String id;
  final String name;
  final String description;
  final NotificationTemplateType templateType;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> actions;
  final int priority;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const NotificationRule({
    required this.id,
    required this.name,
    required this.description,
    required this.templateType,
    required this.conditions,
    required this.actions,
    required this.priority,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory NotificationRule.create({
    required String name,
    required String description,
    required NotificationTemplateType templateType,
    required Map<String, dynamic> conditions,
    required Map<String, dynamic> actions,
    int priority = 0,
    String? createdBy,
  }) {
    return NotificationRule(
      id: FirebaseFirestore.instance.collection('notification_rules').doc().id,
      name: name,
      description: description,
      templateType: templateType,
      conditions: conditions,
      actions: actions,
      priority: priority,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: createdBy,
    );
  }

  factory NotificationRule.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationRule(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      templateType: NotificationTemplateType.fromString(data['templateType'] ?? ''),
      conditions: data['conditions'] as Map<String, dynamic>? ?? {},
      actions: data['actions'] as Map<String, dynamic>? ?? {},
      priority: data['priority'] ?? 0,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'templateType': templateType.value,
      'conditions': conditions,
      'actions': actions,
      'priority': priority,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
    };
  }

  NotificationRule copyWith({
    String? id,
    String? name,
    String? description,
    NotificationTemplateType? templateType,
    Map<String, dynamic>? conditions,
    Map<String, dynamic>? actions,
    int? priority,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return NotificationRule(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      templateType: templateType ?? this.templateType,
      conditions: conditions ?? this.conditions,
      actions: actions ?? this.actions,
      priority: priority ?? this.priority,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Métodos de utilidad
  bool evaluateConditions(Map<String, dynamic> context) {
    for (final condition in conditions.entries) {
      if (!_evaluateCondition(condition.key, condition.value, context)) {
        return false;
      }
    }
    return true;
  }

  bool _evaluateCondition(String field, dynamic expectedValue, Map<String, dynamic> context) {
    final actualValue = context[field];
    
    if (actualValue == null && expectedValue != null) {
      return false;
    }
    
    if (expectedValue is Map && expectedValue.containsKey('operator')) {
      return _evaluateOperatorCondition(expectedValue as Map<String, dynamic>, actualValue);
    }
    
    return actualValue == expectedValue;
  }

  bool _evaluateOperatorCondition(Map<String, dynamic> condition, dynamic actualValue) {
    final operator = condition['operator'];
    final expectedValue = condition['value'];
    
    switch (operator) {
      case 'equals':
        return actualValue == expectedValue;
      case 'not_equals':
        return actualValue != expectedValue;
      case 'greater_than':
        return actualValue > expectedValue;
      case 'less_than':
        return actualValue < expectedValue;
      case 'greater_than_or_equal':
        return actualValue >= expectedValue;
      case 'less_than_or_equal':
        return actualValue <= expectedValue;
      case 'contains':
        if (actualValue is String && expectedValue is String) {
          return actualValue.contains(expectedValue);
        }
        if (actualValue is List) {
          return actualValue.contains(expectedValue);
        }
        return false;
      case 'in':
        if (expectedValue is List) {
          return expectedValue.contains(actualValue);
        }
        return false;
      default:
        return false;
    }
  }
}
