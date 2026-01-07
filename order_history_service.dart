// ============================================================================
// services/order_history_service.dart - Servicio Mejorado de Historial de Pedidos
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_history_model.dart';
import '../models/order_model.dart' as base_order;
import '../services/cart_service.dart';
import '../services/auth_service.dart';

class OrderHistoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CartService _cartService = CartService();

  // Obtener historial completo de pedidos
  Stream<List<OrderHistoryItem>> getOrderHistory({
    OrderStatus? statusFilter,
    String? businessIdFilter,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    Query query = _firestore
        .collection('order_history')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    // Aplicar filtros
    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.value);
    }
    if (businessIdFilter != null) {
      query = query.where('businessId', isEqualTo: businessIdFilter);
    }
    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => OrderHistoryItem.fromFirestore(doc))
          .toList();
    });
  }

  // Obtener pedidos activos
  Stream<List<OrderHistoryItem>> getActiveOrders() {
    return getOrderHistory(
      statusFilter: null, // Se filtrará en el query
    ).map((orders) {
      return orders.where((order) => order.isActive).toList();
    });
  }

  // Obtener pedidos favoritos
  Stream<List<OrderHistoryItem>> getFavoriteOrders() {
    return getOrderHistory().map((orders) {
      return orders.where((order) => order.isFavorite).toList();
    });
  }

  // Obtener pedidos frecuentes (reordenados)
  Stream<List<OrderHistoryItem>> getFrequentOrders({int minReorderCount = 2}) {
    return getOrderHistory().map((orders) {
      return orders
          .where((order) => order.reorderCount >= minReorderCount)
          .toList();
    });
  }

  // Obtener estadísticas del historial
  Future<OrderHistoryStats> getOrderHistoryStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return OrderHistoryStats.empty();

    try {
      final snapshot = await _firestore
          .collection('order_history')
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderHistoryItem.fromFirestore(doc))
          .toList();

      return OrderHistoryStats.fromOrders(orders);
    } catch (e) {
      print('Error obteniendo estadísticas: $e');
      return OrderHistoryStats.empty();
    }
  }

  // Marcar pedido como favorito
  Future<bool> toggleFavorite(String orderId) async {
    try {
      final orderDoc = _firestore.collection('order_history').doc(orderId);
      final orderSnapshot = await orderDoc.get();

      if (!orderSnapshot.exists) return false;

      final order = OrderHistoryItem.fromFirestore(orderSnapshot);
      final newFavoriteStatus = !order.isFavorite;

      await orderDoc.update({
        'isFavorite': newFavoriteStatus,
        'updatedAt': Timestamp.now(),
      });

      return true;
    } catch (e) {
      print('Error toggling favorite: $e');
      return false;
    }
  }

  // Reordenar pedido
  Future<Map<String, dynamic>> reorderOrder(String orderId) async {
    try {
      final orderDoc = _firestore.collection('order_history').doc(orderId);
      final orderSnapshot = await orderDoc.get();

      if (!orderSnapshot.exists) {
        return {
          'success': false,
          'message': 'Pedido no encontrado',
        };
      }

      final order = OrderHistoryItem.fromFirestore(orderSnapshot);

      if (!order.canReorder) {
        return {
          'success': false,
          'message': 'Este pedido no se puede reordenar',
        };
      }

      // Verificar disponibilidad de productos
      final unavailableItems = <String>[];
      final availableItems = <OrderHistoryItemDetail>[];

      for (final item in order.items) {
        // Aquí deberíamos verificar si el producto todavía está disponible
        // Por ahora, asumimos que todos están disponibles
        if (item.isAvailable) {
          availableItems.add(item);
        } else {
          unavailableItems.add(item.productName);
        }
      }

      if (availableItems.isEmpty) {
        return {
          'success': false,
          'message': 'Ninguno de los productos está disponible actualmente',
        };
      }

      // Limpiar carrito actual
      await _cartService.clearCart();

      // Agregar items disponibles al carrito
      final cartItems = <String, int>{};
      for (final item in availableItems) {
        cartItems[item.productId] = (cartItems[item.productId] ?? 0) + item.quantity;
      }

      // Guardar en el carrito usando el método existente
      await _cartService.saveCart(
        businessId: order.businessId,
        businessName: order.businessName,
        cart: cartItems,
      );

      // Incrementar contador de reordenes
      await orderDoc.update({
        'reorderCount': FieldValue.increment(1),
        'updatedAt': Timestamp.now(),
      });

      final message = unavailableItems.isEmpty
          ? 'Todos los productos se agregaron al carrito'
          : 'Se agregaron ${availableItems.length} productos al carrito. Los siguientes no están disponibles: ${unavailableItems.join(', ')}';

      return {
        'success': true,
        'message': message,
        'addedItems': availableItems.length,
        'unavailableItems': unavailableItems,
        'businessId': order.businessId,
        'businessName': order.businessName,
      };
    } catch (e) {
      print('Error reordering: $e');
      return {
        'success': false,
        'message': 'Error al reordenar: $e',
      };
    }
  }

  // Buscar pedidos por texto
  Future<List<OrderHistoryItem>> searchOrders(String query) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('order_history')
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderHistoryItem.fromFirestore(doc))
          .toList();

      // Filtrar por texto (búsqueda en nombre de negocio y productos)
      final filteredOrders = orders.where((order) {
        final searchLower = query.toLowerCase();
        
        // Buscar en nombre de negocio
        if (order.businessName.toLowerCase().contains(searchLower)) {
          return true;
        }

        // Buscar en nombres de productos
        return order.items.any((item) =>
            item.productName.toLowerCase().contains(searchLower));
      }).toList();

      return filteredOrders;
    } catch (e) {
      print('Error searching orders: $e');
      return [];
    }
  }

  // Obtener resumen mensual de gastos
  Future<List<MonthlySpending>> getMonthlySpending({int months = 12}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final startDate = DateTime.now().subtract(Duration(days: 30 * months));
      
      final snapshot = await _firestore
          .collection('order_history')
          .where('userId', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderHistoryItem.fromFirestore(doc))
          .where((order) => order.isCompleted)
          .toList();

      // Agrupar por mes
      final monthlyData = <String, List<OrderHistoryItem>>{};
      
      for (final order in orders) {
        final monthKey = '${order.createdAt.year}-${order.createdAt.month.toString().padLeft(2, '0')}';
        monthlyData.putIfAbsent(monthKey, () => []).add(order);
      }

      // Convertir a MonthlySpending
      final monthlySpending = monthlyData.entries.map((entry) {
        final orders = entry.value;
        final totalSpent = orders.fold(0.0, (sum, order) => sum + order.total);
        final orderCount = orders.length;
        
        return MonthlySpending(
          month: entry.key,
          totalSpent: totalSpent,
          orderCount: orderCount,
          averageOrderValue: orderCount > 0 ? totalSpent / orderCount : 0.0,
        );
      }).toList();

      // Ordenar por mes (más reciente primero)
      monthlySpending.sort((a, b) => b.month.compareTo(a.month));

      return monthlySpending;
    } catch (e) {
      print('Error getting monthly spending: $e');
      return [];
    }
  }

  // Obtener negocios más frecuentes
  Future<List<FrequentBusiness>> getFrequentBusinesses({int limit = 10}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('order_history')
          .where('userId', isEqualTo: userId)
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderHistoryItem.fromFirestore(doc))
          .where((order) => order.isCompleted)
          .toList();

      // Agrupar por negocio
      final businessData = <String, List<OrderHistoryItem>>{};
      
      for (final order in orders) {
        businessData.putIfAbsent(order.businessId, () => []).add(order);
      }

      // Convertir a FrequentBusiness
      final frequentBusinesses = businessData.entries.map((entry) {
        final orders = entry.value;
        final totalSpent = orders.fold(0.0, (sum, order) => sum + order.total);
        final orderCount = orders.length;
        final lastOrder = orders.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
        
        return FrequentBusiness(
          businessId: entry.key,
          businessName: orders.first.businessName,
          businessImage: orders.first.businessImage,
          orderCount: orderCount,
          totalSpent: totalSpent,
          averageOrderValue: orderCount > 0 ? totalSpent / orderCount : 0.0,
          lastOrderDate: lastOrder.createdAt,
        );
      }).toList();

      // Ordenar por frecuencia (más pedidos primero)
      frequentBusinesses.sort((a, b) => b.orderCount.compareTo(a.orderCount));

      return frequentBusinesses.take(limit).toList();
    } catch (e) {
      print('Error getting frequent businesses: $e');
      return [];
    }
  }

  // Migrar pedidos antiguos al nuevo formato
  Future<void> migrateOldOrders() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      // Obtener pedidos del formato antiguo
      final oldOrdersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in oldOrdersSnapshot.docs) {
        final oldData = doc.data();
        
        // Verificar si ya fue migrado
        final existingHistory = await _firestore
            .collection('order_history')
            .doc(doc.id)
            .get();

        if (existingHistory.exists) continue;

        // Convertir al nuevo formato
        final newOrderData = _convertOldOrderToNew(oldData);
        
        // Guardar en el nuevo formato
        await _firestore
            .collection('order_history')
            .doc(doc.id)
            .set(newOrderData);
      }
    } catch (e) {
      print('Error migrating orders: $e');
    }
  }

  // Convertir pedido antiguo a nuevo formato
  Map<String, dynamic> _convertOldOrderToNew(Map<String, dynamic> oldData) {
    // Convertir items
    final oldItems = oldData['items'] as List<dynamic>? ?? [];
    final newItems = oldItems.map((item) {
      return {
        'productId': item['productId'] ?? '',
        'productName': item['productName'] ?? '',
        'productImage': item['productImage'] ?? '',
        'productDescription': item['productDescription'],
        'quantity': item['quantity'] ?? 0,
        'price': item['price'] ?? 0.0,
        'totalPrice': item['totalPrice'] ?? 0.0,
        'options': item['options'] ?? [],
        'extras': item['extras'] ?? [],
        'specialInstructions': item['specialInstructions'],
        'isAvailable': true, // Asumir disponible para migración
        'category': item['category'],
      };
    }).toList();

    return {
      ...oldData,
      'items': newItems,
      'businessImage': oldData['businessImage'] ?? '',
      'deliveredAt': oldData['deliveredAt'],
      'trackingUrl': oldData['trackingUrl'],
      'driverName': oldData['driverName'],
      'driverPhone': oldData['driverPhone'],
      'driverPhoto': oldData['driverPhoto'],
      'estimatedDeliveryMinutes': oldData['estimatedDeliveryMinutes'],
      'rating': oldData['rating'],
      'isFavorite': false,
      'reorderCount': 0,
      'tags': oldData['tags'] ?? [],
      'metadata': oldData['metadata'] ?? {},
    };
  }
}

