import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart' as loc;
import '../models/order_model.dart' as order_model;

class DeliveryTrackingService {
  static final DeliveryTrackingService _instance = DeliveryTrackingService._internal();
  factory DeliveryTrackingService() => _instance;
  DeliveryTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final loc.Location _locationService = loc.Location();
  
  StreamSubscription<loc.LocationData>? _locationSubscription;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  
  // Streams para tracking
  Stream<DeliveryLocation>? _deliveryLocationStream;
  Stream<List<DeliveryStep>>? _deliveryStepsStream;
  Stream<DeliveryStatus>? _deliveryStatusStream;

  // Iniciar tracking de un pedido
  Future<void> startTracking(String orderId) async {
    try {
      // Verificar permisos de ubicación
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      // Iniciar suscripción a ubicación del repartidor
      _startLocationTracking(orderId);
      
      // Iniciar suscripción a actualizaciones del pedido
      _startOrderTracking(orderId);
      
    } catch (e) {
      print('Error starting delivery tracking: $e');
    }
  }

  // Detener tracking
  Future<void> stopTracking() async {
    await _locationSubscription?.cancel();
    await _orderSubscription?.cancel();
    _deliveryLocationStream = null;
    _deliveryStepsStream = null;
    _deliveryStatusStream = null;
  }

  // Iniciar tracking de ubicación del repartidor
  void _startLocationTracking(String orderId) {
    _locationSubscription = _locationService.onLocationChanged.listen(
      (loc.LocationData locationData) {
        if (locationData.latitude != null && locationData.longitude != null) {
          _updateDeliveryLocation(orderId, locationData);
        }
      },
      onError: (error) {
        print('Location tracking error: $error');
      },
    );

    _locationSubscription?.resume();
  }

  // Actualizar ubicación del repartidor en Firestore
  Future<void> _updateDeliveryLocation(String orderId, loc.LocationData locationData) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .doc('current_location')
          .set({
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'heading': locationData.heading,
        'speed': locationData.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'orderId': orderId,
      });

      // También actualizar en la colección principal de delivery_locations
      await _firestore
          .collection('delivery_locations')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'latitude': locationData.latitude,
        'longitude': locationData.longitude,
        'accuracy': locationData.accuracy,
        'heading': locationData.heading,
        'speed': locationData.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating delivery location: $e');
    }
  }

  // Iniciar tracking del estado del pedido
  void _startOrderTracking(String orderId) {
    _orderSubscription = _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final orderData = snapshot.data() as Map<String, dynamic>;
        final order = order_model.Order.fromMap(orderData);
        
        // Actualizar streams basados en el estado del pedido
        _updateDeliveryStreams(orderId, order);
      }
    });
  }

  // Actualizar streams de delivery
  void _updateDeliveryStreams(String orderId, order_model.Order order) {
    // Stream de ubicación del repartidor
    _deliveryLocationStream = _firestore
        .collection('delivery_locations')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return DeliveryLocation(
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
          accuracy: data['accuracy']?.toDouble() ?? 0.0,
          heading: data['heading']?.toDouble() ?? 0.0,
          speed: data['speed']?.toDouble() ?? 0.0,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isActive: data['isActive'] ?? false,
        );
      }
      return DeliveryLocation.empty();
    });

    // Stream de pasos del delivery
    _deliveryStepsStream = _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DeliveryStep(
          id: doc.id,
          type: DeliveryStepType.values.firstWhere(
            (type) => type.value == data['type'],
            orElse: () => DeliveryStepType.location_update,
          ),
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          location: data['latitude'] != null
              ? GeoPoint(
                  data['latitude']?.toDouble() ?? 0.0,
                  data['longitude']?.toDouble() ?? 0.0,
                )
              : null,
          metadata: data['metadata'] ?? {},
        );
      }).toList();
    });

    // Stream de estado del delivery
    _deliveryStatusStream = Stream.value(DeliveryStatus.fromOrderStatus(order.status));
  }

  // Obtener stream de ubicación del repartidor
  Stream<DeliveryLocation>? getDeliveryLocationStream(String orderId) {
    return _deliveryLocationStream ??= _firestore
        .collection('delivery_locations')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        return DeliveryLocation(
          latitude: data['latitude']?.toDouble() ?? 0.0,
          longitude: data['longitude']?.toDouble() ?? 0.0,
          accuracy: data['accuracy']?.toDouble() ?? 0.0,
          heading: data['heading']?.toDouble() ?? 0.0,
          speed: data['speed']?.toDouble() ?? 0.0,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          isActive: data['isActive'] ?? false,
        );
      }
      return DeliveryLocation.empty();
    });
  }

  // Obtener stream de pasos del delivery
  Stream<List<DeliveryStep>> getDeliveryStepsStream(String orderId) {
    return _deliveryStepsStream ??= _firestore
        .collection('orders')
        .doc(orderId)
        .collection('tracking')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DeliveryStep(
          id: doc.id,
          type: DeliveryStepType.values.firstWhere(
            (type) => type.value == data['type'],
            orElse: () => DeliveryStepType.location_update,
          ),
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          location: data['latitude'] != null
              ? GeoPoint(
                  data['latitude']?.toDouble() ?? 0.0,
                  data['longitude']?.toDouble() ?? 0.0,
                )
              : null,
          metadata: data['metadata'] ?? {},
        );
      }).toList();
    });
  }

  // Obtener stream de estado del delivery
  Stream<DeliveryStatus> getDeliveryStatusStream(String orderId) {
    return _deliveryStatusStream ??= _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final orderData = snapshot.data() as Map<String, dynamic>;
        final order = order_model.Order.fromMap(orderData);
        return DeliveryStatus.fromOrderStatus(order.status);
      }
      return DeliveryStatus.pending;
    });
  }

  // Calcular distancia entre dos puntos
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radio de la Tierra en km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distancia en km
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Calcular tiempo estimado de llegada
  Duration calculateEstimatedArrivalTime(
    DeliveryLocation currentLocation,
    GeoPoint destination,
    double currentSpeed, // en m/s
  ) {
    if (currentSpeed <= 0) {
      // Si no hay velocidad, estimar basado en distancia promedio
      final distance = calculateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        destination.latitude,
        destination.longitude,
      );
      // Asumir velocidad promedio de 30 km/h en ciudad
      final averageSpeed = 30.0 / 3.6; // Convertir a m/s
      return Duration(seconds: (distance * 1000) ~/ averageSpeed);
    }

    final distance = calculateDistance(
      currentLocation.latitude,
      currentLocation.longitude,
      destination.latitude,
      destination.longitude,
    );

    return Duration(seconds: (distance * 1000) ~/ currentSpeed);
  }

  // Obtener ruta optimizada (simulada)
  Future<List<GeoPoint>> getOptimizedRoute(
    GeoPoint start,
    GeoPoint end,
  ) async {
    try {
      // En producción, esto usaría Google Directions API
      // Por ahora, simulamos una ruta directa con puntos intermedios
      final List<GeoPoint> route = [start];
      
      // Agregar puntos intermedios para simular ruta
      final steps = 5;
      for (int i = 1; i < steps; i++) {
        final double fraction = i / steps;
        final double lat = start.latitude + (end.latitude - start.latitude) * fraction;
        final double lon = start.longitude + (end.longitude - start.longitude) * fraction;
        
        // Agregar variación para simular ruta realista
        final double variation = sin(fraction * pi) * 0.001;
        route.add(GeoPoint(lat + variation, lon));
      }
      
      route.add(end);
      return route;
    } catch (e) {
      print('Error getting optimized route: $e');
      return [start, end];
    }
  }

  // Agregar paso de tracking
  Future<void> addTrackingStep({
    required String orderId,
    required DeliveryStepType type,
    required String title,
    String? description,
    GeoPoint? location,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore
          .collection('orders')
          .doc(orderId)
          .collection('tracking')
          .add({
        'type': type.value,
        'title': title,
        'description': description ?? '',
        'location': location,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding tracking step: $e');
    }
  }

  // Obtener ubicación actual del usuario
  Future<GeoPoint?> getCurrentUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await Geolocator.openLocationSettings();
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Liberar recursos
  void dispose() {
    stopTracking();
  }
}

// Modelos de datos para tracking
class DeliveryLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double heading;
  final double speed;
  final DateTime timestamp;
  final bool isActive;

  const DeliveryLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.heading,
    required this.speed,
    required this.timestamp,
    required this.isActive,
  });

  static DeliveryLocation empty() {
    return const DeliveryLocation(
      latitude: 0.0,
      longitude: 0.0,
      accuracy: 0.0,
      heading: 0.0,
      speed: 0.0,
      timestamp: null,
      isActive: false,
    );
  }
}

