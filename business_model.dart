// ============================================================================
// models/business_model.dart - Modelo de Negocios
// ============================================================================

import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> categories; // Múltiples categorías
  final String imageUrl;
  final String logoUrl;
  final String? logo; // Logo adicional para compatibilidad
  final String address;
  final String city;
  final String province;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? location; // Ubicación para compatibilidad
  final double rating;
  final int reviewCount;
  final String phone;
  final String email;
  final String website;
  final List<String> operatingHours;
  final double deliveryFee;
  final int minDeliveryTime;
  final int maxDeliveryTime;
  final bool freeDelivery;
  final double minOrderAmount;
  final List<String> paymentMethods;
  final bool isActive;
  final bool isFeatured;
  final List<String> tags; // Tags para búsqueda avanzada
  final double averagePrice; // Precio promedio ($, $$, $$$)
  final double? averageOrderValue; // Valor promedio del pedido
  final double? averageDeliveryTime; // Tiempo promedio de entrega en minutos
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool? isOpen; // Estado de apertura para compatibilidad

  Business({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.categories,
    required this.imageUrl,
    required this.logoUrl,
    this.logo,
    required this.address,
    required this.city,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.location,
    required this.rating,
    required this.reviewCount,
    required this.phone,
    required this.email,
    required this.website,
    required this.operatingHours,
    required this.deliveryFee,
    required this.minDeliveryTime,
    required this.maxDeliveryTime,
    required this.freeDelivery,
    required this.minOrderAmount,
    required this.paymentMethods,
    required this.isActive,
    required this.isFeatured,
    required this.tags,
    required this.averagePrice,
    required this.averageOrderValue,
    required this.averageDeliveryTime,
    required this.createdAt,
    this.updatedAt,
    this.isOpen,
  });

  // Crear desde Firestore
  factory Business.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Business.fromMap(data, doc.id);
  }

  // Crear desde Map
  factory Business.fromMap(Map<String, dynamic> map, String id) {
    return Business(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      logo: map['logo'],
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      province: map['province'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      location: map['location'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      website: map['website'] ?? '',
      operatingHours: List<String>.from(map['operatingHours'] ?? []),
      deliveryFee: (map['deliveryFee'] ?? 0.0).toDouble(),
      minDeliveryTime: map['minDeliveryTime'] ?? 0,
      maxDeliveryTime: map['maxDeliveryTime'] ?? 0,
      freeDelivery: map['freeDelivery'] ?? false,
      minOrderAmount: (map['minOrderAmount'] ?? 0.0).toDouble(),
      paymentMethods: List<String>.from(map['paymentMethods'] ?? []),
      isActive: map['isActive'] ?? true,
      isFeatured: map['isFeatured'] ?? false,
      tags: List<String>.from(map['tags'] ?? []),
      averagePrice: (map['averagePrice'] ?? 0).toDouble(),
      averageOrderValue: (map['averageOrderValue'] ?? 0).toDouble(),
      averageDeliveryTime: (map['averageDeliveryTime'] ?? 30).toInt(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
      isOpen: map['isOpen'],
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'categories': categories,
      'imageUrl': imageUrl,
      'logoUrl': logoUrl,
      'logo': logo,
      'address': address,
      'city': city,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'rating': rating,
      'reviewCount': reviewCount,
      'phone': phone,
      'email': email,
      'website': website,
      'operatingHours': operatingHours,
      'deliveryFee': deliveryFee,
      'minDeliveryTime': minDeliveryTime,
      'maxDeliveryTime': maxDeliveryTime,
      'freeDelivery': freeDelivery,
      'minOrderAmount': minOrderAmount,
      'paymentMethods': paymentMethods,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'tags': tags,
      'averagePrice': averagePrice,
      'averageOrderValue': averageOrderValue,
      'averageDeliveryTime': averageDeliveryTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'isOpen': isOpen,
    };
  }

  // Obtener precio como texto ($, $$, $$$)
  String get priceLevel {
    if (averagePrice <= 500) return '\$';
    if (averagePrice <= 1000) return '\$\$';
    return '\$\$\$';
  }

  // Verificar si está abierto ahora
  bool get isOpenNow {
    final now = DateTime.now();
    final currentDay = now.weekday; // 1 = Lunes, 7 = Domingo
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    
    if (currentDay < operatingHours.length) {
      final todayHours = operatingHours[currentDay - 1];
      return todayHours.contains('Abierto') || todayHours.contains(currentTime);
    }
    return false;
  }

  // Obtener distancia desde una ubicación
  double distanceFrom(double userLat, double userLng) {
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(latitude - userLat);
    final double dLng = _toRadians(longitude - userLng);
    
    final double a = 
        (dLat / 2).sin() * (dLat / 2).sin() +
        userLat.cos() * latitude.cos() * 
        (dLng / 2).sin() * (dLng / 2).sin();
    
    final double c = 2 * math.sqrt(a).asin();
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

// Extensiones para facilitar cálculos
extension DoubleExtension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}
