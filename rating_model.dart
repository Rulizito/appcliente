// ============================================================================
// models/rating_model.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class Rating {
  final String id;
  final String userId;
  final String userName;
  final String orderId;
  final String businessId;
  final String businessName;
  final int stars; // 1 a 5
  final String? comment;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.userId,
    required this.userName,
    required this.orderId,
    required this.businessId,
    required this.businessName,
    required this.stars,
    this.comment,
    required this.createdAt,
  });

  // Convertir a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'orderId': orderId,
      'businessId': businessId,
      'businessName': businessName,
      'stars': stars,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Crear desde Map de Firestore
  factory Rating.fromMap(Map<String, dynamic> map) {
    return Rating(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      orderId: map['orderId'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      stars: map['stars'] ?? 5,
      comment: map['comment'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// Modelo para estadísticas de calificación de un negocio
class BusinessRatingStats {
  final String businessId;
  final double averageRating;
  final int totalRatings;
  final Map<int, int> starsDistribution; // {1: 5, 2: 10, 3: 20, 4: 30, 5: 35}

  BusinessRatingStats({
    required this.businessId,
    required this.averageRating,
    required this.totalRatings,
    required this.starsDistribution,
  });

  factory BusinessRatingStats.empty(String businessId) {
    return BusinessRatingStats(
      businessId: businessId,
      averageRating: 0.0,
      totalRatings: 0,
      starsDistribution: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
    );
  }
}