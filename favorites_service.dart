// ============================================================================
// services/favorites_service.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/favorite_model.dart';

class FavoritesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Agregar un negocio a favoritos
  Future<bool> addFavorite({
    required String userId,
    required String businessId,
    required String businessName,
    required String businessCategory,
  }) async {
    try {
      final favoriteId = _firestore.collection('favorites').doc().id;
      
      final favorite = Favorite(
        id: favoriteId,
        userId: userId,
        businessId: businessId,
        businessName: businessName,
        businessCategory: businessCategory,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('favorites')
          .doc(favoriteId)
          .set(favorite.toMap());

      return true;
    } catch (e) {
      print('Error al agregar favorito: $e');
      return false;
    }
  }

  // Eliminar un negocio de favoritos
  Future<bool> removeFavorite({
    required String userId,
    required String businessId,
  }) async {
    try {
      // Buscar el favorito
      final querySnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .where('businessId', isEqualTo: businessId)
          .get();

      // Eliminar todos los documentos encontrados
      for (var doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Error al eliminar favorito: $e');
      return false;
    }
  }

  // Verificar si un negocio está en favoritos
  Future<bool> isFavorite({
    required String userId,
    required String businessId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .where('businessId', isEqualTo: businessId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error al verificar favorito: $e');
      return false;
    }
  }

  // Obtener todos los favoritos de un usuario
  Stream<List<Favorite>> getUserFavorites(String userId) {
    return _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Favorite.fromMap(doc.data()))
          .toList();
    });
  }

  // Obtener cantidad de favoritos de un usuario
  Future<int> getFavoritesCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('favorites')
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.length;
    } catch (e) {
      print('Error al contar favoritos: $e');
      return 0;
    }
  }

  // Métodos simplificados para uso directo
  Future<bool> isFavoriteSimple(String businessId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;
    return isFavorite(userId: userId, businessId: businessId);
  }

  Future<void> toggleFavorite(String businessId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final isFav = await isFavorite(userId: userId, businessId: businessId);
    if (isFav) {
      await removeFavorite(userId: userId, businessId: businessId);
    } else {
      // Obtener datos del negocio para agregar a favoritos
      final businessDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      
      if (businessDoc.exists) {
        final businessData = businessDoc.data() as Map<String, dynamic>;
        await addFavorite(
          userId: userId,
          businessId: businessId,
          businessName: businessData['name'] ?? 'Negocio',
          businessCategory: businessData['category'] ?? 'Categoría',
        );
      }
    }
  }

  Future<List<DocumentSnapshot>> getFavoriteBusinesses() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];
    
    final favoritesSnapshot = await _firestore
        .collection('favorites')
        .where('userId', isEqualTo: userId)
        .get();
    
    List<DocumentSnapshot> businesses = [];
    for (var favoriteDoc in favoritesSnapshot.docs) {
      final favoriteData = favoriteDoc.data() as Map<String, dynamic>;
      final businessId = favoriteData['businessId'] as String;
      
      final businessDoc = await _firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      
      if (businessDoc.exists) {
        businesses.add(businessDoc);
      }
    }
    
    return businesses;
  }
}