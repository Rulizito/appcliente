// ============================================================================
// services/review_service.dart - Servicio Mejorado de Reseñas
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_model.dart';
import '../models/rating_model.dart';
import 'auth_service.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  // Crear una nueva reseña
  Future<Map<String, dynamic>> createReview({
    required String businessId,
    required String businessName,
    required int rating,
    required String title,
    required String comment,
    String? orderId,
    List<String> images = const [],
    List<String> tags = const [],
    bool isRecommended = true,
    Map<String, int> aspects = const {},
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      // Verificar si ya reseñó este negocio (sin orderId)
      if (orderId == null) {
        final existingReview = await _firestore
            .collection('reviews')
            .where('businessId', isEqualTo: businessId)
            .where('userId', isEqualTo: user.uid)
            .where('orderId', isNull: true)
            .get();

        if (existingReview.docs.isNotEmpty) {
          return {
            'success': false,
            'message': 'Ya reseñaste este negocio',
          };
        }
      }

      // Verificar si ya reseñó este pedido (con orderId)
      if (orderId != null) {
        final existingReview = await _firestore
            .collection('reviews')
            .where('orderId', isEqualTo: orderId)
            .where('userId', isEqualTo: user.uid)
            .get();

        if (existingReview.docs.isNotEmpty) {
          return {
            'success': false,
            'message': 'Ya reseñaste este pedido',
          };
        }
      }

      // Obtener datos del usuario
      final userData = await _authService.getUserData(user.uid);
      
      // Crear la reseña
      final reviewId = _firestore.collection('reviews').doc().id;

      final review = Review(
        id: reviewId,
        userId: user.uid,
        userName: userData?['name'] ?? 'Usuario',
        userPhoto: userData?['photoUrl'],
        businessId: businessId,
        businessName: businessName,
        orderId: orderId,
        rating: rating,
        title: title,
        comment: comment,
        images: images,
        tags: tags,
        isVerified: orderId != null, // Es verificada si tiene orderId
        isRecommended: isRecommended,
        aspects: aspects,
        createdAt: DateTime.now(),
      );

      // Guardar la reseña
      await _firestore
          .collection('reviews')
          .doc(reviewId)
          .set(review.toMap());

      // Actualizar calificación promedio del negocio
      await _updateBusinessRating(businessId);

      // Si es reseña de pedido, actualizar también el rating antiguo
      if (orderId != null) {
        await _createLegacyRating(review);
      }

      return {
        'success': true,
        'message': 'Reseña creada exitosamente',
        'reviewId': reviewId,
      };
    } catch (e) {
      print('Error creando reseña: $e');
      return {
        'success': false,
        'message': 'Error al crear la reseña: $e',
      };
    }
  }

  // Obtener reseñas de un negocio
  Future<List<Review>> getBusinessReviews(
    String businessId, {
    int limit = 20,
    DocumentSnapshot? lastDocument,
    int? minRating,
    int? maxRating,
    bool? verifiedOnly,
    bool? withImages,
    List<String>? tags,
  }) async {
    try {
      Query query = _firestore
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true);

      // Aplicar filtros
      if (minRating != null) {
        query = query.where('rating', isGreaterThanOrEqualTo: minRating);
      }
      if (maxRating != null) {
        query = query.where('rating', isLessThanOrEqualTo: maxRating);
      }
      if (verifiedOnly == true) {
        query = query.where('isVerified', isEqualTo: true);
      }
      if (withImages == true) {
        // Esto requiere una consulta más compleja, por ahora filtramos en memoria
      }

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      
      List<Review> reviews = snapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();

      // Filtrar por imágenes y tags si es necesario
      if (withImages == true) {
        reviews = reviews.where((review) => review.hasImages).toList();
      }
      
      if (tags != null && tags.isNotEmpty) {
        reviews = reviews.where((review) {
          return review.tags.any((tag) => tags.contains(tag));
        }).toList();
      }

      return reviews;
    } catch (e) {
      print('Error obteniendo reseñas: $e');
      return [];
    }
  }

  // Obtener reseñas de un usuario
  Future<List<Review>> getUserReviews({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      Query query = _firestore
          .collection('reviews')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      
      return snapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error obteniendo reseñas del usuario: $e');
      return [];
    }
  }

  // Obtener estadísticas de reseñas de un negocio
  Future<BusinessReviewStats?> getBusinessReviewStats(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('businessId', isEqualTo: businessId)
          .where('isPublic', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final reviews = snapshot.docs
          .map((doc) => Review.fromFirestore(doc))
          .toList();

      // Calcular estadísticas
      double totalRating = 0;
      Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
      Map<String, int> aspectCounts = {};
      int verifiedCount = 0;
      int recommendedCount = 0;
      Map<String, int> tagCounts = {};

      for (final review in reviews) {
        totalRating += review.rating;
        ratingDistribution[review.rating] = (ratingDistribution[review.rating] ?? 0) + 1;
        
        if (review.isVerified) verifiedCount++;
        if (review.isRecommended) recommendedCount++;

        // Contar aspectos
        review.aspects.forEach((aspect, rating) {
          aspectCounts[aspect] = (aspectCounts[aspect] ?? 0) + rating;
        });

        // Contar tags
        for (final tag in review.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      // Calcular promedios de aspectos
      Map<String, int> aspectAverages = {};
      aspectCounts.forEach((aspect, total) {
        aspectAverages[aspect] = (total / reviews.length).round();
      });

      // Obtener tags más comunes
      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final commonTags = sortedTags
          .take(5)
          .map((entry) => entry.key)
          .toList();

      final averageRating = totalRating / reviews.length;
      final recommendedPercentage = reviews.isNotEmpty 
          ? (recommendedCount / reviews.length) * 100 
          : 0.0;

      return BusinessReviewStats(
        businessId: businessId,
        averageRating: averageRating,
        totalReviews: reviews.length,
        ratingDistribution: ratingDistribution,
        aspectAverages: aspectAverages,
        verifiedReviews: verifiedCount,
        recommendedPercentage: recommendedPercentage.round(),
        commonTags: commonTags,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return null;
    }
  }

  // Marcar reseña como útil
  Future<Map<String, dynamic>> markReviewAsHelpful(String reviewId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final reviewRef = _firestore.collection('reviews').doc(reviewId);
      final reviewDoc = await reviewRef.get();

      if (!reviewDoc.exists) {
        return {
          'success': false,
          'message': 'Reseña no encontrada',
        };
      }

      final review = Review.fromFirestore(reviewDoc);
      
      if (review.helpfulUsers.contains(user.uid)) {
        return {
          'success': false,
          'message': 'Ya marcaste esta reseña como útil',
        };
      }

      await reviewRef.update({
        'helpfulUsers': FieldValue.arrayUnion([user.uid]),
        'helpfulCount': FieldValue.increment(1),
      });

      return {
        'success': true,
        'message': 'Reseña marcada como útil',
      };
    } catch (e) {
      print('Error marcando reseña como útil: $e');
      return {
        'success': false,
        'message': 'Error al marcar reseña como útil',
      };
    }
  }

  // Responder a una reseña (desde el negocio)
  Future<Map<String, dynamic>> respondToReview({
    required String reviewId,
    required String response,
  }) async {
    try {
      final reviewRef = _firestore.collection('reviews').doc(reviewId);
      
      await reviewRef.update({
        'response': response,
        'responseDate': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      return {
        'success': true,
        'message': 'Respuesta agregada exitosamente',
      };
    } catch (e) {
      print('Error respondiendo reseña: $e');
      return {
        'success': false,
        'message': 'Error al responder la reseña',
      };
    }
  }

  // Actualizar calificación promedio del negocio
  Future<void> _updateBusinessRating(String businessId) async {
    try {
      final stats = await getBusinessReviewStats(businessId);
      if (stats == null) return;

      await _firestore
          .collection('businesses')
          .doc(businessId)
          .update({
        'rating': stats.averageRating,
        'reviewCount': stats.totalReviews,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error actualizando calificación del negocio: $e');
    }
  }

  // Crear rating legado para compatibilidad
  Future<void> _createLegacyRating(Review review) async {
    try {
      if (review.orderId == null) return;

      final legacyRating = Rating(
        id: '${review.orderId}_${review.userId}',
        userId: review.userId,
        userName: review.userName,
        orderId: review.orderId!,
        businessId: review.businessId,
        businessName: review.businessName,
        stars: review.rating,
        comment: review.comment,
        createdAt: review.createdAt,
      );

      await _firestore
          .collection('ratings')
          .doc(legacyRating.id)
          .set(legacyRating.toMap());
    } catch (e) {
      print('Error creando rating legado: $e');
    }
  }

  // Eliminar reseña
  Future<Map<String, dynamic>> deleteReview(String reviewId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final reviewRef = _firestore.collection('reviews').doc(reviewId);
      final reviewDoc = await reviewRef.get();

      if (!reviewDoc.exists) {
        return {
          'success': false,
          'message': 'Reseña no encontrada',
        };
      }

      final review = Review.fromFirestore(reviewDoc);
      
      // Solo el autor puede eliminar su reseña
      if (review.userId != user.uid) {
        return {
          'success': false,
          'message': 'No tenés permiso para eliminar esta reseña',
        };
      }

      await reviewRef.delete();

      // Actualizar calificación del negocio
      await _updateBusinessRating(review.businessId);

      return {
        'success': true,
        'message': 'Reseña eliminada exitosamente',
      };
    } catch (e) {
      print('Error eliminando reseña: $e');
      return {
        'success': false,
        'message': 'Error al eliminar la reseña',
      };
    }
  }

  // Obtener tags populares
  Future<List<String>> getPopularTags({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .get();

      Map<String, int> tagCounts = {};
      
      for (final doc in snapshot.docs) {
        final review = Review.fromFirestore(doc);
        for (final tag in review.tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }

      final sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags
          .take(limit)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      print('Error obteniendo tags populares: $e');
      return [];
    }
  }
}
