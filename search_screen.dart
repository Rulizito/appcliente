// ============================================================================
// screens/search_screen.dart - VERSIÃ“N MEJORADA CON HISTORIAL PERSISTENTE
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_detail_screen.dart';
import 'dart:async';
import '../services/search_history_service.dart'; // âœ… IMPORTAR EL SERVICIO

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _searchHistoryService = SearchHistoryService(); // âœ… INSTANCIA DEL SERVICIO
  Timer? _debounce;
  
  String _searchQuery = '';
  String _selectedFilter = 'Todos';
  List<String> _searchHistory = []; // Se cargarÃ¡ desde SharedPreferences
  List<String> _popularSearches = []; // Se cargarÃ¡ desde SharedPreferences
  bool _isSearching = false;
  bool _isLoadingHistory = true; // âœ… PARA MOSTRAR LOADING

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // âœ… CARGAR HISTORIAL DESDE SHAREDPREFERENCES
  Future<void> _loadSearchHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final history = await _searchHistoryService.getSearchHistory();
    final popular = await _searchHistoryService.getSearchHistory();

    setState(() {
      _searchHistory = history;
      _popularSearches = popular;
      _isLoadingHistory = false;
    });

    print('ðŸ“± Historial cargado: ${history.length} bÃºsquedas');
  }

  // âœ… GUARDAR BÃšSQUEDA EN SHAREDPREFERENCES
  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    
    await _searchHistoryService.saveSearch(query.trim());
    
    // Recargar historial para actualizar la UI
    final updatedHistory = await _searchHistoryService.getSearchHistory();
    setState(() {
      _searchHistory = updatedHistory;
    });
  }

  // âœ… ELIMINAR BÃšSQUEDA ESPECÃFICA
  Future<void> _removeSearchItem(String query) async {
    await _searchHistoryService.removeSearch(query);
    
    // Recargar historial
    final updatedHistory = await _searchHistoryService.getSearchHistory();
    setState(() {
      _searchHistory = updatedHistory;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('BÃºsqueda eliminada: $query'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // âœ… LIMPIAR TODO EL HISTORIAL
  Future<void> _clearSearchHistory() async {
    // Mostrar diÃ¡logo de confirmaciÃ³n
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text('Â¿QuerÃ©s eliminar todo el historial de bÃºsquedas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Limpiar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _searchHistoryService.clearHistory();
      setState(() {
        _searchHistory = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('âœ… Historial limpiado'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // BÃºsqueda con debounce
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query.trim();
        _isSearching = query.trim().isNotEmpty;
      });
      
      if (query.trim().isNotEmpty) {
        _saveSearchHistory(query.trim()); // âœ… GUARDAR AUTOMÃTICAMENTE
      }
    });
  }

  // âœ… USAR BÃšSQUEDA DEL HISTORIAL
  void _useHistorySearch(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Barra de bÃºsqueda
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red,
              child: Column(
                children: [
                  // Campo de bÃºsqueda
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Buscar restaurantes o productos...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _isSearching = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  // Filtros
                  if (_isSearching) ...[
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Todos'),
                          _buildFilterChip('Restaurantes'),
                          _buildFilterChip('Productos'),
                          _buildFilterChip('Ofertas'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Contenido
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildSearchSuggestions(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        selectedColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        checkmarkColor: Colors.red,
        labelStyle: TextStyle(
          color: isSelected ? Colors.red : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? Colors.red : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // âœ… HISTORIAL DE BÃšSQUEDAS MEJORADO
          if (_searchHistory.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'BÃºsquedas recientes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _clearSearchHistory,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // âœ… MOSTRAR CONTADOR
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${_searchHistory.length} ${_searchHistory.length == 1 ? 'bÃºsqueda' : 'bÃºsquedas'} guardadas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),

            // âœ… LISTA CON OPCIONES DE ELIMINAR INDIVIDUAL
            ..._searchHistory.map((query) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 3,
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    query,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // âœ… BOTÃ“N PARA USAR LA BÃšSQUEDA
                      IconButton(
                        icon: const Icon(Icons.north_west, size: 20),
                        onPressed: () => _useHistorySearch(query),
                        tooltip: 'Usar bÃºsqueda',
                        color: Colors.blue,
                      ),
                      // âœ… BOTÃ“N PARA ELIMINAR INDIVIDUAL
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _removeSearchItem(query),
                        tooltip: 'Eliminar',
                        color: Colors.red,
                      ),
                    ],
                  ),
                  onTap: () => _useHistorySearch(query),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
          ],

          // âœ… MENSAJE SI NO HAY HISTORIAL
          if (_searchHistory.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay bÃºsquedas recientes',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tus bÃºsquedas aparecerÃ¡n aquÃ­',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // CategorÃ­as populares
          const Text(
            'CategorÃ­as populares',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCategoryChip('ðŸ• Pizza', 'Pizza'),
              _buildCategoryChip('ðŸ” Hamburguesas', 'Hamburguesas'),
              _buildCategoryChip('ðŸ£ Sushi', 'Sushi'),
              _buildCategoryChip('ðŸŒ® Tacos', 'Tacos'),
              _buildCategoryChip('ðŸ Pasta', 'Pasta'),
              _buildCategoryChip('ðŸ¥— Ensaladas', 'Ensaladas'),
              _buildCategoryChip('ðŸ° Postres', 'Postres'),
              _buildCategoryChip('â˜• CafÃ©', 'CafÃ©'),
            ],
          ),

          const SizedBox(height: 24),

          // âœ… LO MÃS BUSCADO
          const Text(
            'Lo mÃ¡s buscado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._popularSearches.asMap().entries.map((entry) {
            final index = entry.key;
            final query = entry.value;
            return _buildTrendingSearch((index + 1).toString(), query);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String searchTerm) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ActionChip(
      label: Text(label),
      onPressed: () => _useHistorySearch(searchTerm),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      side: BorderSide(color: Colors.grey[300]!),
    );
  }

  Widget _buildTrendingSearch(String rank, String query) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            rank,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      title: Text(query),
      trailing: const Icon(Icons.trending_up, color: Colors.red),
      onTap: () => _useHistorySearch(query),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('businesses')
          .where('isOpen', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final businesses = snapshot.data?.docs ?? [];
        
        // Filtrar segÃºn el filtro seleccionado
        var filteredResults = businesses;
        if (_selectedFilter != 'Todos') {
          // AquÃ­ puedes agregar lÃ³gica de filtrado adicional
        }

        if (filteredResults.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 100,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No encontramos resultados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IntentÃ¡ con otras palabras clave',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Resultados de negocios
            if (_selectedFilter == 'Todos' || _selectedFilter == 'Restaurantes') ...[
              const Text(
                'Restaurantes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...filteredResults.map((doc) {
                final business = doc.data() as Map<String, dynamic>;
                return _buildBusinessCard(business);
              }).toList(),
            ],

            // AquÃ­ podrÃ­as agregar resultados de productos
            if (_selectedFilter == 'Todos' || _selectedFilter == 'Productos') ...[
              const SizedBox(height: 24),
              const Text(
                'Productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<QuerySnapshot>(
                future: _searchProducts(),
                builder: (context, productSnapshot) {
                  if (productSnapshot.hasData) {
                    final products = productSnapshot.data!.docs;
                    if (products.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      children: products.map((doc) {
                        final product = doc.data() as Map<String, dynamic>;
                        return _buildProductCard(product);
                      }).toList(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Future<QuerySnapshot> _searchProducts() {
    if (_searchQuery.isEmpty) {
      return _firestore
          .collection('products')
          .where('available', isEqualTo: true)
          .limit(10)
          .get();
    }

    final searchLower = _searchQuery.toLowerCase();
    return _firestore
        .collection('products')
        .orderBy('name')
        .startAt([searchLower])
        .endAt(['$searchLower\uf8ff'])
        .limit(10)
        .get();
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BusinessDetailScreen(
              businessId: business['id'],
              businessName: business['name'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.store,
                  size: 40,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(width: 12),
              // InformaciÃ³n
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business['name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business['description'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          business['rating'] != null && business['rating'] > 0
                              ? business['rating'].toStringAsFixed(1)
                              : 'Nuevo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${business['deliveryTime'] ?? 30} min',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.fastfood,
                size: 30,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(width: 12),
            // InformaciÃ³n
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product['description'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Precio
            Text(
              '\$${product['price']}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}