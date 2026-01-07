// ============================================================================
// services/loyalty_service.dart - Servicio de Sistema de Lealtad
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/loyalty_model.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class LoyaltyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Obtener programa de lealtad activo
  Stream<LoyaltyProgram?> getActiveProgram() {
    return _firestore
        .collection('loyalty_programs')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;
          
          // Filtrar por fecha de fin si existe
          final now = Timestamp.now();
          final activeDocs = docs.where((doc) {
            final endDate = doc.data()['endDate'];
            return endDate == null || (endDate as Timestamp).compareTo(now) >= 0;
          }).toList();
          
          return activeDocs.isNotEmpty 
              ? LoyaltyProgram.fromFirestore(activeDocs.first)
              : null;
        });
  }

  // Obtener datos de lealtad del usuario
  Stream<UserLoyalty?> getUserLoyalty(String userId) {
    return _firestore
        .collection('user_loyalty')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final docs = snapshot.docs;
          if (docs.isEmpty) return null;
          return UserLoyalty.fromFirestore(docs.first);
        });
  }

  // Obtener recompensas disponibles para el usuario
  Stream<List<LoyaltyReward>> getAvailableRewards(String userId, LoyaltyTier userTier) {
    return _firestore
        .collection('loyalty_rewards')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .orderBy('pointsCost')
        .snapshots()
        .map((snapshot) {
          final rewards = snapshot.docs.map((doc) => LoyaltyReward.fromFirestore(doc)).toList();
          
          // Filtrar por nivel del usuario y disponibilidad
          final now = DateTime.now();
          return rewards.where((reward) {
            // Verificar nivel requerido
            if (reward.requiredTier.index > userTier.index) return false;
            
            // Verificar disponibilidad
            if (!reward.isAvailable) return false;
            
            // Verificar fecha de disponibilidad
            if (reward.availableUntil != null && now.isAfter(reward.availableUntil!)) return false;
            
            // Verificar límite de usos
            if (reward.maxUses != null && reward.currentUses >= reward.maxUses!) return false;
            
            return true;
          }).toList();
        });
  }

  // Obtener transacciones del usuario
  Stream<List<LoyaltyTransaction>> getUserTransactions(String userId, {int limit = 50}) {
    return _firestore
        .collection('loyalty_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => LoyaltyTransaction.fromMap(doc.data()))
              .toList();
        });
  }

  // Inicializar lealtad para un nuevo usuario
  Future<UserLoyalty> initializeUserLoyalty(String userId, String programId) async {
    try {
      // Verificar si ya existe
      final existingDoc = await _firestore
          .collection('user_loyalty')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .get();

      if (existingDoc.docs.isNotEmpty) {
        return UserLoyalty.fromFirestore(existingDoc.docs.first);
      }

      // Crear nuevo registro de lealtad
      final userLoyalty = UserLoyalty(
        id: _firestore.collection('user_loyalty').doc().id,
        userId: userId,
        programId: programId,
        currentPoints: 0,
        totalPointsEarned: 0,
        totalPointsSpent: 0,
        currentTier: LoyaltyTier.bronze,
        tierUpgradeDate: DateTime.now(),
        lastActivityDate: DateTime.now(),
        lastActionDates: {},
        createdAt: DateTime.now(),
      );

      await _firestore.collection('user_loyalty').doc(userLoyalty.id).set(userLoyalty.toMap());
      
      return userLoyalty;
    } catch (e) {
      print('Error initializing user loyalty: $e');
      throw e;
    }
  }

  // Añadir puntos por compra
  Future<bool> addPointsFromPurchase({
    required String userId,
    required String programId,
    required String orderId,
    required double purchaseAmount,
    required String businessId,
  }) async {
    try {
      // Obtener programa de lealtad
      final programDoc = await _firestore.collection('loyalty_programs').doc(programId).get();
      if (!programDoc.exists) return false;
      
      final program = LoyaltyProgram.fromFirestore(programDoc);

      // Calcular puntos a ganar
      int pointsEarned = 0;
      
      // Puntos por monto de compra
      for (final entry in program.pointsPerPurchase.entries) {
        final threshold = double.tryParse(entry.key) ?? 0;
        if (purchaseAmount >= threshold) {
          pointsEarned = entry.value;
        }
      }

      // Aplicar multiplicador
      pointsEarned = (pointsEarned * program.pointsMultiplier).round();

      if (pointsEarned <= 0) return false;

      // Actualizar lealtad del usuario
      await _firestore.runTransaction((transaction) async {
        final userLoyaltyQuery = await _firestore.collection('user_loyalty')
            .where('userId', isEqualTo: userId)
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();
        
        if (userLoyaltyQuery.docs.isEmpty) return;
        final userLoyaltyDoc = userLoyaltyQuery.docs.first;

        if (!userLoyaltyDoc.exists) return;

        final userLoyalty = UserLoyalty.fromFirestore(userLoyaltyDoc);
        
        // Actualizar puntos
        final newCurrentPoints = userLoyalty.currentPoints + pointsEarned;
        final newTotalEarned = userLoyalty.totalPointsEarned + pointsEarned;
        
        // Verificar upgrade de nivel
        final newTier = _calculateTier(newCurrentPoints);
        final tierUpgraded = newTier.index > userLoyalty.currentTier.index;
        
        // Actualizar streak
        final newStreakDays = _calculateStreak(userLoyalty.lastActivityDate);
        
        // Actualizar datos
        final updatedLoyalty = userLoyalty.copyWith(
          currentPoints: newCurrentPoints,
          totalPointsEarned: newTotalEarned,
          currentTier: newTier,
          tierUpgradeDate: tierUpgraded ? DateTime.now() : userLoyalty.tierUpgradeDate,
          streakDays: newStreakDays,
          lastActivityDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        transaction.update(userLoyaltyDoc.reference, updatedLoyalty.toMap());

        // Crear transacción
        final transactionId = _firestore.collection('loyalty_transactions').doc().id;
        final loyaltyTransaction = LoyaltyTransaction(
          id: transactionId,
          userId: userId,
          programId: programId,
          type: LoyaltyTransactionType.earned,
          points: pointsEarned,
          orderId: orderId,
          businessId: businessId,
          description: 'Puntos ganados por compra de \$${purchaseAmount.toStringAsFixed(2)}',
          metadata: {
            'purchaseAmount': purchaseAmount,
            'businessId': businessId,
          },
          createdAt: DateTime.now(),
        );

        transaction.set(
          _firestore.collection('loyalty_transactions').doc(transactionId),
          loyaltyTransaction.toMap(),
        );

        // Si hubo upgrade de nivel, enviar notificación
        if (tierUpgraded) {
          await _notificationService.sendLoyaltyNotification(
            userId: userId,
            type: 'tier_upgrade',
            loyaltyData: {
              'newTier': newTier.displayName,
              'points': newCurrentPoints,
            },
          );
        }
      });

      return true;
    } catch (e) {
      print('Error adding points from purchase: $e');
      return false;
    }
  }

  // Añadir puntos por acción (review, referral, etc.)
  Future<bool> addPointsFromAction({
    required String userId,
    required String programId,
    required LoyaltyTransactionType actionType,
    required String description,
    String? orderId,
    String? businessId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Obtener programa de lealtad
      final programDoc = await _firestore.collection('loyalty_programs').doc(programId).get();
      if (!programDoc.exists) return false;
      
      final program = LoyaltyProgram.fromFirestore(programDoc);

      // Obtener puntos para la acción
      final pointsEarned = program.pointsPerAction[actionType.value] ?? 0;
      if (pointsEarned <= 0) return false;

      // Aplicar multiplicador
      final finalPoints = (pointsEarned * program.pointsMultiplier).round();

      await _firestore.runTransaction((transaction) async {
        final userLoyaltyQuery = await _firestore.collection('user_loyalty')
            .where('userId', isEqualTo: userId)
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();
        
        if (userLoyaltyQuery.docs.isEmpty) return;
        final userLoyaltyDoc = userLoyaltyQuery.docs.first;

        if (!userLoyaltyDoc.exists) return;

        final userLoyalty = UserLoyalty.fromFirestore(userLoyaltyDoc);
        
        // Actualizar puntos
        final newCurrentPoints = userLoyalty.currentPoints + finalPoints;
        final newTotalEarned = userLoyalty.totalPointsEarned + finalPoints;
        
        // Verificar upgrade de nivel
        final newTier = _calculateTier(newCurrentPoints);
        final tierUpgraded = newTier.index > userLoyalty.currentTier.index;
        
        // Actualizar streak
        final newStreakDays = _calculateStreak(userLoyalty.lastActivityDate);
        
        // Actualizar última acción
        final updatedLastActionDates = Map<String, DateTime>.from(userLoyalty.lastActionDates);
        updatedLastActionDates[actionType.value] = DateTime.now();
        
        // Actualizar datos
        final updatedLoyalty = userLoyalty.copyWith(
          currentPoints: newCurrentPoints,
          totalPointsEarned: newTotalEarned,
          currentTier: newTier,
          tierUpgradeDate: tierUpgraded ? DateTime.now() : userLoyalty.tierUpgradeDate,
          streakDays: newStreakDays,
          lastActivityDate: DateTime.now(),
          lastActionDates: updatedLastActionDates,
          updatedAt: DateTime.now(),
        );

        transaction.update(userLoyaltyDoc.reference, updatedLoyalty.toMap());

        // Crear transacción
        final transactionId = _firestore.collection('loyalty_transactions').doc().id;
        final loyaltyTransaction = LoyaltyTransaction(
          id: transactionId,
          userId: userId,
          programId: programId,
          type: actionType,
          points: finalPoints,
          orderId: orderId,
          businessId: businessId,
          description: description,
          metadata: metadata ?? {},
          createdAt: DateTime.now(),
        );

        transaction.set(
          _firestore.collection('loyalty_transactions').doc(transactionId),
          loyaltyTransaction.toMap(),
        );

        // Enviar notificación
        if (tierUpgraded) {
          await _notificationService.sendLoyaltyNotification(
            userId: userId,
            type: 'tier_upgrade',
            loyaltyData: {
              'newTier': newTier.displayName,
              'points': newCurrentPoints,
            },
          );
        } else {
          await _notificationService.sendLoyaltyNotification(
            userId: userId,
            type: 'points_earned',
            loyaltyData: {
              'points': finalPoints,
              'description': description,
            },
          );
        }
      });

      return true;
    } catch (e) {
      print('Error adding points from action: $e');
      return false;
    }
  }

  // Canjear recompensa
  Future<Map<String, dynamic>> redeemReward({
    required String userId,
    required String rewardId,
    required String programId,
  }) async {
    try {
      final rewardDoc = await _firestore.collection('loyalty_rewards').doc(rewardId).get();
      if (!rewardDoc.exists) {
        return {'success': false, 'message': 'Recompensa no encontrada'};
      }

      final reward = LoyaltyReward.fromFirestore(rewardDoc);

      // Obtener lealtad del usuario
      final userLoyaltyDocs = await _firestore
          .collection('user_loyalty')
          .where('userId', isEqualTo: userId)
          .where('programId', isEqualTo: programId)
          .get();

      if (userLoyaltyDocs.docs.isEmpty) {
        return {'success': false, 'message': 'Usuario no encontrado en programa de lealtad'};
      }

      final userLoyalty = UserLoyalty.fromFirestore(userLoyaltyDocs.docs.first);

      // Verificar si puede canjear
      if (!reward.canUserRedeem(userLoyalty)) {
        return {'success': false, 'message': 'No puedes canjear esta recompensa'};
      }

      await _firestore.runTransaction((transaction) async {
        // Actualizar puntos del usuario
        final newCurrentPoints = userLoyalty.currentPoints - reward.pointsCost;
        final newTotalSpent = userLoyalty.totalPointsSpent + reward.pointsCost;
        
        final updatedLoyalty = userLoyalty.copyWith(
          currentPoints: newCurrentPoints,
          totalPointsSpent: newTotalSpent,
          lastActivityDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        transaction.update(userLoyaltyDocs.docs.first.reference, updatedLoyalty.toMap());

        // Actualizar usos de la recompensa
        final newCurrentUses = reward.currentUses + 1;
        transaction.update(rewardDoc.reference, {
          'currentUses': newCurrentUses,
          'updatedAt': Timestamp.now(),
        });

        // Crear transacción de redención
        final transactionId = _firestore.collection('loyalty_transactions').doc().id;
        final loyaltyTransaction = LoyaltyTransaction(
          id: transactionId,
          userId: userId,
          programId: programId,
          type: LoyaltyTransactionType.redemption,
          points: -reward.pointsCost,
          rewardId: rewardId,
          description: 'Canje de recompensa: ${reward.name}',
          metadata: {
            'rewardName': reward.name,
            'rewardType': reward.type.value,
          },
          createdAt: DateTime.now(),
        );

        transaction.set(
          _firestore.collection('loyalty_transactions').doc(transactionId),
          loyaltyTransaction.toMap(),
        );
      });

      // Enviar notificación
      await _notificationService.sendLoyaltyNotification(
        userId: userId,
        type: 'reward_redeemed',
        loyaltyData: {
          'rewardId': rewardId,
          'rewardName': reward.name,
          'pointsSpent': reward.pointsCost,
        },
      );

      return {
        'success': true,
        'message': 'Recompensa canjeada exitosamente',
        'reward': reward,
        'pointsSpent': reward.pointsCost,
      };
    } catch (e) {
      print('Error redeeming reward: $e');
      return {'success': false, 'message': 'Error al canjear recompensa'};
    }
  }

  // Obtener estadísticas del usuario
  Future<Map<String, dynamic>> getUserLoyaltyStats(String userId) async {
    try {
      final userLoyaltyDocs = await _firestore
          .collection('user_loyalty')
          .where('userId', isEqualTo: userId)
          .get();

      if (userLoyaltyDocs.docs.isEmpty) return {};

      final userLoyalty = UserLoyalty.fromFirestore(userLoyaltyDocs.docs.first);

      // Obtener transacciones del último mes
      final now = DateTime.now();
      final monthAgo = now.subtract(const Duration(days: 30));
      
      final transactionsSnapshot = await _firestore
          .collection('loyalty_transactions')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthAgo))
          .get();

      final transactions = transactionsSnapshot.docs
          .map((doc) => LoyaltyTransaction.fromMap(doc.data()))
          .toList();

      final pointsEarnedThisMonth = transactions
          .where((tx) => tx.isEarned)
          .fold(0, (sum, tx) => sum + tx.points);

      final pointsSpentThisMonth = transactions
          .where((tx) => tx.isSpent)
          .fold(0, (sum, tx) => sum + tx.points.abs());

      // Obtener recompensas canjeadas
      final redeemedRewardsCount = userLoyalty.transactions
          .where((tx) => tx.type == LoyaltyTransactionType.redemption)
          .length;

      return {
        'currentPoints': userLoyalty.currentPoints,
        'currentTier': userLoyalty.currentTier.value,
        'totalPointsEarned': userLoyalty.totalPointsEarned,
        'totalPointsSpent': userLoyalty.totalPointsSpent,
        'streakDays': userLoyalty.streakDays,
        'pointsEarnedThisMonth': pointsEarnedThisMonth,
        'pointsSpentThisMonth': pointsSpentThisMonth,
        'redeemedRewardsCount': redeemedRewardsCount,
        'tierProgress': userLoyalty.progressToNextTier,
        'pointsToNextTier': userLoyalty.pointsToNextTier,
      };
    } catch (e) {
      print('Error getting user loyalty stats: $e');
      return {};
    }
  }

  // Calcular nivel según puntos
  LoyaltyTier _calculateTier(int points) {
    if (points >= 15000) return LoyaltyTier.diamond;
    if (points >= 5000) return LoyaltyTier.platinum;
    if (points >= 1500) return LoyaltyTier.gold;
    if (points >= 500) return LoyaltyTier.silver;
    return LoyaltyTier.bronze;
  }

  // Calcular streak de días
  int _calculateStreak(DateTime lastActivityDate) {
    final now = DateTime.now();
    final difference = now.difference(lastActivityDate).inDays;
    
    if (difference <= 1) {
      // Si la última actividad fue hoy o ayer, mantener o incrementar streak
      return difference == 0 ? 1 : 2; // Simplificado, debería guardar el streak actual
    } else {
      // Si han pasado más de 1 día, resetear streak
      return 1;
    }
  }

  // Obtener leaderboard de usuarios
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('user_loyalty')
          .orderBy('currentPoints', descending: true)
          .limit(limit)
          .get();

      final leaderboard = <Map<String, dynamic>>[];
      
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        final userLoyalty = UserLoyalty.fromFirestore(doc);
        
        // Obtener datos del usuario
        final userData = await _authService.getUserData(userLoyalty.userId);
        
        leaderboard.add({
          'rank': i + 1,
          'userId': userLoyalty.userId,
          'userName': userData?['name'] ?? 'Usuario',
          'userEmail': userData?['email'] ?? '',
          'points': userLoyalty.currentPoints,
          'tier': userLoyalty.currentTier.value,
        });
      }
      
      return leaderboard;
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  // Crear programa de lealtad (para admin)
  Future<String> createLoyaltyProgram(LoyaltyProgram program) async {
    try {
      final docRef = await _firestore.collection('loyalty_programs').add(program.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating loyalty program: $e');
      throw e;
    }
  }

  // Crear recompensa (para admin)
  Future<String> createReward(LoyaltyReward reward) async {
    try {
      final docRef = await _firestore.collection('loyalty_rewards').add(reward.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating reward: $e');
      throw e;
    }
  }

  // Ajuste manual de puntos (para admin)
  Future<bool> adjustPoints({
    required String userId,
    required String programId,
    required int points,
    required String reason,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final userLoyaltyQuery = await _firestore.collection('user_loyalty')
            .where('userId', isEqualTo: userId)
            .where('programId', isEqualTo: programId)
            .limit(1)
            .get();
        
        if (userLoyaltyQuery.docs.isEmpty) return;
        final userLoyaltyDoc = userLoyaltyQuery.docs.first;

        if (!userLoyaltyDoc.exists) return;

        final userLoyalty = UserLoyalty.fromFirestore(userLoyaltyDoc);
        
        final newCurrentPoints = userLoyalty.currentPoints + points;
        final newTotalEarned = points > 0 
            ? userLoyalty.totalPointsEarned + points 
            : userLoyalty.totalPointsEarned;
        final newTotalSpent = points < 0 
            ? userLoyalty.totalPointsSpent + points.abs() 
            : userLoyalty.totalPointsSpent;
        
        final updatedLoyalty = userLoyalty.copyWith(
          currentPoints: newCurrentPoints,
          totalPointsEarned: newTotalEarned,
          totalPointsSpent: newTotalSpent,
          lastActivityDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        transaction.update(userLoyaltyDoc.reference, updatedLoyalty.toMap());

        // Crear transacción de ajuste
        final transactionId = _firestore.collection('loyalty_transactions').doc().id;
        final loyaltyTransaction = LoyaltyTransaction(
          id: transactionId,
          userId: userId,
          programId: programId,
          type: LoyaltyTransactionType.adjustment,
          points: points,
          description: reason,
          metadata: {
            'adjustedBy': 'admin',
            'reason': reason,
          },
          createdAt: DateTime.now(),
        );

        transaction.set(
          _firestore.collection('loyalty_transactions').doc(transactionId),
          loyaltyTransaction.toMap(),
        );
      });

      return true;
    } catch (e) {
      print('Error adjusting points: $e');
      return false;
    }
  }
}
