// ============================================================================
// models/favorite_model.dart
// ============================================================================

class Favorite {
  final String id;
  final String userId;
  final String businessId;
  final String businessName;
  final String businessCategory;
  final DateTime createdAt;

  Favorite({
    required this.id,
    required this.userId,
    required this.businessId,
    required this.businessName,
    required this.businessCategory,
    required this.createdAt,
  });

  // Convertir a Map para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'businessId': businessId,
      'businessName': businessName,
      'businessCategory': businessCategory,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Crear desde Map de Firestore
  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessCategory: map['businessCategory'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}