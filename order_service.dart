import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener pedidos del usuario
  Stream<QuerySnapshot> getUserOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Obtener pedidos activos
  Stream<QuerySnapshot> getActiveOrders() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();
    
    return _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['pending', 'confirmed', 'ready_for_pickup', 'on_way'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Obtener pedidos recientes
  Future<List<DocumentSnapshot>> getRecentOrders({int limit = 3}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    
    final snapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs;
  }

  // Cancelar pedido
  Future<bool> cancelOrder(String orderId) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .update({'status': 'cancelled'});
      return true;
    } catch (e) {
      print('Error cancelling order: $e');
      return false;
    }
  }
}
