import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'business_detail_screen.dart';
import '../services/location_service.dart';
import '../services/favorites_service.dart';
import 'package:intl/intl.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({Key? key}) : super(key: key);

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final LocationService _locationService = LocationService();
  final FavoritesService _favoritesService = FavoritesService();
  
  List<DocumentSnapshot> _businesses = [];
  List<DocumentSnapshot> _filteredBusinesses = [];
  bool _isLoading = false;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  double _maxDistance = 10.0; // km
  double _minRating = 0.0;
  bool _isFavoriteOnly = false;
  bool _isOpenNow = false;
  String _sortBy = 'distance'; // distance, rating, name
  
  Position? _currentPosition;
  
  final List<String> _categories = [
    'Todos',
    'Restaurantes',
    'Cafeterías',
    'Pizzerías',
    'Hamburguesas',
    'Sushi',
    'Comida Rápida',
    'Comida Saludable',
    'Postres',
    'Bebidas',
  ];

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _currentPosition = position;
      });
      _sortBusinesses();
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  Future<void> _loadBusinesses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .get();

      setState(() {
        _businesses = snapshot.docs;
        _filteredBusinesses = snapshot.docs;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error cargando negocios: $e');
    }
  }

  void _applyFilters() async {
    List<DocumentSnapshot> filtered = List.from(_businesses);

    // Filtro por categoría
    if (_selectedCategory != 'Todos') {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['category'] == _selectedCategory;
      }).toList();
    }

    // Filtro por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['name']?.toString().toLowerCase() ?? '';
        final description = data['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    // Filtro por rating
    if (_minRating > 0) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final rating = (data['rating'] ?? 0.0).toDouble();
        return rating >= _minRating;
      }).toList();
    }

    // Filtro por favoritos
    if (_isFavoriteOnly) {
      List<DocumentSnapshot> favoriteFiltered = [];
      for (var doc in filtered) {
        if (await _favoritesService.isFavoriteSimple(doc.id)) {
          favoriteFiltered.add(doc);
        }
      }
      filtered = favoriteFiltered;
    }

    // Filtro por abierto ahora
    if (_isOpenNow) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return _isBusinessOpen(data);
      }).toList();
    }

    setState(() {
      _filteredBusinesses = filtered;
    });
    _sortBusinesses();
  }

  bool _isBusinessOpen(Map<String, dynamic> businessData) {
    final isOpen = businessData['isOpen'] as bool?;
    return isOpen ?? false;
  }

  void _sortBusinesses() {
    List<DocumentSnapshot> sorted = List.from(_filteredBusinesses);

    switch (_sortBy) {
      case 'distance':
        if (_currentPosition != null) {
          sorted.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final distA = _calculateDistance(dataA);
            final distB = _calculateDistance(dataB);
            return distA.compareTo(distB);
          });
        }
        break;
      case 'rating':
        sorted.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final ratingA = dataB['rating'] ?? 0.0;
          final ratingB = dataA['rating'] ?? 0.0;
          return ratingA.compareTo(ratingB);
        });
        break;
      case 'name':
        sorted.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final nameA = dataA['name']?.toString() ?? '';
          final nameB = dataB['name']?.toString() ?? '';
          return nameA.compareTo(nameB);
        });
        break;
    }

    setState(() {
      _filteredBusinesses = sorted;
    });
  }

  double _calculateDistance(Map<String, dynamic> businessData) {
    if (_currentPosition == null) return double.infinity;
    
    final businessLocation = businessData['location'] as GeoPoint?;
    if (businessLocation == null) return double.infinity;

    const double earthRadius = 6371; // km
    
    final double lat1 = _currentPosition!.latitude;
    final double lon1 = _currentPosition!.longitude;
    final double lat2 = businessLocation.latitude;
    final double lon2 = businessLocation.longitude;

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a = 
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) * math.cos(lat2) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final double c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header con búsqueda
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.red,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red, Colors.red.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                  child: Column(
                    children: [
                      // Barra de búsqueda
                      TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar negocios...',
                          prefixIcon: const Icon(Icons.search, color: Colors.white),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                onPressed: _showFilterDialog,
                tooltip: 'Filtros',
              ),
            ],
          ),

          // Categorías
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCategory = category;
                        });
                        _applyFilters();
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.red.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.red : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Lista de negocios
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_filteredBusinesses.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se encontraron negocios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Intenta ajustar los filtros o busca algo diferente',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildBusinessCard(_filteredBusinesses[index]);
                  },
                  childCount: _filteredBusinesses.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(DocumentSnapshot businessDoc) {
    final businessData = businessDoc.data() as Map<String, dynamic>;
    final businessId = businessDoc.id;
    final name = businessData['name'] ?? 'Negocio';
    final description = businessData['description'] ?? '';
    final category = businessData['category'] ?? 'Categoría';
    final rating = (businessData['rating'] ?? 0.0).toDouble();
    final deliveryTime = businessData['deliveryTime'] ?? '30-45 min';
    final deliveryFee = (businessData['deliveryFee'] ?? 0.0).toDouble();
    final imageUrl = businessData['imageUrl'] ?? '';
    final isOpen = businessData['isOpen'] as bool? ?? false;
    final isFavorite = _favoritesService.isFavoriteSimple(businessId);
    
    final distance = _currentPosition != null 
        ? _calculateDistance(businessData) 
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessDetailScreen(
                businessId: businessId,
                businessName: name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del negocio
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.store,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre y estado
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isOpen ? 'Abierto' : 'Cerrado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Categoría
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Descripción
                  if (description.isNotEmpty)
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Rating, tiempo y distancia
                  Row(
                    children: [
                      // Rating
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Tiempo de entrega
                      Row(
                        children: [
                          const Icon(Icons.schedule, color: Colors.grey, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            deliveryTime,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      if (distance != null) ...[
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.grey, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${distance.toStringAsFixed(1)} km',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Costo de entrega y favorito
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Envío: \$${deliveryFee.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          _favoritesService.toggleFavorite(businessId);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtros de Búsqueda'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ordenar por
                const Text(
                  'Ordenar por:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _sortBy,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text('Distancia')),
                    DropdownMenuItem(value: 'rating', child: Text('Calificación')),
                    DropdownMenuItem(value: 'name', child: Text('Nombre')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _sortBy = value;
                      });
                      _sortBusinesses();
                    }
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Rating mínimo
                Text(
                  'Calificación mínima: ${_minRating.toStringAsFixed(1)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _minRating,
                  min: 0.0,
                  max: 5.0,
                  divisions: 10,
                  onChanged: (value) {
                    setDialogState(() {
                      _minRating = value;
                    });
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Solo favoritos
                CheckboxListTile(
                  title: const Text('Solo favoritos'),
                  value: _isFavoriteOnly,
                  onChanged: (value) {
                    setDialogState(() {
                      _isFavoriteOnly = value ?? false;
                    });
                  },
                ),
                
                // Solo abiertos ahora
                CheckboxListTile(
                  title: const Text('Abiertos ahora'),
                  value: _isOpenNow,
                  onChanged: (value) {
                    setDialogState(() {
                      _isOpenNow = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyFilters();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:math' as math;

extension on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double sqrt() => math.sqrt(this);
  double asin() => math.asin(this);
}