class DeliveryStep {
  final String id;
  final DeliveryStepType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final GeoPoint? location;
  final Map<String, dynamic> metadata;

  const DeliveryStep({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.location,
    required this.metadata,
  });
}

enum DeliveryStepType {
  order_confirmed('order_confirmed'),
  preparing('preparing'),
  ready_for_pickup('ready_for_pickup'),
  picked_up('picked_up'),
  on_way('on_way'),
  arriving('arriving'),
  delivered('delivered'),
  location_update('location_update'),
  delay('delay'),
  issue('issue');

  const DeliveryStepType(this.value);
  final String value;
}

class DeliveryStatus {
  final String status;
  final String displayName;
  final String description;
  final Color color;
  final IconData icon;

  const DeliveryStatus({
    required this.status,
    required this.displayName,
    required this.description,
    required this.color,
    required this.icon,
  });

  static DeliveryStatus fromOrderStatus(String orderStatus) {
    switch (orderStatus) {
      case 'pending':
        return const DeliveryStatus(
          status: 'pending',
          displayName: 'Pendiente',
          description: 'Esperando confirmación',
          color: Colors.orange,
          icon: Icons.schedule,
        );
      case 'confirmed':
        return const DeliveryStatus(
          status: 'confirmed',
          displayName: 'Confirmado',
          description: 'Pedido confirmado',
          color: Colors.blue,
          icon: Icons.check_circle_outline,
        );
      case 'preparing':
        return const DeliveryStatus(
          status: 'preparing',
          displayName: 'Preparando',
          description: 'Tu pedido se está preparando',
          color: Colors.purple,
          icon: Icons.restaurant,
        );
      case 'ready_for_pickup':
        return const DeliveryStatus(
          status: 'ready_for_pickup',
          displayName: 'Listo para enviar',
          description: 'Esperando repartidor',
          color: Colors.indigo,
          icon: Icons.shopping_bag,
        );
      case 'on_way':
        return const DeliveryStatus(
          status: 'on_way',
          displayName: 'En camino',
          description: 'El repartidor va hacia ti',
          color: Colors.cyan,
          icon: Icons.delivery_dining,
        );
      case 'delivered':
        return const DeliveryStatus(
          status: 'delivered',
          displayName: 'Entregado',
          description: '¡Pedido entregado!',
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case 'cancelled':
        return const DeliveryStatus(
          status: 'cancelled',
          displayName: 'Cancelado',
          description: 'Pedido cancelado',
          color: Colors.red,
          icon: Icons.cancel,
        );
      default:
        return const DeliveryStatus(
          status: 'unknown',
          displayName: 'Desconocido',
          description: 'Estado desconocido',
          color: Colors.grey,
          icon: Icons.help_outline,
        );
    }
  }
}
