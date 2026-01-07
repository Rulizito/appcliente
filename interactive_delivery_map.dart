import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/delivery_tracking_service.dart';
import '../models/order_model.dart' as order_model;

class InteractiveDeliveryMap extends StatefulWidget {
  final String orderId;
  final order_model.Order order;

  const InteractiveDeliveryMap({
    Key? key,
    required this.orderId,
    required this.order,
  }) : super(key: key);

  @override
  State<InteractiveDeliveryMap> createState() => _InteractiveDeliveryMapState();
}

class _InteractiveDeliveryMapState extends State<InteractiveDeliveryMap>
    with TickerProviderStateMixin {
  final DeliveryTrackingService _trackingService = DeliveryTrackingService();
  
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<GeoPoint> _routePoints = [];
  
  DeliveryLocation? _currentDeliveryLocation;
  DeliveryStatus? _currentDeliveryStatus;
  Duration? _estimatedArrivalTime;
  Timer? _updateTimer;
  
  bool _isLoading = true;
  bool _isFollowingDelivery = true;
  double _currentZoom = 15.0;
  
  late AnimationController _pulseController;
  late AnimationController _routeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _routeAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _routeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _routeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _routeController,
      curve: Curves.easeInOut,
    ));
    
    _initializeTracking();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    _routeController.dispose();
    _trackingService.dispose();
    super.dispose();
  }

  Future<void> _initializeTracking() async {
    try {
      // Obtener ubicación actual del usuario
      final userLocation = await _trackingService.getCurrentUserLocation();
      
      // Inicializar mapa
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Configurar mapa después de que se construya
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setupMap(userLocation);
        });
      }
      
      // Iniciar tracking
      await _trackingService.startTracking(widget.orderId);
      
      // Escuchar actualizaciones
      _listenToTrackingUpdates();
      
      // Iniciar timer de actualizaciones
      _startUpdateTimer();
      
    } catch (e) {
      print('Error initializing tracking: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setupMap(GeoPoint? userLocation) {
    if (_mapController == null) return;
    
    // Calcular bounds del mapa
    final bounds = _calculateMapBounds(userLocation);
    
    // Animar cámara a los bounds
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100.0),
    );
  }

  LatLngBounds _calculateMapBounds(GeoPoint? userLocation) {
    List<LatLng> points = [];
    
    // Agregar ubicación del negocio (si existe)
    if (widget.order.businessLocation != null) {
      points.add(LatLng(
        widget.order.businessLocation!.latitude,
        widget.order.businessLocation!.longitude,
      ));
    }
    
    // Agregar ubicación de entrega
    points.add(LatLng(
      widget.order.deliveryLatitude,
      widget.order.deliveryLongitude,
    ));
    
    // Agregar ubicación actual del repartidor
    if (_currentDeliveryLocation != null) {
      points.add(LatLng(
        _currentDeliveryLocation!.latitude,
        _currentDeliveryLocation!.longitude,
      ));
    }
    
    // Agregar ubicación del usuario
    if (userLocation != null) {
      points.add(LatLng(
        userLocation!.latitude,
        userLocation!.longitude,
      ));
    }
    
    if (points.isEmpty) {
      // Ubicación por defecto
      return LatLngBounds(
        southwest: const LatLng(-34.6037, -58.3816),
        northeast: const LatLng(-34.6037, -58.3816),
      );
    }
    
    // Calcular bounds
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _listenToTrackingUpdates() {
    // Escuchar ubicación del repartidor
    _trackingService.getDeliveryLocationStream(widget.orderId)?.listen((location) {
      if (mounted) {
        setState(() {
          _currentDeliveryLocation = location;
        });
        _updateMarkers();
        _updateRoute();
        _updateEstimatedArrival();
      }
    });

    // Escuchar estado del delivery
    _trackingService.getDeliveryStatusStream(widget.orderId)?.listen((status) {
      if (mounted) {
        setState(() {
          _currentDeliveryStatus = status;
        });
        _updateMarkers();
      }
    });
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _isFollowingDelivery && _currentDeliveryLocation != null) {
        _followDelivery();
      }
    });
  }

  void _followDelivery() {
    if (_mapController == null || _currentDeliveryLocation == null) return;
    
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentDeliveryLocation!.latitude,
            _currentDeliveryLocation!.longitude,
          ),
          zoom: _currentZoom,
        ),
      ),
    );
  }

  Future<void> _updateMarkers() async {
    final Set<Marker> newMarkers = {};
    
    // Marcador del negocio
    if (widget.order.businessLocation != null) {
      final businessInfo = await _getAddressFromLatLng(
        widget.order.businessLocation!.latitude,
        widget.order.businessLocation!.longitude,
      );
      
      newMarkers.add(
        Marker(
          markerId: const MarkerId('business'),
          position: LatLng(
            widget.order.businessLocation!.latitude,
            widget.order.businessLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: widget.order.businessName,
            snippet: businessInfo ?? 'Origen del pedido',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }
    
    // Marcador del repartidor (animado)
    if (_currentDeliveryLocation != null && 
        _currentDeliveryStatus?.status != 'delivered') {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('delivery'),
          position: LatLng(
            _currentDeliveryLocation!.latitude,
            _currentDeliveryLocation!.longitude,
          ),
          infoWindow: InfoWindow(
            title: 'Repartidor en camino',
            snippet: 'Velocidad: ${(_currentDeliveryLocation!.speed * 3.6).toStringAsFixed(1)} km/h',
          ),
          icon: await _getDeliveryMarkerIcon(),
          rotation: _currentDeliveryLocation!.heading,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    
    // Marcador de destino
    newMarkers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(
          widget.order.deliveryLatitude,
          widget.order.deliveryLongitude,
        ),
        infoWindow: InfoWindow(
          title: 'Dirección de entrega',
          snippet: widget.order.deliveryAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
      ),
    );
    
    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Future<BitmapDescriptor> _getDeliveryMarkerIcon() async {
    return BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/delivery_marker.png',
    );
  }

  Future<void> _updateRoute() async {
    if (_currentDeliveryLocation == null) return;
    
    try {
      final route = await _trackingService.getOptimizedRoute(
        GeoPoint(
          _currentDeliveryLocation!.latitude,
          _currentDeliveryLocation!.longitude,
        ),
        GeoPoint(
          widget.order.deliveryLatitude,
          widget.order.deliveryLongitude,
        ),
      );
      
      if (mounted) {
        setState(() {
          _routePoints = route;
        });
        _updatePolylines();
      }
    } catch (e) {
      print('Error updating route: $e');
    }
  }

  void _updatePolylines() {
    if (_routePoints.length < 2) return;
    
    final polylinePoints = _routePoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      color: Colors.red,
      width: 4,
      points: polylinePoints,
      patterns: [PatternItem.dash(10, 5)],
    );
    
    setState(() {
      _polylines = {polyline};
    });
  }

  void _updateEstimatedArrival() {
    if (_currentDeliveryLocation == null) return;
    
    final arrivalTime = _trackingService.calculateEstimatedArrivalTime(
      _currentDeliveryLocation!,
      GeoPoint(
        widget.order.deliveryLatitude,
        widget.order.deliveryLongitude,
      ),
      _currentDeliveryLocation!.speed,
    );
    
    setState(() {
      _estimatedArrivalTime = arrivalTime;
    });
  }

  Future<String?> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    return null;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _setupMap(null);
  }

  void _toggleFollowDelivery() {
    setState(() {
      _isFollowingDelivery = !_isFollowingDelivery;
    });
    
    if (_isFollowingDelivery) {
      _followDelivery();
    }
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(2.0, 20.0);
    _mapController?.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(2.0, 20.0);
    _mapController?.animateCamera(
      CameraUpdate.zoomTo(_currentZoom),
    );
  }

  void _centerOnDelivery() {
    if (_currentDeliveryLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            _currentDeliveryLocation!.latitude,
            _currentDeliveryLocation!.longitude,
          ),
        ),
      );
    }
  }

  void _showFullRoute() {
    if (_routePoints.isNotEmpty) {
      final bounds = _calculateMapBounds(null);
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.red),
            )
          : Stack(
              children: [
                // Mapa
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      widget.order.deliveryLatitude,
                      widget.order.deliveryLongitude,
                    ),
                    zoom: _currentZoom,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  trafficEnabled: true,
                ),
                
                // Panel de información superior
                Positioned(
                  top: 50,
                  left: 16,
                  right: 16,
                  child: _buildInfoPanel(),
                ),
                
                // Controles personalizados
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: Column(
                    children: [
                      _buildMapControl(
                        icon: _isFollowingDelivery 
                            ? Icons.gps_fixed 
                            : Icons.gps_not_fixed,
                        onTap: _toggleFollowDelivery,
                        tooltip: _isFollowingDelivery 
                            ? 'Dejar de seguir' 
                            : 'Seguir repartidor',
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.center_focus_strong,
                        onTap: _centerOnDelivery,
                        tooltip: 'Centrar en repartidor',
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.zoom_in,
                        onTap: _zoomIn,
                        tooltip: 'Acercar',
                      ),
                      const SizedBox(height: 8),
                      _buildMapControl(
                        icon: Icons.zoom_out,
                        onTap: _zoomOut,
                        tooltip: 'Alejar',
                      ),
                    ],
                  ),
                ),
                
                // Panel inferior con tiempo estimado
                if (_estimatedArrivalTime != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildArrivalPanel(),
                  ),
              ],
            ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _currentDeliveryStatus?.color ?? Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _currentDeliveryStatus?.icon ?? Icons.help_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentDeliveryStatus?.displayName ?? 'Cargando...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentDeliveryStatus?.description ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_currentDeliveryLocation != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.speed, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${(_currentDeliveryLocation!.speed * 3.6).toStringAsFixed(1)} km/h',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalPanel() {
    final hours = _estimatedArrivalTime!.inHours;
    final minutes = _estimatedArrivalTime!.inMinutes % 60;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.access_time,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tiempo estimado de llegada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '${hours}h ${minutes}min',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
}