// Modelo para estadísticas del historial
class OrderHistoryStats {
  final int totalOrders;
  final int completedOrders;
  final int cancelledOrders;
  final double totalSpent;
  final double averageOrderValue;
  final String mostOrderedBusiness;
  final DateTime? lastOrderDate;
  final int favoriteOrders;

  OrderHistoryStats({
    required this.totalOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.totalSpent,
    required this.averageOrderValue,
    required this.mostOrderedBusiness,
    this.lastOrderDate,
    required this.favoriteOrders,
  });

  factory OrderHistoryStats.fromOrders(List<OrderHistoryItem> orders) {
    final totalOrders = orders.length;
    final completedOrders = orders.where((o) => o.isCompleted).length;
    final cancelledOrders = orders.where((o) => o.isCancelled).length;
    final totalSpent = orders.fold(0.0, (sum, order) => sum + order.total);
    final averageOrderValue = completedOrders > 0 ? totalSpent / completedOrders : 0.0;
    
    // Negocio más pedido
    final businessCounts = <String, int>{};
    for (final order in orders) {
      businessCounts[order.businessName] = (businessCounts[order.businessName] ?? 0) + 1;
    }
    final mostOrderedBusiness = businessCounts.entries.isNotEmpty
        ? businessCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'Ninguno';
    
    final lastOrderDate = orders.isNotEmpty ? orders.first.createdAt : null;
    final favoriteOrders = orders.where((o) => o.isFavorite).length;

    return OrderHistoryStats(
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      cancelledOrders: cancelledOrders,
      totalSpent: totalSpent,
      averageOrderValue: averageOrderValue,
      mostOrderedBusiness: mostOrderedBusiness,
      lastOrderDate: lastOrderDate,
      favoriteOrders: favoriteOrders,
    );
  }

