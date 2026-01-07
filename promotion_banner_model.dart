// ============================================================================
// models/promotion_banner_model.dart - Modelo de Banners Promocionales Dinámicos
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum BannerType {
  hero,           // Banner principal grande
  carousel,       // Carrusel de imágenes
  flash,          // Banner de oferta flash
  category,       // Banner de categoría
  business,       // Banner de negocio específico
  referral,       // Banner de referido
  loyalty,        // Banner de lealtad
  seasonal,       // Banner de temporada
  countdown,      // Banner con cuenta regresiva
  interactive,    // Banner interactivo
}

enum BannerAction {
  none,           // Sin acción
  navigate,       // Navegar a pantalla
  coupon,         // Mostrar/activar cupón
  business,       // Ir a negocio
  category,       // Ir a categoría
  search,         // Búsqueda específica
  share,          // Compartir
  external,       // Link externo
  call,           // Llamar
  order,          // Hacer pedido
}

enum BannerTarget {
  all,            // Todos los usuarios
  new_users,      // Usuarios nuevos
  returning,      // Usuarios recurrentes
  premium,        // Usuarios premium
  inactive,       // Usuarios inactivos
  location,       // Por ubicación
  custom,         // Segmento personalizado
}

class PromotionBanner {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final BannerType type;
  final BannerAction action;
  final BannerTarget target;
  final String? actionData; // Datos para la acción (ej: businessId, couponCode)
  final String? externalUrl; // URL externa si action es external
  final Color backgroundColor;
  final Color textColor;
  final Color buttonColor;
  final String buttonText;
  final bool isActive;
  final int priority; // Prioridad de visualización (mayor = más importante)
  final DateTime startDate;
  final DateTime endDate;
  final List<String>? targetUserIds; // IDs de usuarios específicos
  final List<String>? targetBusinessIds; // IDs de negocios específicos
  final List<String>? targetCategories; // Categorías específicas
  final Map<String, dynamic>? locationFilter; // Filtro por ubicación
  final int? maxImpressions; // Máximo de impresiones
  final int currentImpressions; // Impresiones actuales
  final int? maxClicks; // Máximo de clics
  final int currentClicks; // Clics actuales
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> metadata; // Datos adicionales

  PromotionBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.type,
    required this.action,
    required this.target,
    this.actionData,
    this.externalUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.buttonColor,
    required this.buttonText,
    required this.isActive,
    required this.priority,
    required this.startDate,
    required this.endDate,
    this.targetUserIds,
    this.targetBusinessIds,
    this.targetCategories,
    this.locationFilter,
    this.maxImpressions,
    this.currentImpressions = 0,
    this.maxClicks,
    this.currentClicks = 0,
    required this.createdAt,
    this.updatedAt,
    this.metadata = const {},
  });

  // Crear desde Firestore
  factory PromotionBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PromotionBanner.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory PromotionBanner.fromMap(Map<String, dynamic> map, String id) {
    return PromotionBanner(
      id: id,
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      type: BannerTypeExtension.fromString(map['type'] ?? 'hero'),
      action: BannerActionExtension.fromString(map['action'] ?? 'none'),
      target: BannerTargetExtension.fromString(map['target'] ?? 'all'),
      actionData: map['actionData'],
      externalUrl: map['externalUrl'],
      backgroundColor: _parseColor(map['backgroundColor']),
      textColor: _parseColor(map['textColor']),
      buttonColor: _parseColor(map['buttonColor']),
      buttonText: map['buttonText'] ?? '',
      isActive: map['isActive'] ?? true,
      priority: map['priority'] ?? 0,
      startDate: map['startDate'] != null 
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate()
          : DateTime.now().add(const Duration(days: 30)),
      targetUserIds: map['targetUserIds'] != null 
          ? List<String>.from(map['targetUserIds'])
          : null,
      targetBusinessIds: map['targetBusinessIds'] != null 
          ? List<String>.from(map['targetBusinessIds'])
          : null,
      targetCategories: map['targetCategories'] != null 
          ? List<String>.from(map['targetCategories'])
          : null,
      locationFilter: map['locationFilter'],
      maxImpressions: map['maxImpressions'],
      currentImpressions: map['currentImpressions'] ?? 0,
      maxClicks: map['maxClicks'],
      currentClicks: map['currentClicks'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'imageUrl': imageUrl,
      'type': type.value,
      'action': action.value,
      'target': target.value,
      'actionData': actionData,
      'externalUrl': externalUrl,
      'backgroundColor': backgroundColor.value,
      'textColor': textColor.value,
      'buttonColor': buttonColor.value,
      'buttonText': buttonText,
      'isActive': isActive,
      'priority': priority,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'targetUserIds': targetUserIds,
      'targetBusinessIds': targetBusinessIds,
      'targetCategories': targetCategories,
      'locationFilter': locationFilter,
      'maxImpressions': maxImpressions,
      'currentImpressions': currentImpressions,
      'maxClicks': maxClicks,
      'currentClicks': currentClicks,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'metadata': metadata,
    };
  }

  // Verificar si el banner está activo
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           now.isBefore(endDate) &&
           (maxImpressions == null || currentImpressions < maxImpressions!) &&
           (maxClicks == null || currentClicks < maxClicks!);
  }

  // Verificar si es para el usuario actual
  bool isForUser(String userId, {Map<String, dynamic>? userData}) {
    // Verificar si está en la lista de usuarios específicos
    if (targetUserIds != null && targetUserIds!.isNotEmpty) {
      return targetUserIds!.contains(userId);
    }

    // Verificar según el tipo de target
    switch (target) {
      case BannerTarget.all:
        return true;
      case BannerTarget.new_users:
        // Aquí podríamos verificar si el usuario es nuevo
        return userData?['isFirstOrder'] == true;
      case BannerTarget.returning:
        return userData?['orderCount'] != null && userData!['orderCount'] > 0;
      case BannerTarget.premium:
        return userData?['isPremium'] == true;
      case BannerTarget.inactive:
        // Verificar si el usuario está inactivo (ej: sin pedidos en 30 días)
        if (userData?['lastOrderDate'] != null) {
          final lastOrder = (userData!['lastOrderDate'] as Timestamp).toDate();
          return DateTime.now().difference(lastOrder).inDays > 30;
        }
        return false;
      case BannerTarget.location:
        // Verificar ubicación del usuario
        return locationFilter != null;
      case BannerTarget.custom:
        return true; // Lógica personalizada
    }
  }

  // Obtener tamaño del banner según tipo
  double get height {
    switch (type) {
      case BannerType.hero:
        return 200;
      case BannerType.carousel:
        return 150;
      case BannerType.flash:
        return 120;
      case BannerType.category:
        return 100;
      case BannerType.business:
        return 140;
      case BannerType.referral:
        return 160;
      case BannerType.loyalty:
        return 140;
      case BannerType.seasonal:
        return 180;
      case BannerType.countdown:
        return 130;
      case BannerType.interactive:
        return 200;
    }
  }

  // Obtener texto formateado para botón
  String get formattedButtonText {
    if (buttonText.isNotEmpty) return buttonText;
    
    switch (action) {
      case BannerAction.navigate:
        return 'Ver más';
      case BannerAction.coupon:
        return 'Obtener cupón';
      case BannerAction.business:
        return 'Ver negocio';
      case BannerAction.category:
        return 'Ver categoría';
      case BannerAction.search:
        return 'Buscar';
      case BannerAction.share:
        return 'Compartir';
      case BannerAction.external:
        return 'Visitar';
      case BannerAction.call:
        return 'Llamar';
      case BannerAction.order:
        return 'Pedir ahora';
      default:
        return '';
    }
  }

  // Parsear color desde string o int
  static Color _parseColor(dynamic colorValue) {
    if (colorValue == null) return Colors.red;
    
    if (colorValue is int) {
      return Color(colorValue);
    }
    
    if (colorValue is String) {
      // Intentar parsear como hex
      if (colorValue.startsWith('#')) {
        return Color(int.parse(colorValue.substring(1), radix: 16) + 0xFF000000);
      }
      
      // Colores predefinidos
      switch (colorValue.toLowerCase()) {
        case 'red':
          return Colors.red;
        case 'blue':
          return Colors.blue;
        case 'green':
          return Colors.green;
        case 'orange':
          return Colors.orange;
        case 'purple':
          return Colors.purple;
        case 'pink':
          return Colors.pink;
        case 'yellow':
          return Colors.yellow;
        case 'black':
          return Colors.black;
        case 'white':
          return Colors.white;
        case 'grey':
        case 'gray':
          return Colors.grey;
        default:
          return Colors.red;
      }
    }
    
    return Colors.red;
  }

  // Copia con valores actualizados
  PromotionBanner copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    BannerType? type,
    BannerAction? action,
    BannerTarget? target,
    String? actionData,
    String? externalUrl,
    Color? backgroundColor,
    Color? textColor,
    Color? buttonColor,
    String? buttonText,
    bool? isActive,
    int? priority,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? targetUserIds,
    List<String>? targetBusinessIds,
    List<String>? targetCategories,
    Map<String, dynamic>? locationFilter,
    int? maxImpressions,
    int? currentImpressions,
    int? maxClicks,
    int? currentClicks,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PromotionBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      action: action ?? this.action,
      target: target ?? this.target,
      actionData: actionData ?? this.actionData,
      externalUrl: externalUrl ?? this.externalUrl,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      buttonColor: buttonColor ?? this.buttonColor,
      buttonText: buttonText ?? this.buttonText,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetUserIds: targetUserIds ?? this.targetUserIds,
      targetBusinessIds: targetBusinessIds ?? this.targetBusinessIds,
      targetCategories: targetCategories ?? this.targetCategories,
      locationFilter: locationFilter ?? this.locationFilter,
      maxImpressions: maxImpressions ?? this.maxImpressions,
      currentImpressions: currentImpressions ?? this.currentImpressions,
      maxClicks: maxClicks ?? this.maxClicks,
      currentClicks: currentClicks ?? this.currentClicks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'PromotionBanner(id: $id, title: $title, type: $type, action: $action)';
  }
}

