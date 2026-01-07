// ============================================================================
// models/referral_model.dart - Sistema de Referidos
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

// Modelo para el sistema de referidos de un usuario
class UserReferral {
  final String userId;
  final String referralCode; // Código único del usuario (ej: "JUAN2024")
  final String? referredBy; // Código de quien lo refirió (null si no fue referido)
  final int totalReferrals; // Cantidad de personas que invitó
  final double totalEarnings; // Total ganado en recompensas
  final DateTime createdAt;
  final List<String> referredUsers; // IDs de usuarios que invitó

  UserReferral({
    required this.userId,
    required this.referralCode,
    this.referredBy,
    this.totalReferrals = 0,
    this.totalEarnings = 0,
    required this.createdAt,
    this.referredUsers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'referralCode': referralCode,
      'referredBy': referredBy,
      'totalReferrals': totalReferrals,
      'totalEarnings': totalEarnings,
      'createdAt': Timestamp.fromDate(createdAt),
      'referredUsers': referredUsers,
    };
  }

  factory UserReferral.fromMap(Map<String, dynamic> map) {
    return UserReferral(
      userId: map['userId'] ?? '',
      referralCode: map['referralCode'] ?? '',
      referredBy: map['referredBy'],
      totalReferrals: map['totalReferrals'] ?? 0,
      totalEarnings: (map['totalEarnings'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      referredUsers: map['referredUsers'] != null
          ? List<String>.from(map['referredUsers'])
          : [],
    );
  }

  // Crear copia con campos actualizados
  UserReferral copyWith({
    String? userId,
    String? referralCode,
    String? referredBy,
    int? totalReferrals,
    double? totalEarnings,
    DateTime? createdAt,
    List<String>? referredUsers,
  }) {
    return UserReferral(
      userId: userId ?? this.userId,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      totalReferrals: totalReferrals ?? this.totalReferrals,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      createdAt: createdAt ?? this.createdAt,
      referredUsers: referredUsers ?? this.referredUsers,
    );
  }
}

// Modelo para cada referido individual
class Referral {
  final String id;
  final String referrerId; // ID del que invitó
  final String referrerCode; // Código usado
  final String referredUserId; // ID del que fue invitado
  final String referredUserName; // Nombre del invitado
  final String referredUserEmail; // Email del invitado
  final DateTime createdAt;
  final bool rewardClaimed; // Si ya se dio la recompensa
  final String? couponCode; // Código del cupón otorgado
  final double rewardAmount; // Monto de la recompensa

  Referral({
    required this.id,
    required this.referrerId,
    required this.referrerCode,
    required this.referredUserId,
    required this.referredUserName,
    required this.referredUserEmail,
    required this.createdAt,
    this.rewardClaimed = false,
    this.couponCode,
    this.rewardAmount = 100,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'referrerId': referrerId,
      'referrerCode': referrerCode,
      'referredUserId': referredUserId,
      'referredUserName': referredUserName,
      'referredUserEmail': referredUserEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'rewardClaimed': rewardClaimed,
      'couponCode': couponCode,
      'rewardAmount': rewardAmount,
    };
  }

  factory Referral.fromMap(Map<String, dynamic> map) {
    return Referral(
      id: map['id'] ?? '',
      referrerId: map['referrerId'] ?? '',
      referrerCode: map['referrerCode'] ?? '',
      referredUserId: map['referredUserId'] ?? '',
      referredUserName: map['referredUserName'] ?? '',
      referredUserEmail: map['referredUserEmail'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      rewardClaimed: map['rewardClaimed'] ?? false,
      couponCode: map['couponCode'],
      rewardAmount: (map['rewardAmount'] ?? 100).toDouble(),
    );
  }
}