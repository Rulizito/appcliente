// ============================================================================
// models/loyalty_model.dart - Modelo de Sistema de Lealtad
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum LoyaltyTier {
  bronze,    // 0-499 puntos
  silver,    // 500-1499 puntos
  gold,      // 1500-4999 puntos
  platinum,  // 5000-14999 puntos
  diamond,   // 15000+ puntos
}

enum RewardType {
  discount,      // Descuento en dinero
  percentage,    // Descuento porcentual
  free_delivery, // Envío gratis
  free_item,     // Item gratis
  points_bonus,  // Bonus de puntos
  upgrade,       // Upgrade de nivel
  exclusive,     // Acceso exclusivo
}

enum RewardStatus {
  available,     // Disponible para canjear
  redeemed,      // Canjeado
  expired,       // Expirado
  locked,        // Bloqueado (nivel insuficiente)
}

class LoyaltyProgram {
  final String id;
  final String name;
  final String description;
  final bool isActive;
  final DateTime startDate;
  final DateTime? endDate;
  final Map<String, int> pointsPerPurchase; // Puntos por monto de compra
  final Map<String, int> pointsPerAction;   // Puntos por acciones (review, referral, etc.)
  final int pointsMultiplier;               // Multiplicador de puntos
  final List<LoyaltyTier> availableTiers;
  final Map<String, dynamic> tierBenefits;  // Beneficios por nivel
  final DateTime createdAt;
  final DateTime? updatedAt;

  LoyaltyProgram({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    required this.startDate,
    this.endDate,
    required this.pointsPerPurchase,
    required this.pointsPerAction,
    this.pointsMultiplier = 1,
    required this.availableTiers,
    required this.tierBenefits,
    required this.createdAt,
    this.updatedAt,
  });

