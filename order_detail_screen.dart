import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart' as order_model;
import '../services/rating_service.dart';
import 'rate_order_screen.dart';

class OrderDetailScreen extends StatelessWidget {
  final order_model.Order? order;
  final String? orderId;

  const OrderDetailScreen({Key? key, this.order, this.orderId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Si tenemos orderId pero no order, cargamos desde Firestore
    if (order == null && orderId != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Pedido #${orderId!.substring(0, 8)}'),
          backgroundColor: Colors.red,
        ),
        body: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
              return const Center(
                child: Text('Error al cargar el pedido'),
              );
            }

            try {
              final orderData = snapshot.data!.data() as Map<String, dynamic>;
              final loadedOrder = order_model.Order.fromMap(orderData);
              return _buildOrderDetail(context, loadedOrder);
            } catch (e) {
              return Center(
                child: Text('Error al procesar el pedido: $e'),
              );
            }
          },
        ),
      );
    }

    // Si tenemos order, lo mostramos directamente
    if (order != null) {
      return _buildOrderDetail(context, order!);
    }

    // Si no tenemos ni order ni orderId
    return const Scaffold(
      body: Center(
        child: Text('No se proporcionó información del pedido'),
      ),
    );
  }

  Widget _buildOrderDetail(BuildContext context, order_model.Order order) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${order.id.substring(0, 8)}'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del pedido
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              color: _getStatusColor(order.status).withOpacity(0.1),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(order.status),
                    size: 80,
                    color: _getStatusColor(order.status),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    order.statusText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(order.status),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusMessage(order.status),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Timeline del pedido
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estado del pedido',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTimelineItem(
                    'Pedido realizado',
                    DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
                    true,
                  ),
                  _buildTimelineItem(
                    'Confirmado',
                    '',
                    _isStatusReached(order.status, 'confirmed'),
                  ),
                  _buildTimelineItem(
                    'Preparando',
                    '',
                    _isStatusReached(order.status, 'preparing'),
                  ),
                  _buildTimelineItem(
                    'En camino',
                    '',
                    _isStatusReached(order.status, 'on_way'),
                  ),
                  _buildTimelineItem(
                    'Entregado',
                    '',
                    _isStatusReached(order.status, 'delivered'),
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Información del negocio
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Negocio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.store,
                          size: 30,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          order.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Productos
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Productos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          Text(
                            '\$${(item.price * item.quantity).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Dirección de entrega
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dirección de entrega',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryAddress,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Resumen del pago
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen del pago',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentRow('Subtotal', '\$${order.subtotal.toStringAsFixed(0)}'),
                  _buildPaymentRow('Envío', '\$${order.deliveryFee.toStringAsFixed(0)}'),
                  if (order.tip > 0)
                    _buildPaymentRow('Propina', '\$${order.tip.toStringAsFixed(0)}'),
                  const Divider(),
                  _buildPaymentRow(
                    'Total',
                    '\$${order.total.toStringAsFixed(0)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Método de pago: ${order.paymentMethod}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Botones de acción
            if (order.status == 'delivered')
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RateOrderScreen(orderId: order.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Calificar pedido',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'preparing':
        return Colors.purple;
      case 'ready_for_pickup':
        return Colors.indigo;
      case 'on_way':
        return Colors.cyan;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'preparing':
        return Icons.restaurant;
      case 'ready_for_pickup':
        return Icons.shopping_bag;
      case 'on_way':
        return Icons.delivery_dining;
      case 'delivered':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'pending':
        return 'Tu pedido está siendo procesado';
      case 'confirmed':
        return 'El negocio ha confirmado tu pedido';
      case 'preparing':
        return 'Tu pedido está siendo preparado';
      case 'ready_for_pickup':
        return 'Tu pedido está listo para ser entregado';
      case 'on_way':
        return 'Tu pedido está en camino';
      case 'delivered':
        return 'Tu pedido ha sido entregado';
      case 'cancelled':
        return 'Tu pedido ha sido cancelado';
      default:
        return 'Estado desconocido';
    }
  }

  bool _isStatusReached(String currentStatus, String targetStatus) {
    final statusOrder = [
      'pending',
      'confirmed',
      'preparing',
      'ready_for_pickup',
      'on_way',
      'delivered'
    ];
    
    final currentIndex = statusOrder.indexOf(currentStatus);
    final targetIndex = statusOrder.indexOf(targetStatus);
    
    return currentIndex >= targetIndex;
  }

  Widget _buildTimelineItem(String title, String time, bool isCompleted, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? Colors.green : Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? Colors.black : Colors.grey[500],
                ),
              ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, String amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
