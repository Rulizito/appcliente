import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Búsqueda difusa (tolerante a errores)
  Future<List<Map<String, dynamic>>> searchBusinesses(String query) async {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    
    // Buscar en negocios
    final snapshot = await _firestore
        .collection('businesses')
        .where('isOpen', isEqualTo: true)
        .get();
    
    // Filtrar localmente
    final results = snapshot.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toLowerCase();
      final category = (data['category'] ?? '').toLowerCase();
      final description = (data['description'] ?? '').toLowerCase();
      
      return name.contains(lowerQuery) || 
             category.contains(lowerQuery) ||
             description.contains(lowerQuery);
    }).map((doc) => doc.data()).toList();
    
    return results;
  }
  
  // Búsqueda de productos
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    if (query.isEmpty) return [];
    
    final lowerQuery = query.toLowerCase();
    
    final snapshot = await _firestore
        .collection('products')
        .where('available', isEqualTo: true)
        .get();
    
    final results = snapshot.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toLowerCase();
      final description = (data['description'] ?? '').toLowerCase();
      
      return name.contains(lowerQuery) || 
             description.contains(lowerQuery);
    }).map((doc) => doc.data()).toList();
    
    return results;
  }
}