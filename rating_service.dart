// ============================================================================
// services/rating_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear una nueva calificación
  Future<Map<String, dynamic>> createRating({
    required String userId,
    required String userName,
    required String orderId,
    required String businessId,
    required String businessName,
    required int stars,
    String? comment,
  }) async {
    try {
      // Verificar si ya calificó este pedido
      final existingRating = await _firestore
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: userId)
          .get();

      if (existingRating.docs.isNotEmpty) {
        return {
          'success': false,
          'message': 'Ya calificaste este pedido',
        };
      }

      // Crear la calificación
      final ratingId = _firestore.collection('ratings').doc().id;

      final rating = Rating(
        id: ratingId,
        userId: userId,
        userName: userName,
        orderId: orderId,
        businessId: businessId,
        businessName: businessName,
        stars: stars,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await _firestore.collection('ratings').doc(ratingId).set(rating.toMap());

      // Actualizar el promedio de calificación del negocio
      await _updateBusinessRating(businessId);

      return {
        'success': true,
        'message': '¡Gracias por tu calificación!',
      };
    } catch (e) {
      print('Error al crear calificación: $e');
      return {
        'success': false,
        'message': 'Error al guardar la calificación',
      };
    }
  }

  // Actualizar el promedio de calificación de un negocio
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('ratings')
          .where('businessId', isEqualTo: businessId)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

      // Calcular promedio
      double total = 0;
      for (var doc in ratingsSnapshot.docs) {
        final rating = Rating.fromMap(doc.data());
        total += rating.stars;
      }

      final average = total / ratingsSnapshot.docs.length;

      // Actualizar en el negocio
      await _firestore.collection('businesses').doc(businessId).update({
        'rating': average,
        'totalRatings': ratingsSnapshot.docs.length,
        'ratingUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error al actualizar rating del negocio: $e');
    }
  }

  // Verificar si un pedido ya fue calificado
  Future<bool> isOrderRated(String orderId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error al verificar calificación: $e');
      return false;
    }
  }

  // Obtener calificación de un pedido específico
  Future<Rating?> getOrderRating(String orderId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return Rating.fromMap(snapshot.docs.first.data());
    } catch (e) {
      print('Error al obtener calificación: $e');
      return null;
    }
  }

  // Obtener todas las calificaciones de un negocio
  Stream<List<Rating>> getBusinessRatings(String businessId) {
    return _firestore
        .collection('ratings')
        .where('businessId', isEqualTo: businessId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Rating.fromMap(doc.data())).toList();
    });
  }

  // Obtener estadísticas de calificación de un negocio
  Future<BusinessRatingStats> getBusinessRatingStats(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('businessId', isEqualTo: businessId)
          .get();

      if (snapshot.docs.isEmpty) {
        return BusinessRatingStats.empty(businessId);
      }

      final ratings = snapshot.docs.map((doc) => Rating.fromMap(doc.data())).toList();

      // Calcular distribución de estrellas
      Map<int, int> distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      double totalStars = 0;

      for (var rating in ratings) {
        distribution[rating.stars] = (distribution[rating.stars] ?? 0) + 1;
        totalStars += rating.stars;
      }

      final average = totalStars / ratings.length;

      return BusinessRatingStats(
        businessId: businessId,
        averageRating: average,
        totalRatings: ratings.length,
        starsDistribution: distribution,
      );
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return BusinessRatingStats.empty(businessId);
    }
  }

  // Obtener calificaciones de un usuario
  Stream<List<Rating>> getUserRatings(String userId) {
    return _firestore
        .collection('ratings')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Rating.fromMap(doc.data())).toList();
    });
  }
}