// ============================================================================
// models/coupon_model.dart - VERSIÓN MEJORADA
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class Coupon {
  final String id;
  final String code; // Código del cupón (ej: "VERANO2024")
  final String description; // Descripción del cupón
  final CouponType type; // percentage o fixed
  final double value; // 20 para 20% o 100 para $100
  final double? minAmount; // Monto mínimo de compra requerido
  final DateTime? expiryDate; // Fecha de expiración
  final bool isActive; // Si está activo o no
  final int? maxUses; // Cantidad máxima de usos (null = ilimitado)
  final int currentUses; // Cantidad de veces usado
  final List<String>? applicableCategories; // Categorías donde aplica (null = todas)
  final bool isFirstOrderOnly; // Solo para primer pedido
  final DateTime createdAt;
  final String? imageUrl; // Imagen del cupón (opcional)
  final String? promoText; // Texto promocional corto (ej: "¡Oferta especial!")
  final CouponSource source; // De dónde viene el cupón
  final bool isFeatured; // Destacado en la lista

  Coupon({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    this.minAmount,
    this.expiryDate,
    this.isActive = true,
    this.maxUses,
    this.currentUses = 0,
    this.applicableCategories,
    this.isFirstOrderOnly = false,
    required this.createdAt,
    this.imageUrl,
    this.promoText,
    this.source = CouponSource.general,
    this.isFeatured = false,
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'description': description,
      'type': type.toString().split('.').last,
      'value': value,
      'minAmount': minAmount,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'maxUses': maxUses,
      'currentUses': currentUses,
      'applicableCategories': applicableCategories,
      'isFirstOrderOnly': isFirstOrderOnly,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'promoText': promoText,
      'source': source.toString().split('.').last,
      'isFeatured': isFeatured,
    };
  }

  // Crear desde Map de Firestore
  factory Coupon.fromMap(Map<String, dynamic> map) {
    return Coupon(
      id: map['id'] ?? '',
      code: map['code'] ?? '',
      description: map['description'] ?? '',
      type: CouponType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => CouponType.percentage,
      ),
      value: (map['value'] ?? 0).toDouble(),
      minAmount: map['minAmount']?.toDouble(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      maxUses: map['maxUses'],
      currentUses: map['currentUses'] ?? 0,
      applicableCategories: map['applicableCategories'] != null
          ? List<String>.from(map['applicableCategories'])
          : null,
      isFirstOrderOnly: map['isFirstOrderOnly'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
      promoText: map['promoText'],
      source: CouponSource.values.firstWhere(
        (e) => e.toString().split('.').last == (map['source'] ?? 'general'),
        orElse: () => CouponSource.general,
      ),
      isFeatured: map['isFeatured'] ?? false,
    );
  }

  // Calcular el descuento para un monto dado
  double calculateDiscount(double amount) {
    if (type == CouponType.percentage) {
      return (amount * value) / 100;
    } else {
      return value;
    }
  }

  // Verificar si el cupón es válido
  bool isValid() {
    // Verificar si está activo
    if (!isActive) return false;

    // Verificar fecha de expiración
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) {
      return false;
    }

    // Verificar máximo de usos
    if (maxUses != null && currentUses >= maxUses!) {
      return false;
    }

    return true;
  }

  // Obtener texto de descuento formateado
  String get discountText {
    if (type == CouponType.percentage) {
      return '${value.toInt()}% OFF';
    } else {
      return '\$${value.toInt()} OFF';
    }
  }

  // Verificar si aplica para una categoría
  bool appliesTo(String category) {
    if (applicableCategories == null || applicableCategories!.isEmpty) {
      return true; // Aplica a todas las categorías
    }
    return applicableCategories!.contains(category);
  }

  // Obtener días restantes
  int? get daysRemaining {
    if (expiryDate == null) return null;
    final difference = expiryDate!.difference(DateTime.now());
    return difference.inDays;
  }

  // Verificar si está por vencer (menos de 3 días)
  bool get isExpiringSoon {
    final days = daysRemaining;
    return days != null && days <= 3 && days > 0;
  }
}

// Enumeración para tipos de cupón
enum CouponType {
  percentage, // Porcentaje de descuento
  fixed, // Monto fijo de descuento
}

// Enumeración para origen del cupón
enum CouponSource {
  general, // Cupón general del sistema
  achievement, // Ganado por logro
  referral, // Ganado por referir amigo
  birthday, // Cupón de cumpleaños
  firstOrder, // Cupón de primer pedido
  loyalty, // Programa de lealtad
}

// Modelo para cupones guardados por el usuario
class UserCoupon {
  final String id;
  final String userId;
  final String couponId;
  final String couponCode;
  final bool isUsed;
  final DateTime? usedAt;
  final String? orderId; // ID del pedido donde se usó
  final DateTime savedAt;
  final CouponSource source; // De dónde viene

  UserCoupon({
    required this.id,
    required this.userId,
    required this.couponId,
    required this.couponCode,
    this.isUsed = false,
    this.usedAt,
    this.orderId,
    required this.savedAt,
    this.source = CouponSource.general,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'couponId': couponId,
      'couponCode': couponCode,
      'isUsed': isUsed,
      'usedAt': usedAt?.toIso8601String(),
      'orderId': orderId,
      'savedAt': savedAt.toIso8601String(),
      'source': source.toString().split('.').last,
    };
  }

  factory UserCoupon.fromMap(Map<String, dynamic> map) {
    return UserCoupon(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      couponId: map['couponId'] ?? '',
      couponCode: map['couponCode'] ?? '',
      isUsed: map['isUsed'] ?? false,
      usedAt: map['usedAt'] != null ? DateTime.parse(map['usedAt']) : null,
      orderId: map['orderId'],
      savedAt: DateTime.parse(map['savedAt'] ?? DateTime.now().toIso8601String()),
      source: CouponSource.values.firstWhere(
        (e) => e.toString().split('.').last == (map['source'] ?? 'general'),
        orElse: () => CouponSource.general,
      ),
    );
  }
}