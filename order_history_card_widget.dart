// ============================================================================
// widgets/order_history_card_widget.dart - Widget de Tarjeta de Historial de Pedidos
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order_history_model.dart';
import 'package:intl/intl.dart';

class OrderHistoryCard extends StatelessWidget {
  final OrderHistoryItem order;
  final VoidCallback? onReorder;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTap;

  const OrderHistoryCard({
    Key? key,
    required this.order,
    this.onReorder,
    this.onToggleFavorite,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con negocio y fecha
              Row(
                children: [
                  // Logo del negocio
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: order.businessImage.isNotEmpty
                        ? CachedNetworkImageProvider(order.businessImage)
                        : null,
                    child: order.businessImage.isEmpty
                        ? Text(
                            order.businessName.isNotEmpty
                                ? order.businessName[0].toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                    backgroundColor: Colors.grey[400],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.businessName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              order.formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              order.formattedTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Badge de estado
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: order.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: order.statusColor),
                        ),
                        child: Text(
                          order.formattedStatus,
                          style: TextStyle(
                            fontSize: 10,
                            color: order.statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Botón de favorito
                      if (order.isCompleted)
                        GestureDetector(
                          onTap: onToggleFavorite,
                          child: Icon(
                            order.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: order.isFavorite ? Colors.red : Colors.grey[400],
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Items del pedido
              _buildItemsSection(),
              
              const SizedBox(height: 12),
              
              // Información adicional
              Row(
                children: [
                  // Método de pago
                  Icon(
                    _getPaymentIcon(order.paymentMethod),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getPaymentMethodText(order.paymentMethod),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Dirección
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Footer con total y acciones
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        order.formattedTotal,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  
                  // Botón de reordenar
                  if (order.canReorder && onReorder != null)
                    ElevatedButton.icon(
                      onPressed: onReorder,
                      icon: const Icon(Icons.repeat, size: 16),
                      label: const Text('Reordenar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  
                  // Indicador de frecuencia
                  if (order.reorderCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.repeat,
                            color: Colors.blue,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${order.reorderCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // Información del driver (si está en camino)
              if (order.status == OrderStatus.onWay && order.driverName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: order.driverPhoto?.isNotEmpty == true
                            ? CachedNetworkImageProvider(order.driverPhoto!)
                            : null,
                        child: order.driverPhoto?.isEmpty != false
                            ? Text(
                                order.driverName?.isNotEmpty == true
                                    ? order.driverName![0].toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                        backgroundColor: Colors.grey[400],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.driverName!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (order.estimatedDeliveryMinutes != null)
                              Text(
                                'Llega en aproximadamente ${order.estimatedDeliveryMinutes} minutos',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (order.driverPhone != null)
                        IconButton(
                          onPressed: () {
                            // Aquí podríamos implementar llamada al driver
                          },
                          icon: const Icon(Icons.phone, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ],
              
              // Calificación (si está entregado y no calificado)
              if (order.isCompleted && order.rating == null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rate,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '¿Cómo estuvo tu experiencia? Califica este pedido',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange[800],
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navegar a pantalla de calificación
                        },
                        child: const Text('Calificar'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemsSection() {
    final displayItems = order.items.take(3).toList();
    final remainingCount = order.items.length - displayItems.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...displayItems.map((item) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: displayItems.indexOf(item) < displayItems.length - 1 ? 8 : 0,
                  ),
                  child: _buildItemInfo(item),
                ),
              );
            }).toList(),
          ],
        ),
        if (remainingCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            '+$remainingCount ${remainingCount == 1 ? 'producto más' : 'productos más'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemInfo(OrderHistoryItemDetail item) {
    return Row(
      children: [
        // Imagen del producto
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: item.productImage.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: item.productImage,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error, size: 16),
                    ),
                  ),
                )
              : Icon(
                  Icons.fastfood,
                  color: Colors.grey[400],
                  size: 20,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${item.quantity}x ${item.formattedPrice}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getPaymentIcon(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
      case 'efectivo':
        return Icons.money;
      case 'card':
      case 'tarjeta':
        return Icons.credit_card;
      case 'mercadopago':
      case 'mercado pago':
        return Icons.account_balance_wallet;
      case 'transfer':
      case 'transferencia':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodText(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cash':
      case 'efectivo':
        return 'Efectivo';
      case 'card':
      case 'tarjeta':
        return 'Tarjeta';
      case 'mercadopago':
      case 'mercado pago':
        return 'Mercado Pago';
      case 'transfer':
      case 'transferencia':
        return 'Transferencia';
      default:
        return paymentMethod;
    }
  }
}
