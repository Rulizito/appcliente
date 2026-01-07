// ============================================================================
// services/ai_recommendation_service_simple.dart - Versión simplificada para compilar
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart' as order_model;
import '../models/business_model.dart' as business_model;

// Enums
enum RecommendationType {
  content_based,
  collaborative,
  time_based,
  location_based,
  hybrid,
}

class Recommendation {
  final String id;
  final RecommendationType type;
  final String businessId;
  final business_model.Business business;
  final double score;
  final String reason;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  Recommendation({
    required this.id,
    required this.type,
    required this.businessId,
    required this.business,
    required this.score,
    required this.reason,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'businessId': businessId,
      'business': business.toMap(),
      'score': score,
      'reason': reason,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Recommendation.fromMap(Map<String, dynamic> map) {
    return Recommendation(
      id: map['id'] ?? '',
      type: RecommendationType.values.firstWhere(
        (type) => type.name == map['type'],
        orElse: () => RecommendationType.hybrid,
      ),
      businessId: map['businessId'] ?? '',
      business: business_model.Business.fromMap(
        map['business'] as Map<String, dynamic>,
        map['business']['id'] ?? '',
      ),
      score: (map['score'] ?? 0.0).toDouble(),
      reason: map['reason'] ?? '',
      data: map['data'] ?? {},
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

class UserProfile {
  final String userId;
  final Map<String, double> categoryPreferences;
  final Map<String, double> businessPreferences;
  final Map<String, double> timePreferences;
  final Map<String, double> pricePreferences;
  final List<String> favoriteCategories;
  final List<String> favoriteBusinesses;
  final double avgOrderValue;
  final int totalOrders;
  final DateTime lastOrderDate;
  final Map<String, dynamic> metadata;

  UserProfile({
    required this.userId,
    required this.categoryPreferences,
    required this.businessPreferences,
    required this.timePreferences,
    required this.pricePreferences,
    required this.favoriteCategories,
    required this.favoriteBusinesses,
    required this.avgOrderValue,
    required this.totalOrders,
    required this.lastOrderDate,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'categoryPreferences': categoryPreferences,
      'businessPreferences': businessPreferences,
      'timePreferences': timePreferences,
      'pricePreferences': pricePreferences,
      'favoriteCategories': favoriteCategories,
      'favoriteBusinesses': favoriteBusinesses,
      'avgOrderValue': avgOrderValue,
      'totalOrders': totalOrders,
      'lastOrderDate': Timestamp.fromDate(lastOrderDate),
      'metadata': metadata,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] ?? '',
      categoryPreferences: Map<String, double>.from(map['categoryPreferences'] ?? {}),
      businessPreferences: Map<String, double>.from(map['businessPreferences'] ?? {}),
      timePreferences: Map<String, double>.from(map['timePreferences'] ?? {}),
      pricePreferences: Map<String, double>.from(map['pricePreferences'] ?? {}),
      favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
      favoriteBusinesses: List<String>.from(map['favoriteBusinesses'] ?? []),
      avgOrderValue: (map['avgOrderValue'] ?? 0).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      lastOrderDate: (map['lastOrderDate'] as Timestamp).toDate(),
      metadata: map['metadata'] ?? {},
    );
  }
}

class AIRecommendationService {
  static final AIRecommendationService _instance = AIRecommendationService._internal();
  factory AIRecommendationService() => _instance;
  AIRecommendationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener recomendaciones personalizadas
  Future<List<Recommendation>> getPersonalizedRecommendations(
    String userId, {
    int limit = 10,
    List<RecommendationType> types = const [RecommendationType.hybrid],
  }) async {
    try {
      // Por ahora, devolver lista vacía para evitar errores
      return [];
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  // Guardar feedback de recomendación
  Future<void> saveRecommendationFeedback(String recommendationId, bool isPositive) async {
    try {
      await _firestore.collection('recommendation_feedback').add({
        'recommendationId': recommendationId,
        'userId': _auth.currentUser?.uid,
        'isPositive': isPositive,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving recommendation feedback: $e');
    }
  }

  // Obtener perfil de usuario
  Future<UserProfile> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('user_profiles').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data()!);
      }
      return _createDefaultProfile(userId);
    } catch (e) {
      print('Error getting user profile: $e');
      return _createDefaultProfile(userId);
    }
  }

  // Crear perfil por defecto
  UserProfile _createDefaultProfile(String userId) {
    return UserProfile(
      userId: userId,
      categoryPreferences: {},
      businessPreferences: {},
      timePreferences: {},
      pricePreferences: {},
      favoriteCategories: [],
      favoriteBusinesses: [],
      avgOrderValue: 0.0,
      totalOrders: 0,
      lastOrderDate: DateTime.now(),
      metadata: {},
    );
  }
}
