import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class OrderStatisticsScreen extends StatelessWidget {
  const OrderStatisticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Estadísticas'),
        backgroundColor: Colors.red,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getStatistics(user?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }
          
          final stats = snapshot.data ?? {};
          
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                'Total de Pedidos',
                '${stats['totalOrders'] ?? 0}',
                Icons.shopping_bag,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Pedidos Completados',
                '${stats['completedOrders'] ?? 0}',
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Gastado',
                '\$${stats['totalSpent'] ?? 0}',
                Icons.attach_money,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Negocio Favorito',
                stats['favoriteBusiness'] ?? 'Ninguno',
                Icons.favorite,
                Colors.red,
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Future<Map<String, dynamic>> _getStatistics(String userId) async {
    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      
      int totalOrders = ordersSnapshot.docs.length;
      int completedOrders = 0;
      double totalSpent = 0;
      Map<String, int> businessCount = {};
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        
        if (data['status'] == 'delivered') {
          completedOrders++;
          totalSpent += (data['total'] ?? 0).toDouble();
        }
        
        final businessName = data['businessName'] ?? '';
        businessCount[businessName] = (businessCount[businessName] ?? 0) + 1;
      }
      
      String favoriteBusiness = 'Ninguno';
      if (businessCount.isNotEmpty) {
        favoriteBusiness = businessCount.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
      }
      
      return {
        'totalOrders': totalOrders,
        'completedOrders': completedOrders,
        'totalSpent': totalSpent.toInt(),
        'favoriteBusiness': favoriteBusiness,
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {};
    }
  }
}