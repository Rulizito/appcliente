// ============================================================================
// screens/nearby_businesses_screen.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/favorites_service.dart';
import 'business_detail_screen.dart';

class NearbyBusinessesScreen extends StatefulWidget {
  const NearbyBusinessesScreen({Key? key}) : super(key: key);

  @override
  State<NearbyBusinessesScreen> createState() => _NearbyBusinessesScreenState();
}

class _NearbyBusinessesScreenState extends State<NearbyBusinessesScreen> {
  final _locationService = LocationService();
  final _firestore = FirebaseFirestore.instance;
  
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String? _locationError;
  List<BusinessWithDistance> _businesses = [];
  bool _isLoadingBusinesses = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    final position = await _locationService.getCurrentLocation();

    if (position != null) {
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      _loadNearbyBusinesses();
    } else {
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'No se pudo obtener tu ubicación';
      });
    }
  }

  Future<void> _loadNearbyBusinesses() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingBusinesses = true;
    });

    try {
      final snapshot = await _firestore
          .collection('businesses')
          .where('isOpen', isEqualTo: true)
          .get();

      List<BusinessWithDistance> businessesWithDistance = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Por ahora usamos una ubicación simulada
        // En producción, deberías tener lat/lng guardadas en cada negocio
        final businessLat = data['latitude'] ?? -34.6037; // Buenos Aires por defecto
        final businessLng = data['longitude'] ?? -58.3816;

        final distance = _locationService.calculateDistance(
          lat1: _currentPosition!.latitude,
          lon1: _currentPosition!.longitude,
          lat2: businessLat,
          lon2: businessLng,
        );

        businessesWithDistance.add(
          BusinessWithDistance(
            id: data['id'],
            name: data['name'],
            category: data['category'],
            description: data['description'],
            rating: (data['rating'] ?? 0.0).toDouble(),
            deliveryTime: data['deliveryTime'] ?? 30,
            deliveryFee: data['deliveryFee'] ?? 50,
            isOpen: data['isOpen'] ?? false,
            distance: distance,
          ),
        );
      }

      // Ordenar por distancia
      businessesWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

      setState(() {
        _businesses = businessesWithDistance;
        _isLoadingBusinesses = false;
      });
    } catch (e) {
      print('Error al cargar negocios: $e');
      setState(() {
        _isLoadingBusinesses = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Negocios cercanos'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _initializeLocation,
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingLocation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 16),
            const Text('Obteniendo tu ubicación...'),
          ],
        ),
      );
    }

    if (_locationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_off,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                _locationError!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Necesitamos tu ubicación para mostrarte negocios cercanos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final opened = await _locationService.openAppSettings();
                  if (!opened) {
                    _initializeLocation();
                  }
                },
                icon: const Icon(Icons.settings),
                label: const Text('Configurar permisos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _initializeLocation,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingBusinesses) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    if (_businesses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.store_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              const Text(
                'No hay negocios cercanos disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Información de ubicación
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.red.withOpacity(0.1),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tu ubicación actual',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
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
        ),

        // Lista de negocios
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _businesses.length,
            itemBuilder: (context, index) {
              final business = _businesses[index];
              return NearbyBusinessCard(business: business);
            },
          ),
        ),
      ],
    );
  }
}

// Modelo para negocio con distancia
class BusinessWithDistance {
  final String id;
  final String name;
  final String category;
  final String description;
  final double rating;
  final int deliveryTime;
  final int deliveryFee;
  final bool isOpen;
  final double distance;

  BusinessWithDistance({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.rating,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.isOpen,
    required this.distance,
  });
}

// Widget para la tarjeta de negocio cercano
class NearbyBusinessCard extends StatefulWidget {
  final BusinessWithDistance business;

  const NearbyBusinessCard({Key? key, required this.business}) : super(key: key);

  @override
  State<NearbyBusinessCard> createState() => _NearbyBusinessCardState();
}

class _NearbyBusinessCardState extends State<NearbyBusinessCard> {
  final _authService = AuthService();
  final _favoritesService = FavoritesService();
  final _locationService = LocationService();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkIfFavorite();
  }

  Future<void> _checkIfFavorite() async {
    final user = _authService.currentUser;
    if (user != null) {
      final isFav = await _favoritesService.isFavorite(
        userId: user.uid,
        businessId: widget.business.id,
      );
      if (mounted) {
        setState(() {
          _isFavorite = isFav;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iniciá sesión para guardar favoritos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool success;
    if (_isFavorite) {
      success = await _favoritesService.removeFavorite(
        userId: user.uid,
        businessId: widget.business.id,
      );
      if (success && mounted) {
        setState(() => _isFavorite = false);
      }
    } else {
      success = await _favoritesService.addFavorite(
        userId: user.uid,
        businessId: widget.business.id,
        businessName: widget.business.name,
        businessCategory: widget.business.category,
      );
      if (success && mounted) {
        setState(() => _isFavorite = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.business.isOpen
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessDetailScreen(
                    businessId: widget.business.id,
                    businessName: widget.business.name,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Imagen del negocio
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      size: 40,
                      color: Colors.grey[400],
                    ),
                  ),
                  // Badge de distancia
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        _locationService.formatDistance(widget.business.distance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 16),

              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.business.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: widget.business.isOpen ? Colors.black : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.business.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          widget.business.rating > 0
                              ? widget.business.rating.toStringAsFixed(1)
                              : 'Nuevo',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.business.deliveryTime} min',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botón de favorito
              IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}