import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productName;
  final int quantity;
  final double price;

  OrderItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'quantity': quantity,
      'price': price,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productName: map['productName'] ?? '',
      quantity: map['quantity'] ?? 0,
      price: (map['price'] ?? 0).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String userId;
  final String userName;
  final String businessId;
  final String businessName;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double tip; // ✅ AGREGADO: Campo para propina
  final double total;
  final String deliveryAddress;
  final String paymentMethod;
  final String? paymentType; // ✅ AGREGADO: Tipo de pago (cash, card, etc.)
  final String status; // 'pending', 'confirmed', 'preparing', 'on_way', 'delivered', 'cancelled'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final GeoPoint? businessLocation; // ✅ AGREGADO: Ubicación del negocio
  final double deliveryLatitude; // ✅ AGREGADO: Latitud de entrega
  final double deliveryLongitude; // ✅ AGREGADO: Longitud de entrega

  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.businessId,
    required this.businessName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    this.tip = 0, // ✅ AGREGADO: Valor por defecto 0
    required this.total,
    required this.deliveryAddress,
    required this.paymentMethod,
    this.paymentType, // AGREGADO: Opcional
    this.status = 'pending',
    this.businessLocation, // AGREGADO: Ubicación del negocio
    this.deliveryLatitude = 0.0, // AGREGADO: Latitud de entrega por defecto
    this.deliveryLongitude = 0.0, // AGREGADO: Longitud de entrega por defecto
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'businessId': businessId,
      'businessName': businessName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'tip': tip, // AGREGADO: Guardar propina
      'total': total,
      'deliveryAddress': deliveryAddress,
      'paymentMethod': paymentMethod,
      'paymentType': paymentType, // AGREGADO: Guardar tipo de pago
      'status': status,
      'businessLocation': businessLocation != null 
          ? {
              'latitude': businessLocation!.latitude,
              'longitude': businessLocation!.longitude,
            }
          : null,
      'deliveryLatitude': deliveryLatitude,
      'deliveryLongitude': deliveryLongitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    try {
      return Order(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? '',
        businessId: map['businessId'] ?? '',
        businessName: map['businessName'] ?? '',
        items: (map['items'] as List<dynamic>?)
            ?.map((item) => OrderItem.fromMap(item as Map<String, dynamic>))
            .toList() ?? [],
        subtotal: (map['subtotal'] ?? 0).toDouble(),
        deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
        tip: (map['tip'] ?? 0).toDouble(), // AGREGADO: Leer propina con valor por defecto
        total: (map['total'] ?? 0).toDouble(),
        deliveryAddress: map['deliveryAddress'] ?? '',
        paymentMethod: map['paymentMethod'] ?? '',
        paymentType: map['paymentType'], // AGREGADO: Leer tipo de pago
        businessLocation: map['businessLocation'] != null 
            ? GeoPoint(
                map['businessLocation']['latitude']?.toDouble() ?? 0.0,
                map['businessLocation']['longitude']?.toDouble() ?? 0.0,
              )
            : null,
        deliveryLatitude: (map['deliveryLatitude'] ?? 0.0).toDouble(),
        deliveryLongitude: (map['deliveryLongitude'] ?? 0.0).toDouble(),
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] != null 
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: map['updatedAt'] != null 
            ? (map['updatedAt'] as Timestamp).toDate() 
            : null,
      );
    } catch (e) {
      print('Error creando Order desde mapa: $e');
      // Retornar un Order por defecto si hay error
      return Order(
        id: map['id'] ?? 'unknown',
        userId: map['userId'] ?? '',
        userName: map['userName'] ?? 'Usuario',
        businessId: map['businessId'] ?? '',
        businessName: map['businessName'] ?? 'Negocio',
        items: [],
        subtotal: 0.0,
        deliveryFee: 0.0,
        tip: 0.0,
        total: 0.0,
        deliveryAddress: '',
        paymentMethod: '',
        paymentType: '', // AGREGADO: Valor por defecto para paymentType
        status: 'pending',
        createdAt: DateTime.now(),
        updatedAt: null,
      );
    }
  }

  String get statusText {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmado';
      case 'preparing':
        return 'Preparando';
      case 'ready_for_pickup':
        return 'Listo para envío';
      case 'on_way':
        return 'En camino';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }
}