import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart' as order_model;
import '../models/business_model.dart' as business_model;

// Enums y clases movidos al nivel superior
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
      'avgOrderValue': (map['avgOrderValue'] as num).toDouble(),
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
      return await _createUserProfile(userId);
    } catch (e) {
      print('Error getting user profile: $e');
      return _createDefaultProfile(userId);
    }
  }

  // Crear perfil de usuario
  Future<UserProfile> _createUserProfile(String userId) async {
    try {
      final orders = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final profile = _analyzeUserOrders(userId, orders.docs);
      
      await _firestore.collection('user_profiles').doc(userId).set(profile.toMap());
      return profile;
    } catch (e) {
      print('Error creating user profile: $e');
      return _createDefaultProfile(userId);
    }
  }

  // Analizar pedidos del usuario
  UserProfile _analyzeUserOrders(String userId, List<QueryDocumentSnapshot> orderDocs) {
    final categoryPrefs = <String, double>{};
    final businessPrefs = <String, double>{};
    final timePrefs = <String, double>{};
    final pricePrefs = <String, double>{};
    final categories = <String>[];
    final businesses = <String>[];
    double totalValue = 0;
    int orderCount = orderDocs.length;
    DateTime? lastOrder;

    for (final doc in orderDocs) {
      final order = order_model.Order.fromMap(doc.data() as Map<String, dynamic>);
      
      // Analizar categorías
      for (final item in order.items) {
        final category = item.category ?? 'General';
        categoryPrefs[category] = (categoryPrefs[category] ?? 0) + 1;
        categories.add(category);
      }
      
      // Analizar negocios
      businessPrefs[order.businessId] = (businessPrefs[order.businessId] ?? 0) + 1;
      businesses.add(order.businessId);
      
      // Analizar tiempo
      final hour = order.createdAt.hour;
      final timeSlot = hour < 12 ? 'morning' : hour < 18 ? 'afternoon' : 'evening';
      timePrefs[timeSlot] = (timePrefs[timeSlot] ?? 0) + 1;
      
      // Analizar precio
      totalValue += order.total;
    }

    final avgOrderValue = orderCount > 0 ? totalValue / orderCount : 0;
    lastOrder = orderDocs.isNotEmpty ? (orderDocs.first['createdAt'] as Timestamp).toDate() : null;

    return UserProfile(
      userId: userId,
      categoryPreferences: categoryPrefs,
      businessPreferences: businessPrefs,
      timePreferences: timePrefs,
      pricePreferences: pricePrefs,
      favoriteCategories: categories,
      favoriteBusinesses: businesses,
      avgOrderValue: (map['avgOrderValue'] ?? 0).toDouble(),
      totalOrders: orderCount,
      lastOrderDate: lastOrder != null ? (lastOrder as Timestamp).toDate() : DateTime.now();
      metadata: {},
    );
  }

  // Obtener recomendaciones personalizadas
  Future<List<Recommendation>> getPersonalizedRecommendations(
    String userId, {
    List<RecommendationType>? types,
    int limit = 10,
  }) async {
    try {
      final profile = await getUserProfile(userId);
      final recommendations = <Recommendation>[];
      
      final typesToGenerate = types ?? [
        RecommendationType.content_based,
        RecommendationType.collaborative,
        RecommendationType.time_based,
        RecommendationType.hybrid,
      ];

      for (final type in typesToGenerate) {
        final typeRecommendations = await _generateRecommendations(
          profile,
          type,
          limit: (limit / typesToGenerate.length).ceil(),
        );
        recommendations.addAll(typeRecommendations);
      }

      // Ordenar por score
      recommendations.sort((a, b) => b.score.compareTo(a.score));
      
      return recommendations.take(limit).toList();
    } catch (e) {
      print('Error getting personalized recommendations: $e');
      return [];
    }
  }

  // Generar recomendaciones por tipo
  Future<List<Recommendation>> _generateRecommendations(
    UserProfile profile,
    RecommendationType type, {
    int limit = 10,
  }) async {
    switch (type) {
      case RecommendationType.content_based:
        return await _generateContentBasedRecommendations(profile, limit);
      case RecommendationType.collaborative:
        return await _generateCollaborativeRecommendations(profile, limit);
      case RecommendationType.time_based:
        return await _generateTimeBasedRecommendations(profile, limit);
      case RecommendationType.location_based:
        return await _generateLocationBasedRecommendations(profile, limit);
      case RecommendationType.hybrid:
        return await _generateHybridRecommendations(profile, limit);
    }
  }

  // Recomendaciones basadas en contenido
  Future<List<Recommendation>> _generateContentBasedRecommendations(
    UserProfile profile,
    int limit,
  ) async {
    try {
      final businesses = await _getBusinessesByCategories(profile.favoriteCategories);
      final recommendations = <Recommendation>[];

      for (final business in businesses) {
        final score = _calculateContentBasedScore(profile, business);
        if (score > 0.3) {
          recommendations.add(Recommendation(
            id: _firestore.collection('recommendations').doc().id,
            type: RecommendationType.content_based,
            businessId: business.id,
            business: business,
            score: score,
            reason: _generateReason(score, type),
            data: {'business': business.toMap()},
            createdAt: DateTime.now(),
          ));
        }
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(limit).toList();
    } catch (e) {
      print('Error generating content-based recommendations: $e');
      return [];
    }
  }

  // Recomendaciones colaborativas
  Future<List<Recommendation>> _generateCollaborativeRecommendations(
    UserProfile profile,
    int limit,
  ) async {
    try {
      final similarUsers = await _findSimilarUsers(profile.userId, profile);
      final recommendations = <Recommendation>[];

      for (final userId in similarUsers) {
        final userBusinesses = await _getUserFavoriteBusinesses(userId);
        for (final businessId in userBusinesses) {
          if (!profile.favoriteBusinesses.contains(businessId)) {
            final business = await _getBusiness(businessId);
            if (business != null) {
              final score = _calculateCollaborativeScore(profile, business);
              recommendations.add(Recommendation(
                id: _firestore.collection('recommendations').doc().id,
                type: RecommendationType.collaborative,
                businessId: businessId,
                business: business,
                score: score,
                reason: _generateReason(score, RecommendationType.collaborative),
                data: {'business': business.toMap()},
                createdAt: DateTime.now(),
              ));
            }
          }
        }
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(limit).toList();
    } catch (e) {
      print('Error generating collaborative recommendations: $e');
      return [];
    }
  }

  // Recomendaciones basadas en tiempo
  Future<List<Recommendation>> _generateTimeBasedRecommendations(
    UserProfile profile,
    int limit,
  ) async {
    try {
      final currentHour = DateTime.now().hour;
      final businesses = await _getOpenBusinesses();
      final recommendations = <Recommendation>[];

      for (final business in businesses) {
        final score = _calculateTimeBasedScore(profile, business, currentHour);
        if (score > 0.2) {
          recommendations.add(Recommendation(
            id: _firestore.collection('recommendations').doc().id,
            type: RecommendationType.time_based,
            businessId: business.id,
            business: business,
            score: score,
            reason: _generateReason(score, RecommendationType.time_based),
            data: {'business': business.toMap()},
            createdAt: DateTime.now(),
          ));
        }
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(limit).toList();
    } catch (e) {
      print('Error generating time-based recommendations: $e');
      return [];
    }
  }

  // Recomendaciones basadas en ubicación
  Future<List<Recommendation>> _generateLocationBasedRecommendations(
    UserProfile profile,
    int limit,
  ) async {
    try {
      // Simular ubicación del usuario (en una app real vendría del GPS)
      final userLat = -34.6037; // Buenos Aires
      final userLng = -58.3816;
      
      final businesses = await _getBusinesses();
      final recommendations = <Recommendation>[];

      for (final business in businesses) {
        final distance = _calculateDistance(userLat, userLng, business.latitude, business.longitude);
        final score = _calculateLocationBasedScore(profile, business, distance);
        if (score > 0.1 && distance < 10) { // Menos de 10km
          recommendations.add(Recommendation(
            id: _firestore.collection('recommendations').doc().id,
            type: RecommendationType.location_based,
            businessId: business.id,
            business: business,
            score: score,
            reason: _generateReason(score, RecommendationType.location_based),
            data: {'business': business.toMap()},
            createdAt: DateTime.now(),
          ));
        }
      }

      recommendations.sort((a, b) => b.score.compareTo(a.score));
      return recommendations.take(limit).toList();
    } catch (e) {
      print('Error generating location-based recommendations: $e');
      return [];
    }
  }

  // Recomendaciones híbridas
  Future<List<Recommendation>> _generateHybridRecommendations(
    UserProfile profile,
    int limit,
  ) async {
    try {
      final contentRecs = await _generateContentBasedRecommendations(profile, limit ~/ 2);
      final collaborativeRecs = await _generateCollaborativeRecommendations(profile, limit ~/ 2);
      final timeRecs = await _generateTimeBasedRecommendations(profile, limit ~/ 2);
      final locationRecs = await _generateLocationBasedRecommendations(profile, limit ~/ 2);
      
      final allRecs = [...contentRecs, ...collaborativeRecs, ...timeRecs, ...locationRecs];
      
      // Calcular scores híbridos
      final hybridRecs = allRecs.map((rec) {
        final hybridScore = _calculateHybridScore(profile, rec);
        return Recommendation(
          id: rec.id,
          type: RecommendationType.hybrid,
          businessId: rec.businessId,
          business: rec.business,
          score: hybridScore,
          reason: _generateReason(hybridScore, RecommendationType.hybrid),
          data: rec.data,
          createdAt: rec.createdAt,
        );
      }).toList();

      hybridRecs.sort((a, b) => b.score.compareTo(a.score));
      return hybridRecs.take(limit).toList();
    } catch (e) {
      print('Error generating hybrid recommendations: $e');
      return [];
    }
  }

  // Métodos de cálculo de score
  double _calculateContentBasedScore(UserProfile profile, business_model.Business business) {
    double score = 0.0;
    
    // Preferencia de categoría
    for (final category in business.categories) {
      score += profile.categoryPreferences[category] ?? 0.0;
    }
    
    // Preferencia de negocio
    score += profile.businessPreferences[business.id] ?? 0.0;
    
    // Calificación
    score += business.rating / 5.0 * 0.3;
    
    // Popularidad
    score += business.reviewCount / 100.0 * 0.2;
    
    return math.min(score, 1.0);
  }

  double _calculateCollaborativeScore(UserProfile profile, business_model.Business business) {
    double score = 0.0;
    
    // Similitud de usuarios
    score += profile.businessPreferences[business.id] ?? 0.0;
    
    // Calificación
    score += business.rating / 5.0 * 0.4;
    
    // Popularidad
    score += business.reviewCount / 100.0 * 0.3;
    
    return math.min(score, 1.0);
  }

  double _calculateTimeBasedScore(UserProfile profile, business_model.Business business, int currentHour) {
    double score = 0.0;
    
    // Hora del día
    if (currentHour >= 12 && currentHour <= 14) {
      score += 0.3; // Hora del almuerzo
    }
    
    // Negocio abierto
    score += business.isOpenNow ? 0.3 : 0.0;
    
    // Tiempo de entrega
    if (business.averageDeliveryTime != null) {
      score += (1.0 - (business.averageDeliveryTime! / 60.0)) * 0.2;
    }
    
    return math.min(score, 1.0);
  }

  double _calculateLocationBasedScore(UserProfile profile, business_model.Business business, double distance) {
    double score = 0.0;
    
    // Distancia
    score += math.max(0, 1.0 - (distance / 10.0)) * 0.5;
    
    // Calificación
    score += business.rating / 5.0 * 0.3;
    
    return math.min(score, 1.0);
  }

  double _calculateHybridScore(UserProfile profile, Recommendation rec) {
    double score = rec.score;
    
    // Ajustar según preferencias del usuario
    if (profile.favoriteCategories.contains(rec.business.categories.first)) {
      score += 0.2;
    }
    
    // Ajustar según hora del día
    final currentHour = DateTime.now().hour;
    if (currentHour >= 12 && currentHour <= 14) {
      score += 0.1;
    }
    
    return math.min(score, 1.0);
  }

  // Métodos auxiliares
  String _generateReason(double score, RecommendationType type) {
    switch (type) {
      case RecommendationType.content_based:
        return 'Basado en tus preferencias anteriores';
      case RecommendationType.collaborative:
        return 'Usuarios similares también disfrutan este lugar';
      case RecommendationType.time_based:
        return 'Perfecto para esta hora del día';
      case RecommendationType.location_based:
        return 'Cerca de tu ubicación actual';
      case RecommendationType.hybrid:
        return 'Recomendación personalizada para ti';
    }
  }

  Future<List<business_model.Business>> _getBusinesses() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => business_model.Business.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      print('Error getting businesses: $e');
      return [];
    }
  }

  Future<List<business_model.Business>> _getBusinessesByCategories(List<String> categories) async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('categories', arrayContainsAny: categories)
          .get();
      
      return snapshot.docs
          .map((doc) => business_model.Business.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      print('Error getting businesses by categories: $e');
      return [];
    }
  }

  Future<List<business_model.Business>> _getOpenBusinesses() async {
    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('isOpenNow', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => business_model.Business.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          ))
          .toList();
    } catch (e) {
      print('Error getting open businesses: $e');
      return [];
    }
  }

  Future<business_model.Business?> _getBusiness(String businessId) async {
    try {
      final doc = await _firestore.collection('businesses').doc(businessId).get();
      if (doc.exists) {
        return business_model.Business.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting business: $e');
      return null;
    }
  }

  Future<List<String>> _getUserFavoriteBusinesses(String userId) async {
    try {
      final profileDoc = await _firestore.collection('user_profiles').doc(userId).get();
      if (profileDoc.exists) {
        final profile = UserProfile.fromMap(profileDoc.data()!);
        return profile.favoriteBusinesses;
      }
      return [];
    } catch (e) {
      print('Error getting user favorite businesses: $e');
      return [];
    }
  }

  Future<List<String>> _findSimilarUsers(String userId, UserProfile profile) async {
    try {
      final snapshot = await _firestore
          .collection('user_profiles')
          .where('userId', isNotEqualTo: userId)
          .limit(10)
          .get();
      
      final similarUsers = <String>[];
      for (final doc in snapshot.docs) {
        final otherProfile = UserProfile.fromMap(doc.data());
        final similarity = _calculateUserSimilarity(profile, otherProfile);
        if (similarity > 0.5) {
          similarUsers.add(otherProfile.userId);
        }
      }
      
      return similarUsers;
    } catch (e) {
      print('Error finding similar users: $e');
      return [];
    }
  }

  double _calculateUserSimilarity(UserProfile profile1, UserProfile profile2) {
    double similarity = 0.0;
    
    // Similitud de categorías
    final categories1 = profile1.favoriteCategories.toSet();
    final categories2 = profile2.favoriteCategories.toSet();
    final categoryIntersection = categories1.intersection(categories2);
    final categoryUnion = categories1.union(categories2);
    similarity += categoryIntersection.length / categoryUnion.length * 0.4;
    
    // Similitud de negocios
    final businesses1 = profile1.favoriteBusinesses.toSet();
    final businesses2 = profile2.favoriteBusinesses.toSet();
    final businessIntersection = businesses1.intersection(businesses2);
    final businessUnion = businesses1.union(businesses2);
    similarity += businessIntersection.length / businessUnion.length * 0.3;
    
    // Similitud de preferencias de tiempo
    final timePrefs1 = profile1.timePreferences.keys;
    final timePrefs2 = profile2.timePreferences.keys;
    final timeIntersection = timePrefs1.toSet().intersection(timePrefs2.toSet());
    final timeUnion = timePrefs1.toSet().union(timePrefs2.toSet());
    similarity += timeIntersection.length / timeUnion.length * 0.3;
    
    return similarity;
  }

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

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) * 
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}
