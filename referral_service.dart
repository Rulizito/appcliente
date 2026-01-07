// ============================================================================
// services/referral_service.dart - Servicio de Referidos
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/referral_model.dart';
import 'coupon_service.dart';
import 'dart:math';

class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _couponService = CouponService();

  // Generar código de referido único
  String _generateReferralCode(String userName) {
    final random = Random();
    final randomNum = random.nextInt(9999);
    
    // Tomar primeras letras del nombre
    final namePrefix = userName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z]'), '')
        .substring(0, min(4, userName.length));
    
    return '$namePrefix$randomNum';
  }

  // Crear perfil de referido para nuevo usuario
  Future<UserReferral> createUserReferral({
    required String userId,
    required String userName,
    String? referredByCode,
  }) async {
    try {
      // Generar código único
      String code = _generateReferralCode(userName);
      
      // Verificar que sea único
      bool isUnique = false;
      int attempts = 0;
      
      while (!isUnique && attempts < 10) {
        final existing = await _firestore
            .collection('user_referrals')
            .where('referralCode', isEqualTo: code)
            .get();
        
        if (existing.docs.isEmpty) {
          isUnique = true;
        } else {
          code = _generateReferralCode(userName);
          attempts++;
        }
      }

      final userReferral = UserReferral(
        userId: userId,
        referralCode: code,
        referredBy: referredByCode,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('user_referrals')
          .doc(userId)
          .set(userReferral.toMap());

      // Si fue referido por alguien, procesar la recompensa
      if (referredByCode != null && referredByCode.isNotEmpty) {
        await _processReferral(
          referrerCode: referredByCode,
          newUserId: userId,
        );
      }

      return userReferral;
    } catch (e) {
      print('Error al crear perfil de referido: $e');
      rethrow;
    }
  }

  // Procesar referido exitoso
  Future<void> _processReferral({
    required String referrerCode,
    required String newUserId,
  }) async {
    try {
      // Buscar al referidor
      final referrerSnapshot = await _firestore
          .collection('user_referrals')
          .where('referralCode', isEqualTo: referrerCode)
          .limit(1)
          .get();

      if (referrerSnapshot.docs.isEmpty) {
        print('Código de referido no encontrado');
        return;
      }

      final referrerDoc = referrerSnapshot.docs.first;
      final referrer = UserReferral.fromMap(referrerDoc.data());

      // Obtener datos del nuevo usuario
      final newUserDoc = await _firestore
          .collection('users')
          .doc(newUserId)
          .get();

      if (!newUserDoc.exists) return;

      final newUserData = newUserDoc.data()!;

      // Crear registro de referido
      final referralId = _firestore.collection('referrals').doc().id;
      
      final referral = Referral(
        id: referralId,
        referrerId: referrer.userId,
        referrerCode: referrerCode,
        referredUserId: newUserId,
        referredUserName: newUserData['name'] ?? 'Usuario',
        referredUserEmail: newUserData['email'] ?? '',
        createdAt: DateTime.now(),
        rewardAmount: 100,
      );

      await _firestore
          .collection('referrals')
          .doc(referralId)
          .set(referral.toMap());

      // Actualizar contador del referidor
      await _firestore
          .collection('user_referrals')
          .doc(referrer.userId)
          .update({
        'totalReferrals': FieldValue.increment(1),
        'totalEarnings': FieldValue.increment(100),
        'referredUsers': FieldValue.arrayUnion([newUserId]),
      });

      // Dar cupones a ambos usuarios
      await _couponService.grantReferralCoupon(
        userId: referrer.userId,
        referredUserId: newUserId,
      );

      // Marcar recompensa como entregada
      await _firestore
          .collection('referrals')
          .doc(referralId)
          .update({'rewardClaimed': true});

      print('✅ Referido procesado exitosamente');
    } catch (e) {
      print('Error al procesar referido: $e');
    }
  }

  // Verificar si un código de referido existe
  Future<bool> isValidReferralCode(String code) async {
    try {
      if (code.isEmpty) return false;

      final snapshot = await _firestore
          .collection('user_referrals')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error al verificar código: $e');
      return false;
    }
  }

  // Obtener perfil de referido del usuario
  Future<UserReferral?> getUserReferral(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_referrals')
          .doc(userId)
          .get();

      if (!doc.exists) return null;

      return UserReferral.fromMap(doc.data()!);
    } catch (e) {
      print('Error al obtener referido: $e');
      return null;
    }
  }

  // Stream del perfil de referido
  Stream<UserReferral?> getUserReferralStream(String userId) {
    return _firestore
        .collection('user_referrals')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return UserReferral.fromMap(snapshot.data()!);
    });
  }

  // Obtener lista de personas que invitaste
  Stream<List<Referral>> getMyReferrals(String userId) {
    return _firestore
        .collection('referrals')
        .where('referrerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Referral.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener estadísticas de referidos
  Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      final userReferral = await getUserReferral(userId);
      
      if (userReferral == null) {
        return {
          'totalReferrals': 0,
          'totalEarnings': 0.0,
          'pendingRewards': 0,
          'claimedRewards': 0,
        };
      }

      final referrals = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();

      int pendingRewards = 0;
      int claimedRewards = 0;

      for (var doc in referrals.docs) {
        final referral = Referral.fromMap(doc.data());
        if (referral.rewardClaimed) {
          claimedRewards++;
        } else {
          pendingRewards++;
        }
      }

      return {
        'totalReferrals': userReferral.totalReferrals,
        'totalEarnings': userReferral.totalEarnings,
        'pendingRewards': pendingRewards,
        'claimedRewards': claimedRewards,
        'referralCode': userReferral.referralCode,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {
        'totalReferrals': 0,
        'totalEarnings': 0.0,
        'pendingRewards': 0,
        'claimedRewards': 0,
      };
    }
  }

  // Obtener top referidores (leaderboard)
  Future<List<Map<String, dynamic>>> getTopReferrers({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('user_referrals')
          .orderBy('totalReferrals', descending: true)
          .limit(limit)
          .get();

      List<Map<String, dynamic>> topReferrers = [];

      for (var doc in snapshot.docs) {
        final referral = UserReferral.fromMap(doc.data());
        
        // Obtener nombre del usuario
        final userDoc = await _firestore
            .collection('users')
            .doc(referral.userId)
            .get();
        
        final userName = userDoc.exists && userDoc.data() != null
            ? userDoc.data()!['name'] ?? 'Usuario'
            : 'Usuario';

        topReferrers.add({
          'userId': referral.userId,
          'userName': userName,
          'referralCode': referral.referralCode,
          'totalReferrals': referral.totalReferrals,
          'totalEarnings': referral.totalEarnings,
        });
      }

      return topReferrers;
    } catch (e) {
      print('Error al obtener top referidores: $e');
      return [];
    }
  }
}