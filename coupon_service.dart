// ============================================================================
// services/coupon_service.dart - VERSIÓN ACTUALIZADA
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/coupon_model.dart';

class CouponService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Validar y aplicar un cupón
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String userId,
    required double orderAmount,
    String? businessCategory,
  }) async {
    try {
      // Buscar el cupón por código (case insensitive)
      final querySnapshot = await _firestore
          .collection('coupons')
          .where('code', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Cupón no válido',
        };
      }

      final couponData = querySnapshot.docs.first.data();
      final coupon = Coupon.fromMap(couponData);

      // Verificar si el cupón es válido
      if (!coupon.isValid()) {
        if (!coupon.isActive) {
          return {
            'success': false,
            'message': 'Este cupón ya no está disponible',
          };
        }
        if (coupon.expiryDate != null && DateTime.now().isAfter(coupon.expiryDate!)) {
          return {
            'success': false,
            'message': 'Este cupón expiró',
          };
        }
        if (coupon.maxUses != null && coupon.currentUses >= coupon.maxUses!) {
          return {
            'success': false,
            'message': 'Este cupón alcanzó su límite de usos',
          };
        }
      }

      // Verificar monto mínimo
      if (coupon.minAmount != null && orderAmount < coupon.minAmount!) {
        return {
          'success': false,
          'message': 'Monto mínimo requerido: \$${coupon.minAmount!.toInt()}',
        };
      }

      // Verificar si aplica a la categoría
      if (businessCategory != null && !coupon.appliesTo(businessCategory)) {
        return {
          'success': false,
          'message': 'Este cupón no aplica para esta categoría',
        };
      }

      // Verificar si es solo para primer pedido
      if (coupon.isFirstOrderOnly) {
        final userOrders = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: userId)
            .where('status', isEqualTo: 'delivered')
            .limit(1)
            .get();

        if (userOrders.docs.isNotEmpty) {
          return {
            'success': false,
            'message': 'Este cupón es solo para tu primer pedido',
          };
        }
      }

      // Calcular descuento
      final discount = coupon.calculateDiscount(orderAmount);

      return {
        'success': true,
        'message': 'Cupón aplicado correctamente',
        'coupon': coupon,
        'discount': discount,
      };
    } catch (e) {
      print('Error al validar cupón: $e');
      return {
        'success': false,
        'message': 'Error al validar el cupón',
      };
    }
  }

  // Usar un cupón (incrementar contador)
  Future<void> useCoupon(String couponId) async {
    try {
      await _firestore.collection('coupons').doc(couponId).update({
        'currentUses': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error al usar cupón: $e');
    }
  }

  // Guardar cupón del usuario
  Future<bool> saveUserCoupon({
    required String userId,
    required String couponId,
    required String couponCode,
    CouponSource source = CouponSource.general,
  }) async {
    try {
      // Verificar si ya lo tiene guardado
      final existing = await _firestore
          .collection('user_coupons')
          .where('userId', isEqualTo: userId)
          .where('couponCode', isEqualTo: couponCode)
          .where('isUsed', isEqualTo: false)
          .get();

      if (existing.docs.isNotEmpty) {
        return false; // Ya lo tiene guardado
      }

      final userCouponId = _firestore.collection('user_coupons').doc().id;

      final userCoupon = UserCoupon(
        id: userCouponId,
        userId: userId,
        couponId: couponId,
        couponCode: couponCode,
        savedAt: DateTime.now(),
        source: source,
      );

      await _firestore
          .collection('user_coupons')
          .doc(userCouponId)
          .set(userCoupon.toMap());

      return true;
    } catch (e) {
      print('Error al guardar cupón: $e');
      return false;
    }
  }

  // Marcar cupón como usado
  Future<void> markCouponAsUsed({
    required String userId,
    required String couponCode,
    required String orderId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('user_coupons')
          .where('userId', isEqualTo: userId)
          .where('couponCode', isEqualTo: couponCode)
          .where('isUsed', isEqualTo: false)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'isUsed': true,
          'usedAt': DateTime.now().toIso8601String(),
          'orderId': orderId,
        });
      }
    } catch (e) {
      print('Error al marcar cupón como usado: $e');
    }
  }

  // Obtener cupones disponibles
  Stream<List<Coupon>> getAvailableCoupons() {
    return _firestore
        .collection('coupons')
        .where('isActive', isEqualTo: true)
        .orderBy('isFeatured', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Coupon.fromMap(doc.data()))
          .where((coupon) => coupon.isValid())
          .toList();
    });
  }

  // Obtener cupones del usuario
  Stream<List<UserCoupon>> getUserCoupons(String userId) {
    return _firestore
        .collection('user_coupons')
        .where('userId', isEqualTo: userId)
        .where('isUsed', isEqualTo: false)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserCoupon.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener información completa de un cupón guardado
  Future<Coupon?> getCouponDetails(String couponId) async {
    try {
      final doc = await _firestore.collection('coupons').doc(couponId).get();
      if (!doc.exists) return null;
      return Coupon.fromMap(doc.data()!);
    } catch (e) {
      print('Error al obtener detalles del cupón: $e');
      return null;
    }
  }

  // Obtener historial de cupones usados
  Stream<List<UserCoupon>> getUsedCoupons(String userId) {
    return _firestore
        .collection('user_coupons')
        .where('userId', isEqualTo: userId)
        .where('isUsed', isEqualTo: true)
        .orderBy('usedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserCoupon.fromMap(doc.data()))
          .toList();
    });
  }

  // Otorgar cupón por logro
  Future<bool> grantAchievementCoupon({
    required String userId,
    required String achievement,
  }) async {
    try {
      // Lógica para crear un cupón personalizado por logro
      final couponId = _firestore.collection('coupons').doc().id;
      
      // Ejemplo: 10% de descuento por completar 10 pedidos
      final coupon = Coupon(
        id: couponId,
        code: 'LOGRO${DateTime.now().millisecondsSinceEpoch}',
        description: '¡Felicitaciones! Ganaste este cupón por: $achievement',
        type: CouponType.percentage,
        value: 10,
        isActive: true,
        createdAt: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 30)),
        source: CouponSource.achievement,
        promoText: '🏆 Cupón de Logro',
      );

      // Crear el cupón
      await _firestore
          .collection('coupons')
          .doc(couponId)
          .set(coupon.toMap());

      // Guardarlo automáticamente al usuario
      await saveUserCoupon(
        userId: userId,
        couponId: couponId,
        couponCode: coupon.code,
        source: CouponSource.achievement,
      );

      return true;
    } catch (e) {
      print('Error al otorgar cupón de logro: $e');
      return false;
    }
  }

  // Otorgar cupón por referido
  Future<bool> grantReferralCoupon({
    required String userId,
    required String referredUserId,
  }) async {
    try {
      final couponId = _firestore.collection('coupons').doc().id;
      
      final coupon = Coupon(
        id: couponId,
        code: 'REFERIDO${DateTime.now().millisecondsSinceEpoch}',
        description: '¡Gracias por invitar a un amigo! Ambos ganan \$100',
        type: CouponType.fixed,
        value: 100,
        isActive: true,
        createdAt: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 60)),
        source: CouponSource.referral,
        promoText: '👥 Cupón de Referido',
      );

      await _firestore
          .collection('coupons')
          .doc(couponId)
          .set(coupon.toMap());

      // Dar cupón a ambos usuarios
      await saveUserCoupon(
        userId: userId,
        couponId: couponId,
        couponCode: coupon.code,
        source: CouponSource.referral,
      );

      await saveUserCoupon(
        userId: referredUserId,
        couponId: couponId,
        couponCode: coupon.code,
        source: CouponSource.referral,
      );

      return true;
    } catch (e) {
      print('Error al otorgar cupón de referido: $e');
      return false;
    }
  }

  // Verificar y otorgar cupón de cumpleaños
  Future<void> checkBirthdayCoupon(String userId, DateTime birthDate) async {
    try {
      final now = DateTime.now();
      final isBirthday = now.month == birthDate.month && now.day == birthDate.day;

      if (!isBirthday) return;

      // Verificar si ya se le dio este año
      final existingBirthdayCoupon = await _firestore
          .collection('user_coupons')
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: 'birthday')
          .get();

      for (var doc in existingBirthdayCoupon.docs) {
        final userCoupon = UserCoupon.fromMap(doc.data());
        if (userCoupon.savedAt.year == now.year) {
          return; // Ya tiene cupón de este año
        }
      }

      // Crear cupón de cumpleaños
      final couponId = _firestore.collection('coupons').doc().id;
      
      final coupon = Coupon(
        id: couponId,
        code: 'CUMPLE${now.year}',
        description: '🎂 ¡Feliz cumpleaños! Disfrutá tu regalo especial',
        type: CouponType.percentage,
        value: 20,
        isActive: true,
        createdAt: DateTime.now(),
        expiryDate: DateTime.now().add(const Duration(days: 7)),
        source: CouponSource.birthday,
        promoText: '🎉 Regalo de Cumpleaños',
      );

      await _firestore
          .collection('coupons')
          .doc(couponId)
          .set(coupon.toMap());

      await saveUserCoupon(
        userId: userId,
        couponId: couponId,
        couponCode: coupon.code,
        source: CouponSource.birthday,
      );

      // TODO: Enviar notificación de cumpleaños
    } catch (e) {
      print('Error al verificar cupón de cumpleaños: $e');
    }
  }

  // Obtener estadísticas de cupones del usuario
  Future<Map<String, dynamic>> getUserCouponStats(String userId) async {
    try {
      final allCoupons = await _firestore
          .collection('user_coupons')
          .where('userId', isEqualTo: userId)
          .get();

      int totalSaved = 0;
      int totalUsed = 0;
      double totalSavings = 0;

      for (var doc in allCoupons.docs) {
        final userCoupon = UserCoupon.fromMap(doc.data());
        
        if (userCoupon.isUsed) {
          totalUsed++;
          
          // Calcular ahorro (necesitaríamos el monto del pedido)
          // Por ahora es aproximado
        } else {
          totalSaved++;
        }
      }

      return {
        'totalSaved': totalSaved,
        'totalUsed': totalUsed,
        'totalSavings': totalSavings,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {
        'totalSaved': 0,
        'totalUsed': 0,
        'totalSavings': 0,
      };
    }
  }
}