  factory OrderHistoryStats.empty() {
    return OrderHistoryStats(
      totalOrders: 0,
      completedOrders: 0,
      cancelledOrders: 0,
      totalSpent: 0.0,
      averageOrderValue: 0.0,
      mostOrderedBusiness: 'Ninguno',
      favoriteOrders: 0,
    );
  }

  // Obtener porcentaje de completados
  double get completionRate {
    return totalOrders > 0 ? (completedOrders / totalOrders) * 100 : 0.0;
  }

  // Obtener total formateado
  String get formattedTotalSpent {
    return '\$${totalSpent.toStringAsFixed(2)}';
  }

  // Obtener promedio formateado
  String get formattedAverageOrderValue {
    return '\$${averageOrderValue.toStringAsFixed(2)}';
  }
}

// Modelo para gastos mensuales
class MonthlySpending {
  final String month;
  final double totalSpent;
  final int orderCount;
  final double averageOrderValue;

  MonthlySpending({
    required this.month,
    required this.totalSpent,
    required this.orderCount,
    required this.averageOrderValue,
  });

  // Obtener nombre del mes formateado
  String get formattedMonth {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    
    final year = parts[0];
    final monthNum = int.parse(parts[1]);
    
    const monthNames = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    
    return '${monthNames[monthNum - 1]} $year';
  }

  // Obtener total formateado
  String get formattedTotalSpent {
    return '\$${totalSpent.toStringAsFixed(2)}';
  }
}

// Modelo para negocios frecuentes
class FrequentBusiness {
  final String businessId;
  final String businessName;
  final String businessImage;
  final int orderCount;
  final double totalSpent;
  final double averageOrderValue;
  final DateTime lastOrderDate;

  FrequentBusiness({
    required this.businessId,
    required this.businessName,
    this.businessImage = '',
    required this.orderCount,
    required this.totalSpent,
    required this.averageOrderValue,
    required this.lastOrderDate,
  });

  // Obtener fecha formateada
  String get formattedLastOrderDate {
    final now = DateTime.now();
    final difference = now.difference(lastOrderDate);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else {
      return 'Hoy';
    }
  }

  // Obtener total formateado
  String get formattedTotalSpent {
    return '\$${totalSpent.toStringAsFixed(2)}';
  }
}
