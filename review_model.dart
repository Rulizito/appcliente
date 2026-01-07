// ============================================================================
// models/review_model.dart - Modelo de Reseñas Mejorado
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String businessId;
  final String businessName;
  final String? orderId; // Opcional - puede ser reseña general
  final int rating; // 1 a 5 estrellas
  final String title; // Título de la reseña
  final String comment; // Comentario detallado
  final List<String> images; // URLs de imágenes adjuntas
  final List<String> tags; // Tags descriptivos (ej: "Rápido", "Buen servicio")
  final bool isVerified; // Si el usuario realizó un pedido
  final bool isRecommended; // Si recomienda el negocio
  final Map<String, int> aspects; // Calificación por aspectos (comida, servicio, envío)
  final String? response; // Respuesta del negocio
  final DateTime? responseDate; // Fecha de respuesta del negocio
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublic; // Si la reseña es pública
  final int helpfulCount; // Contador de "útil"
  final List<String> helpfulUsers; // Usuarios que marcaron como útil

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.businessId,
    required this.businessName,
    this.orderId,
    required this.rating,
    required this.title,
    required this.comment,
    this.images = const [],
    this.tags = const [],
    this.isVerified = false,
    this.isRecommended = true,
    this.aspects = const {},
    this.response,
    this.responseDate,
    required this.createdAt,
    this.updatedAt,
    this.isPublic = true,
    this.helpfulCount = 0,
    this.helpfulUsers = const [],
  });

  // Crear desde Firestore
  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhoto: map['userPhoto'],
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      orderId: map['orderId'],
      rating: (map['rating'] ?? 0).toInt(),
      title: map['title'] ?? '',
      comment: map['comment'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      tags: List<String>.from(map['tags'] ?? []),
      isVerified: map['isVerified'] ?? false,
      isRecommended: map['isRecommended'] ?? true,
      aspects: Map<String, int>.from(map['aspects'] ?? {}),
      response: map['response'],
      responseDate: map['responseDate'] != null 
          ? (map['responseDate'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      isPublic: map['isPublic'] ?? true,
      helpfulCount: map['helpfulCount'] ?? 0,
      helpfulUsers: List<String>.from(map['helpfulUsers'] ?? []),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'businessId': businessId,
      'businessName': businessName,
      'orderId': orderId,
      'rating': rating,
      'title': title,
      'comment': comment,
      'images': images,
      'tags': tags,
      'isVerified': isVerified,
      'isRecommended': isRecommended,
      'aspects': aspects,
      'response': response,
      'responseDate': responseDate != null ? Timestamp.fromDate(responseDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isPublic': isPublic,
      'helpfulCount': helpfulCount,
      'helpfulUsers': helpfulUsers,
    };
  }

  // Calificación formateada
  String get formattedRating {
    return '$rating.0';
  }

  // Verificar si tiene imágenes
  bool get hasImages => images.isNotEmpty;

  // Verificar si tiene respuesta del negocio
  bool get hasResponse => response != null && response!.isNotEmpty;

  // Verificar si es reseña verificada (con pedido real)
  bool get isVerifiedReview => isVerified && orderId != null;

  // Obtener fecha formateada
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'Ahora';
    }
  }

  // Copia con valores actualizados
  Review copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhoto,
    String? businessId,
    String? businessName,
    String? orderId,
    int? rating,
    String? title,
    String? comment,
    List<String>? images,
    List<String>? tags,
    bool? isVerified,
    bool? isRecommended,
    Map<String, int>? aspects,
    String? response,
    DateTime? responseDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    int? helpfulCount,
    List<String>? helpfulUsers,
  }) {
    return Review(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      orderId: orderId ?? this.orderId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      images: images ?? this.images,
      tags: tags ?? this.tags,
      isVerified: isVerified ?? this.isVerified,
      isRecommended: isRecommended ?? this.isRecommended,
      aspects: aspects ?? this.aspects,
      response: response ?? this.response,
      responseDate: responseDate ?? this.responseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulUsers: helpfulUsers ?? this.helpfulUsers,
    );
  }

  @override
  String toString() {
    return 'Review(id: $id, rating: $rating, title: $title, business: $businessName)';
  }
}

// Modelo para estadísticas de reseñas de un negocio
class BusinessReviewStats {
  final String businessId;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // 1-5 estrellas: cantidad
  final Map<String, int> aspectAverages; // Promedio por aspecto
  final int verifiedReviews;
  final int recommendedPercentage;
  final List<String> commonTags;
  final DateTime lastUpdated;

  BusinessReviewStats({
    required this.businessId,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
    required this.aspectAverages,
    required this.verifiedReviews,
    required this.recommendedPercentage,
    required this.commonTags,
    required this.lastUpdated,
  });

  // Calificación formateada
  String get formattedRating {
    return averageRating.toStringAsFixed(1);
  }

  // Porcentaje de reseñas verificadas
  double get verifiedPercentage {
    if (totalReviews == 0) return 0.0;
    return (verifiedReviews / totalReviews) * 100;
  }

  // Estrellas más comunes
  int get mostCommonRating {
    if (ratingDistribution.isEmpty) return 0;
    
    int maxCount = 0;
    int mostCommon = 0;
    
    ratingDistribution.forEach((rating, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = rating;
      }
    });
    
    return mostCommon;
  }

  @override
  String toString() {
    return 'BusinessReviewStats(businessId: $businessId, averageRating: $averageRating, totalReviews: $totalReviews)';
  }
}