// Extensiones para enums
extension BannerTypeExtension on BannerType {
  String get value {
    switch (this) {
      case BannerType.hero:
        return 'hero';
      case BannerType.carousel:
        return 'carousel';
      case BannerType.flash:
        return 'flash';
      case BannerType.category:
        return 'category';
      case BannerType.business:
        return 'business';
      case BannerType.referral:
        return 'referral';
      case BannerType.loyalty:
        return 'loyalty';
      case BannerType.seasonal:
        return 'seasonal';
      case BannerType.countdown:
        return 'countdown';
      case BannerType.interactive:
        return 'interactive';
    }
  }

  static BannerType fromString(String value) {
    switch (value) {
      case 'hero':
        return BannerType.hero;
      case 'carousel':
        return BannerType.carousel;
      case 'flash':
        return BannerType.flash;
      case 'category':
        return BannerType.category;
      case 'business':
        return BannerType.business;
      case 'referral':
        return BannerType.referral;
      case 'loyalty':
        return BannerType.loyalty;
      case 'seasonal':
        return BannerType.seasonal;
      case 'countdown':
        return BannerType.countdown;
      case 'interactive':
        return BannerType.interactive;
      default:
        return BannerType.hero;
    }
  }
}

extension BannerActionExtension on BannerAction {
  String get value {
    switch (this) {
      case BannerAction.none:
        return 'none';
      case BannerAction.navigate:
        return 'navigate';
      case BannerAction.coupon:
        return 'coupon';
      case BannerAction.business:
        return 'business';
      case BannerAction.category:
        return 'category';
      case BannerAction.search:
        return 'search';
      case BannerAction.share:
        return 'share';
      case BannerAction.external:
        return 'external';
      case BannerAction.call:
        return 'call';
      case BannerAction.order:
        return 'order';
    }
  }

  static BannerAction fromString(String value) {
    switch (value) {
      case 'none':
        return BannerAction.none;
      case 'navigate':
        return BannerAction.navigate;
      case 'coupon':
        return BannerAction.coupon;
      case 'business':
        return BannerAction.business;
      case 'category':
        return BannerAction.category;
      case 'search':
        return BannerAction.search;
      case 'share':
        return BannerAction.share;
      case 'external':
        return BannerAction.external;
      case 'call':
        return BannerAction.call;
      case 'order':
        return BannerAction.order;
      default:
        return BannerAction.none;
    }
  }
}

extension BannerTargetExtension on BannerTarget {
  String get value {
    switch (this) {
      case BannerTarget.all:
        return 'all';
      case BannerTarget.new_users:
        return 'new_users';
      case BannerTarget.returning:
        return 'returning';
      case BannerTarget.premium:
        return 'premium';
      case BannerTarget.inactive:
        return 'inactive';
      case BannerTarget.location:
        return 'location';
      case BannerTarget.custom:
        return 'custom';
    }
  }

  static BannerTarget fromString(String value) {
    switch (value) {
      case 'all':
        return BannerTarget.all;
      case 'new_users':
        return BannerTarget.new_users;
      case 'returning':
        return BannerTarget.returning;
      case 'premium':
        return BannerTarget.premium;
      case 'inactive':
        return BannerTarget.inactive;
      case 'location':
        return BannerTarget.location;
      case 'custom':
        return BannerTarget.custom;
      default:
        return BannerTarget.all;
    }
  }
}
