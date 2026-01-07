// ============================================================================
// models/order_history_model.dart - Modelo Mejorado para Historial de Pedidos
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_model.dart' as base_order;

class OrderHistoryItem {
  final String id;
  final String userId;
  final String userName;
  final String businessId;
  final String businessName;
  final String businessImage;
  final List<OrderHistoryItemDetail> items;
  final double subtotal;
  final double deliveryFee;
  final double tip;
  final double total;
  final String deliveryAddress;
  final String paymentMethod;
  final String? paymentType;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deliveredAt;
  final String? trackingUrl;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final int? estimatedDeliveryMinutes;
  final RatingInfo? rating;
  final bool isFavorite;
  final int reorderCount;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  OrderHistoryItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.businessId,
    required this.businessName,
    this.businessImage = '',
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.tip,
    required this.total,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.paymentType,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.deliveredAt,
    this.trackingUrl,
    this.driverName,
    this.driverPhone,
    this.driverPhoto,
    this.estimatedDeliveryMinutes,
    this.rating,
    this.isFavorite = false,
    this.reorderCount = 0,
    this.tags = const [],
    this.metadata = const {},
  });

  // Crear desde Firestore
  factory OrderHistoryItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderHistoryItem.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory OrderHistoryItem.fromMap(Map<String, dynamic> map, String id) {
    // Convertir items
    final itemsList = (map['items'] as List<dynamic>?)
        ?.map((item) => OrderHistoryItemDetail.fromMap(item as Map<String, dynamic>))
        .toList() ?? [];

    // Convertir rating
    RatingInfo? ratingInfo;
    if (map['rating'] != null) {
      ratingInfo = RatingInfo.fromMap(map['rating'] as Map<String, dynamic>);
    }

    return OrderHistoryItem(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      businessImage: map['businessImage'] ?? '',
      items: itemsList,
      subtotal: (map['subtotal'] ?? 0).toDouble(),
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      tip: (map['tip'] ?? 0).toDouble(),
      total: (map['total'] ?? 0).toDouble(),
      deliveryAddress: map['deliveryAddress'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      paymentType: map['paymentType'],
      status: OrderStatus.fromString(map['status'] ?? 'pending'),
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      deliveredAt: map['deliveredAt'] != null 
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      trackingUrl: map['trackingUrl'],
      driverName: map['driverName'],
      driverPhone: map['driverPhone'],
      driverPhoto: map['driverPhoto'],
      estimatedDeliveryMinutes: map['estimatedDeliveryMinutes'] as int?,
      rating: ratingInfo,
      isFavorite: map['isFavorite'] ?? false,
      reorderCount: map['reorderCount'] ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'businessId': businessId,
      'businessName': businessName,
      'businessImage': businessImage,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'tip': tip,
      'total': total,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'paymentType': paymentType,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'trackingUrl': trackingUrl,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverPhoto': driverPhoto,
      'estimatedDeliveryMinutes': estimatedDeliveryMinutes,
      'rating': rating?.toMap(),
      'isFavorite': isFavorite,
      'reorderCount': reorderCount,
      'tags': tags,
      'metadata': metadata,
    };
  }

  // Verificar si el pedido está activo
  bool get isActive => status == OrderStatus.pending || 
                      status == OrderStatus.confirmed || 
                      status == OrderStatus.preparing || 
                      status == OrderStatus.onWay;

  // Verificar si el pedido está completado
  bool get isCompleted => status == OrderStatus.delivered;

  // Verificar si el pedido fue cancelado
  bool get isCancelled => status == OrderStatus.cancelled;

  // Obtener estado formateado
  String get formattedStatus {
    switch (status) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.preparing:
        return 'Preparando';
      case OrderStatus.onWay:
        return 'En camino';
      case OrderStatus.delivered:
        return 'Entregado';
      case OrderStatus.cancelled:
        return 'Cancelado';
    }
  }

  // Obtener color del estado
  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.onWay:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  // Obtener fecha formateada
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Ayer';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays} días';
      } else {
        return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
      }
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'Ahora';
    }
  }

  // Obtener hora formateada
  String get formattedTime {
    return '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
  }

  // Verificar si se puede reordenar
  bool get canReorder => isCompleted && !isCancelled;

  // Obtener precio total formateado
  String get formattedTotal {
    return '\$${total.toStringAsFixed(2)}';
  }

  // Obtener cantidad total de items
  int get totalItems {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  // Copia con valores actualizados
  OrderHistoryItem copyWith({
    String? id,
    String? userId,
    String? userName,
    String? businessId,
    String? businessName,
    String? businessImage,
    List<OrderHistoryItemDetail>? items,
    double? subtotal,
    double? deliveryFee,
    double? tip,
    double? total,
    String? deliveryAddress,
    String? paymentMethod,
    String? paymentType,
    OrderStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveredAt,
    String? trackingUrl,
    String? driverName,
    String? driverPhone,
    String? driverPhoto,
    int? estimatedDeliveryMinutes,
    RatingInfo? rating,
    bool? isFavorite,
    int? reorderCount,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) {
    return OrderHistoryItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessImage: businessImage ?? this.businessImage,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tip: tip ?? this.tip,
      total: total ?? this.total,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentType: paymentType ?? this.paymentType,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPhoto: driverPhoto ?? this.driverPhoto,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      reorderCount: reorderCount ?? this.reorderCount,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'OrderHistoryItem(id: $id, businessName: $businessName, status: $formattedStatus, total: $formattedTotal)';
  }
}

// Modelo para detalles del item del pedido
class OrderHistoryItemDetail {
  final String productId;
  final String productName;
  final String productImage;
  final String? productDescription;
  final int quantity;
  final double price;
  final double totalPrice;
  final List<String> options;
  final List<String> extras;
  final String? specialInstructions;
  final bool isAvailable;
  final String? category;

  OrderHistoryItemDetail({
    required this.productId,
    required this.productName,
    this.productImage = '',
    this.productDescription,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    this.options = const [],
    this.extras = const [],
    this.specialInstructions,
    this.isAvailable = true,
    this.category,
  });

  factory OrderHistoryItemDetail.fromMap(Map<String, dynamic> map) {
    return OrderHistoryItemDetail(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'] ?? '',
      productDescription: map['productDescription'],
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      options: List<String>.from(map['options'] ?? []),
      extras: List<String>.from(map['extras'] ?? []),
      specialInstructions: map['specialInstructions'],
      isAvailable: map['isAvailable'] ?? true,
      category: map['category'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'productDescription': productDescription,
      'quantity': quantity,
      'price': price,
      'totalPrice': totalPrice,
      'options': options,
      'extras': extras,
      'specialInstructions': specialInstructions,
      'isAvailable': isAvailable,
      'category': category,
    };
  }

  // Obtener precio formateado
  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }

  // Obtener precio total formateado
  String get formattedTotalPrice {
    return '\$${totalPrice.toStringAsFixed(2)}';
  }

  @override
  String toString() {
    return 'OrderHistoryItemDetail(name: $productName, quantity: $quantity, price: $formattedPrice)';
  }
}

// Enum para estados del pedido
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  onWay('on_way'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'on_way':
        return OrderStatus.onWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }
}

// Modelo para información de calificación
class RatingInfo {
  final double rating;
  final String? comment;
  final DateTime? ratedAt;
  final String? reviewId;

  RatingInfo({
    required this.rating,
    this.comment,
    this.ratedAt,
    this.reviewId,
  });

  factory RatingInfo.fromMap(Map<String, dynamic> map) {
    return RatingInfo(
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'],
      ratedAt: map['ratedAt'] != null 
          ? (map['ratedAt'] as Timestamp).toDate()
          : null,
      reviewId: map['reviewId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'comment': comment,
      'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
      'reviewId': reviewId,
    };
  }

  // Obtener calificación formateada
  String get formattedRating {
    return rating.toStringAsFixed(1);
  }

  @override
  String toString() {
    return 'RatingInfo(rating: $formattedRating, comment: $comment)';
  }
}