  // Crear desde Firestore
  factory LoyaltyProgram.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LoyaltyProgram.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory LoyaltyProgram.fromMap(Map<String, dynamic> map, String id) {
    return LoyaltyProgram(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      isActive: map['isActive'] ?? true,
      startDate: map['startDate'] != null 
          ? (map['startDate'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: map['endDate'] != null 
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      pointsPerPurchase: Map<String, int>.from(map['pointsPerPurchase'] ?? {}),
      pointsPerAction: Map<String, int>.from(map['pointsPerAction'] ?? {}),
      pointsMultiplier: map['pointsMultiplier'] ?? 1,
      availableTiers: (map['availableTiers'] as List<dynamic>?)
          ?.map((tier) => LoyaltyTierExtension.fromString(tier))
          .toList() ?? [LoyaltyTier.bronze, LoyaltyTier.silver, LoyaltyTier.gold],
      tierBenefits: Map<String, dynamic>.from(map['tierBenefits'] ?? {}),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'isActive': isActive,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'pointsPerPurchase': pointsPerPurchase,
      'pointsPerAction': pointsPerAction,
      'pointsMultiplier': pointsMultiplier,
      'availableTiers': availableTiers.map((tier) => tier.value).toList(),
      'tierBenefits': tierBenefits,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Verificar si el programa está activo
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return isActive && 
           now.isAfter(startDate) && 
           (endDate == null || now.isBefore(endDate!));
  }
}

class UserLoyalty {
  final String id;
  final String userId;
  final String programId;
  final int currentPoints;
  final int totalPointsEarned;
  final int totalPointsSpent;
  final LoyaltyTier currentTier;
  final DateTime tierUpgradeDate;
  final int streakDays;            // Días consecutivos de actividad
  final DateTime lastActivityDate;
  final Map<String, DateTime> lastActionDates; // Última vez que realizó cada acción
  final List<String> redeemedRewards; // IDs de recompensas canjeadas
  final List<LoyaltyTransaction> transactions;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserLoyalty({
    required this.id,
    required this.userId,
    required this.programId,
    required this.currentPoints,
    required this.totalPointsEarned,
    required this.totalPointsSpent,
    required this.currentTier,
    required this.tierUpgradeDate,
    this.streakDays = 0,
    required this.lastActivityDate,
    required this.lastActionDates,
    this.redeemedRewards = const [],
    this.transactions = const [],
    required this.createdAt,
    this.updatedAt,
  });

  // Crear desde Firestore
  factory UserLoyalty.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserLoyalty.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory UserLoyalty.fromMap(Map<String, dynamic> map, String id) {
    return UserLoyalty(
      id: id,
      userId: map['userId'] ?? '',
      programId: map['programId'] ?? '',
      currentPoints: map['currentPoints'] ?? 0,
      totalPointsEarned: map['totalPointsEarned'] ?? 0,
      totalPointsSpent: map['totalPointsSpent'] ?? 0,
      currentTier: LoyaltyTierExtension.fromString(map['currentTier'] ?? 'bronze'),
      tierUpgradeDate: map['tierUpgradeDate'] != null 
          ? (map['tierUpgradeDate'] as Timestamp).toDate()
          : DateTime.now(),
      streakDays: map['streakDays'] ?? 0,
      lastActivityDate: map['lastActivityDate'] != null 
          ? (map['lastActivityDate'] as Timestamp).toDate()
          : DateTime.now(),
      lastActionDates: Map<String, dynamic>.from(map['lastActionDates'] ?? {})
          .map((key, value) => MapEntry(key, (value as Timestamp).toDate())),
      redeemedRewards: List<String>.from(map['redeemedRewards'] ?? []),
      transactions: (map['transactions'] as List<dynamic>?)
          ?.map((tx) => LoyaltyTransaction.fromMap(tx))
          .toList() ?? [],
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'programId': programId,
      'currentPoints': currentPoints,
      'totalPointsEarned': totalPointsEarned,
      'totalPointsSpent': totalPointsSpent,
      'currentTier': currentTier.value,
      'tierUpgradeDate': Timestamp.fromDate(tierUpgradeDate),
      'streakDays': streakDays,
      'lastActivityDate': Timestamp.fromDate(lastActivityDate),
      'lastActionDates': lastActionDates.map((key, value) => MapEntry(key, Timestamp.fromDate(value))),
      'redeemedRewards': redeemedRewards,
      'transactions': transactions.map((tx) => tx.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Método copyWith
  UserLoyalty copyWith({
    String? id,
    String? userId,
    String? programId,
    int? currentPoints,
    int? totalPointsEarned,
    int? totalPointsSpent,
    LoyaltyTier? currentTier,
    DateTime? tierUpgradeDate,
    int? streakDays,
    DateTime? lastActivityDate,
    Map<String, DateTime>? lastActionDates,
    List<String>? redeemedRewards,
    List<LoyaltyTransaction>? transactions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserLoyalty(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      programId: programId ?? this.programId,
      currentPoints: currentPoints ?? this.currentPoints,
      totalPointsEarned: totalPointsEarned ?? this.totalPointsEarned,
      totalPointsSpent: totalPointsSpent ?? this.totalPointsSpent,
      currentTier: currentTier ?? this.currentTier,
      tierUpgradeDate: tierUpgradeDate ?? this.tierUpgradeDate,
      streakDays: streakDays ?? this.streakDays,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      lastActionDates: lastActionDates ?? this.lastActionDates,
      redeemedRewards: redeemedRewards ?? this.redeemedRewards,
      transactions: transactions ?? this.transactions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Obtener puntos necesarios para siguiente nivel
  int get pointsToNextTier {
    switch (currentTier) {
      case LoyaltyTier.bronze:
        return 500 - currentPoints;
      case LoyaltyTier.silver:
        return 1500 - currentPoints;
      case LoyaltyTier.gold:
        return 5000 - currentPoints;
      case LoyaltyTier.platinum:
        return 15000 - currentPoints;
      case LoyaltyTier.diamond:
        return 0; // Nivel máximo
    }
  }

  // Obtener progreso al siguiente nivel (0.0 - 1.0)
  double get progressToNextTier {
    switch (currentTier) {
      case LoyaltyTier.bronze:
        return currentPoints / 500;
      case LoyaltyTier.silver:
        return (currentPoints - 500) / 1000;
      case LoyaltyTier.gold:
        return (currentPoints - 1500) / 3500;
      case LoyaltyTier.platinum:
        return (currentPoints - 5000) / 10000;
      case LoyaltyTier.diamond:
        return 1.0; // Nivel máximo
    }
  }

  // Verificar si puede subir de nivel
  bool get canUpgradeTier {
    switch (currentTier) {
      case LoyaltyTier.bronze:
        return currentPoints >= 500;
      case LoyaltyTier.silver:
        return currentPoints >= 1500;
      case LoyaltyTier.gold:
        return currentPoints >= 5000;
      case LoyaltyTier.platinum:
        return currentPoints >= 15000;
      case LoyaltyTier.diamond:
        return false; // Nivel máximo
    }
  }
}

class LoyaltyReward {
  final String id;
  final String programId;
  final String name;
  final String description;
  final RewardType type;
  final int pointsCost;
  final LoyaltyTier requiredTier;
  final Map<String, dynamic> rewardData; // Datos específicos del reward
  final int? maxUses;                    // Límite de usos totales
  final int currentUses;                 // Usos actuales
  final int? maxUsesPerUser;             // Límite por usuario
  final DateTime? availableUntil;        // Disponible hasta
  final List<String> applicableBusinesses; // Negocios donde aplica
  final List<String> applicableCategories; // Categorías donde aplica
  final String? imageUrl;                // Imagen del reward
  final bool isActive;
  final int priority;                    // Prioridad de visualización
  final DateTime createdAt;
  final DateTime? updatedAt;

  LoyaltyReward({
    required this.id,
    required this.programId,
    required this.name,
    required this.description,
    required this.type,
    required this.pointsCost,
    required this.requiredTier,
    required this.rewardData,
    this.maxUses,
    this.currentUses = 0,
    this.maxUsesPerUser,
    this.availableUntil,
    this.applicableBusinesses = const [],
    this.applicableCategories = const [],
    this.imageUrl,
    this.isActive = true,
    this.priority = 0,
    required this.createdAt,
    this.updatedAt,
  });

  // Crear desde Firestore
  factory LoyaltyReward.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LoyaltyReward.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory LoyaltyReward.fromMap(Map<String, dynamic> map, String id) {
    return LoyaltyReward(
      id: id,
      programId: map['programId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: RewardTypeExtension.fromString(map['type'] ?? 'discount'),
      pointsCost: map['pointsCost'] ?? 0,
      requiredTier: LoyaltyTierExtension.fromString(map['requiredTier'] ?? 'bronze'),
      rewardData: Map<String, dynamic>.from(map['rewardData'] ?? {}),
      maxUses: map['maxUses'],
      currentUses: map['currentUses'] ?? 0,
      maxUsesPerUser: map['maxUsesPerUser'],
      availableUntil: map['availableUntil'] != null 
          ? (map['availableUntil'] as Timestamp).toDate()
          : null,
      applicableBusinesses: List<String>.from(map['applicableBusinesses'] ?? []),
      applicableCategories: List<String>.from(map['applicableCategories'] ?? []),
      imageUrl: map['imageUrl'],
      isActive: map['isActive'] ?? true,
      priority: map['priority'] ?? 0,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'programId': programId,
      'name': name,
      'description': description,
      'type': type.value,
      'pointsCost': pointsCost,
      'requiredTier': requiredTier.value,
      'rewardData': rewardData,
      'maxUses': maxUses,
      'currentUses': currentUses,
      'maxUsesPerUser': maxUsesPerUser,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'applicableBusinesses': applicableBusinesses,
      'applicableCategories': applicableCategories,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'priority': priority,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Verificar si está disponible
  bool get isAvailable {
    final now = DateTime.now();
    return isActive &&
           (availableUntil == null || now.isBefore(availableUntil!)) &&
           (maxUses == null || currentUses < maxUses!);
  }

  // Verificar si el usuario puede canjearlo
  bool canUserRedeem(UserLoyalty userLoyalty) {
    if (!isAvailable) return false;
    if (userLoyalty.currentPoints < pointsCost) return false;
    if (userLoyalty.currentTier.index < requiredTier.index) return false;
    
    // Verificar límite por usuario
    if (maxUsesPerUser != null) {
      final userUses = userLoyalty.transactions
          .where((tx) => tx.rewardId == id && tx.type == LoyaltyTransactionType.redemption)
          .length;
      if (userUses >= maxUsesPerUser!) return false;
    }
    
    return true;
  }

  // Obtener texto formateado del reward
  String get formattedRewardText {
    switch (type) {
      case RewardType.discount:
        return '\$${rewardData['amount'] ?? 0} de descuento';
      case RewardType.percentage:
        return '${rewardData['percentage'] ?? 0}% de descuento';
      case RewardType.free_delivery:
        return 'Envío gratis';
      case RewardType.free_item:
        return '${rewardData['itemName'] ?? 'Item'} gratis';
      case RewardType.points_bonus:
        return '+${rewardData['bonusPoints'] ?? 0} puntos';
      case RewardType.upgrade:
        return 'Upgrade a ${rewardData['targetTier'] ?? 'siguiente nivel'}';
      case RewardType.exclusive:
        return 'Acceso exclusivo: ${rewardData['accessType'] ?? 'VIP'}';
    }
  }
}

class LoyaltyTransaction {
  final String id;
  final String userId;
  final String programId;
  final LoyaltyTransactionType type;
  final int points;                    // Puntos ganados o gastados (positivo o negativo)
  final String? orderId;               // ID del pedido si aplica
  final String? rewardId;              // ID del reward si aplica
  final String? businessId;            // ID del negocio si aplica
  final String description;            // Descripción de la transacción
  final Map<String, dynamic> metadata; // Datos adicionales
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.userId,
    required this.programId,
    required this.type,
    required this.points,
    this.orderId,
    this.rewardId,
    this.businessId,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  // Crear desde Map
  factory LoyaltyTransaction.fromMap(Map<String, dynamic> map) {
    return LoyaltyTransaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      programId: map['programId'] ?? '',
      type: LoyaltyTransactionTypeExtension.fromString(map['type'] ?? 'earned'),
      points: map['points'] ?? 0,
      orderId: map['orderId'],
      rewardId: map['rewardId'],
      businessId: map['businessId'],
      description: map['description'] ?? '',
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'programId': programId,
      'type': type.value,
      'points': points,
      'orderId': orderId,
      'rewardId': rewardId,
      'businessId': businessId,
      'description': description,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Verificar si es una transacción de puntos ganados
  bool get isEarned => type == LoyaltyTransactionType.earned || type == LoyaltyTransactionType.bonus;

  // Verificar si es una transacción de puntos gastados
  bool get isSpent => type == LoyaltyTransactionType.redemption || type == LoyaltyTransactionType.expired;
}

enum LoyaltyTransactionType {
  earned,      // Puntos ganados por compra
  bonus,       // Puntos bonus
  redemption,  // Canje de reward
  expired,     // Puntos expirados
  adjustment,  // Ajuste manual
  referral,    // Puntos por referido
  review,      // Puntos por reseña
  milestone,   // Puntos por hito
}

// Extensiones para enums
extension LoyaltyTierExtension on LoyaltyTier {
  String get value {
    switch (this) {
      case LoyaltyTier.bronze:
        return 'bronze';
      case LoyaltyTier.silver:
        return 'silver';
      case LoyaltyTier.gold:
        return 'gold';
      case LoyaltyTier.platinum:
        return 'platinum';
      case LoyaltyTier.diamond:
        return 'diamond';
    }
  }

  static LoyaltyTier fromString(String value) {
    switch (value) {
      case 'bronze':
        return LoyaltyTier.bronze;
      case 'silver':
        return LoyaltyTier.silver;
      case 'gold':
        return LoyaltyTier.gold;
      case 'platinum':
        return LoyaltyTier.platinum;
      case 'diamond':
        return LoyaltyTier.diamond;
      default:
        return LoyaltyTier.bronze;
    }
  }

  String get displayName {
    switch (this) {
      case LoyaltyTier.bronze:
        return 'Bronce';
      case LoyaltyTier.silver:
        return 'Plata';
      case LoyaltyTier.gold:
        return 'Oro';
      case LoyaltyTier.platinum:
        return 'Platino';
      case LoyaltyTier.diamond:
        return 'Diamante';
    }
  }

  Color get color {
    switch (this) {
      case LoyaltyTier.bronze:
        return Colors.brown;
      case LoyaltyTier.silver:
        return Colors.grey;
      case LoyaltyTier.gold:
        return Colors.amber;
      case LoyaltyTier.platinum:
        return Colors.blueGrey;
      case LoyaltyTier.diamond:
        return Colors.purple;
    }
  }

  IconData get icon {
    switch (this) {
      case LoyaltyTier.bronze:
        return Icons.military_tech;
      case LoyaltyTier.silver:
        return Icons.workspace_premium;
      case LoyaltyTier.gold:
        return Icons.emoji_events;
      case LoyaltyTier.platinum:
        return Icons.diamond;
      case LoyaltyTier.diamond:
        return Icons.stars;
    }
  }
}

extension RewardTypeExtension on RewardType {
  String get value {
    switch (this) {
      case RewardType.discount:
        return 'discount';
      case RewardType.percentage:
        return 'percentage';
      case RewardType.free_delivery:
        return 'free_delivery';
      case RewardType.free_item:
        return 'free_item';
      case RewardType.points_bonus:
        return 'points_bonus';
      case RewardType.upgrade:
        return 'upgrade';
      case RewardType.exclusive:
        return 'exclusive';
    }
  }

  static RewardType fromString(String value) {
    switch (value) {
      case 'discount':
        return RewardType.discount;
      case 'percentage':
        return RewardType.percentage;
      case 'free_delivery':
        return RewardType.free_delivery;
      case 'free_item':
        return RewardType.free_item;
      case 'points_bonus':
        return RewardType.points_bonus;
      case 'upgrade':
        return RewardType.upgrade;
      case 'exclusive':
        return RewardType.exclusive;
      default:
        return RewardType.discount;
    }
  }
}

extension RewardStatusExtension on RewardStatus {
  String get value {
    switch (this) {
      case RewardStatus.available:
        return 'available';
      case RewardStatus.redeemed:
        return 'redeemed';
      case RewardStatus.expired:
        return 'expired';
      case RewardStatus.locked:
        return 'locked';
    }
  }

  static RewardStatus fromString(String value) {
    switch (value) {
      case 'available':
        return RewardStatus.available;
      case 'redeemed':
        return RewardStatus.redeemed;
      case 'expired':
        return RewardStatus.expired;
      case 'locked':
        return RewardStatus.locked;
      default:
        return RewardStatus.available;
    }
  }
}

extension LoyaltyTransactionTypeExtension on LoyaltyTransactionType {
  String get value {
    switch (this) {
      case LoyaltyTransactionType.earned:
        return 'earned';
      case LoyaltyTransactionType.bonus:
        return 'bonus';
      case LoyaltyTransactionType.redemption:
        return 'redemption';
      case LoyaltyTransactionType.expired:
        return 'expired';
      case LoyaltyTransactionType.adjustment:
        return 'adjustment';
      case LoyaltyTransactionType.referral:
        return 'referral';
      case LoyaltyTransactionType.review:
        return 'review';
      case LoyaltyTransactionType.milestone:
        return 'milestone';
    }
  }

  static LoyaltyTransactionType fromString(String value) {
    switch (value) {
      case 'earned':
        return LoyaltyTransactionType.earned;
      case 'bonus':
        return LoyaltyTransactionType.bonus;
      case 'redemption':
        return LoyaltyTransactionType.redemption;
      case 'expired':
        return LoyaltyTransactionType.expired;
      case 'adjustment':
        return LoyaltyTransactionType.adjustment;
      case 'referral':
        return LoyaltyTransactionType.referral;
      case 'review':
        return LoyaltyTransactionType.review;
      case 'milestone':
        return LoyaltyTransactionType.milestone;
      default:
        return LoyaltyTransactionType.earned;
    }
  }
}
