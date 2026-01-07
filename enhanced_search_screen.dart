// ============================================================================
// screens/enhanced_search_screen.dart - Búsqueda Mejorada con Filtros Avanzados
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_detail_screen.dart';
import 'advanced_filters_screen.dart';
import '../services/advanced_search_service.dart';
import '../models/business_model.dart';
import '../services/search_history_service.dart';

class EnhancedSearchScreen extends StatefulWidget {
  const EnhancedSearchScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedSearchScreen> createState() => _EnhancedSearchScreenState();
}

class _EnhancedSearchScreenState extends State<EnhancedSearchScreen> {
  final _searchController = TextEditingController();
  final _searchService = AdvancedSearchService();
  final _searchHistoryService = SearchHistoryService();
  
  List<Business> _searchResults = [];
  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  List<String> _categories = [];
  
  bool _isSearching = false;
  bool _isLoading = false;
  bool _showFilters = false;
  
  SearchFilters _filters = SearchFilters();

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    final history = await _searchHistoryService.getSearchHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  Future<void> _loadCategories() async {
    final categories = await _searchService.getAvailableCategories();
    setState(() {
      _categories = categories;
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty && !_hasActiveFilters()) return;

    setState(() {
      _isSearching = true;
      _isLoading = true;
    });

    try {
      _filters.query = query.isEmpty ? null : query;
      
      final results = await _searchService.searchBusinesses(_filters);
      
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });

      if (query.isNotEmpty) {
        await _searchHistoryService.saveSearch(query);
        await _loadSearchHistory();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error en la búsqueda: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    try {
      final suggestions = await _searchService.getSearchSuggestions(query);
      setState(() {
        _suggestions = suggestions;
      });
    } catch (e) {
      print('Error obteniendo sugerencias: $e');
    }
  }

  bool _hasActiveFilters() {
    return _filters.category != null ||
           (_filters.categories != null && _filters.categories!.isNotEmpty) ||
           _filters.minRating != null ||
           _filters.maxPrice != null ||
           _filters.freeDelivery == true ||
           _filters.openNow == true ||
           (_filters.paymentMethods != null && _filters.paymentMethods!.isNotEmpty) ||
           (_filters.tags != null && _filters.tags!.isNotEmpty);
  }

  void _openFilters() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdvancedFiltersScreen(
          initialFilters: _filters,
          onFiltersApplied: (newFilters) {
            setState(() {
              _filters = newFilters;
              _showFilters = _hasActiveFilters();
            });
            _performSearch();
          },
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _filters = SearchFilters();
      _showFilters = false;
    });
    _performSearch();
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _performSearch();
  }

  void _removeSearchItem(String query) async {
    await _searchHistoryService.removeSearch(query);
    await _loadSearchHistory();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Búsqueda eliminada: $query'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar Negocios'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              color: _showFilters ? Colors.white : Colors.white70,
            ),
            onPressed: _openFilters,
          ),
          if (_hasActiveFilters())
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearFilters,
              tooltip: 'Limpiar filtros',
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Campo de búsqueda con sugerencias
                Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar negocios, categorías o productos...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _suggestions = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (value) {
                        setState(() {});
                        _getSuggestions(value);
                      },
                      onSubmitted: (_) => _performSearch(),
                    ),
                    
                    // Sugerencias
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: _suggestions.take(5).map((suggestion) {
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.search, size: 20),
                              title: Text(suggestion),
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Filtros activos
                if (_hasActiveFilters())
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _getFiltersSummary(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpiar'),
                        ),
                      ],
                    ),
                  ),
                
                // Categorías rápidas
                if (!_isSearching && _categories.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Categorías populares',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.take(8).length,
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(category),
                                onSelected: (_) {
                                  setState(() {
                                    _filters.category = category;
                                  });
                                  _performSearch();
                                },
                                backgroundColor: Colors.grey[200],
                                selectedColor: Colors.red.withOpacity(0.2),
                                checkmarkColor: Colors.red,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isSearching
                    ? _buildSearchResults()
                    : _buildSearchSuggestions(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron negocios',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos o ajusta los filtros',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final business = _searchResults[index];
        return _buildBusinessCard(business);
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return Column(
      children: [
        // Historial de búsqueda
        if (_searchHistory.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Búsquedas recientes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _searchHistoryService.clearHistory();
                        await _loadSearchHistory();
                      },
                      child: const Text('Limpiar todo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _searchHistory.take(10).map((query) {
                    return Chip(
                      label: Text(query),
                      onDeleted: () => _removeSearchItem(query),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      backgroundColor: Colors.grey[200],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBusinessCard(Business business) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessDetailScreen(businessId: business.id, businessName: business.name),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Logo/Imagen
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  image: business.logoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(business.logoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: business.logoUrl.isEmpty
                    ? Icon(
                        Icons.store,
                        size: 30,
                        color: Colors.grey[400],
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      business.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Calificación
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              business.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              ' (${business.reviewCount})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Precio
                        Text(
                          business.priceLevel,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Envío
                        if (business.freeDelivery)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Envío gratis',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Estado
              Column(
                children: [
                  if (business.isOpenNow)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Abierto',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Cerrado',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (business.deliveryFee > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '\$${business.deliveryFee.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFiltersSummary() {
    List<String> activeFilters = [];
    
    if (_filters.category != null) {
      activeFilters.add(_filters.category!);
    }
    if (_filters.minRating != null) {
      activeFilters.add('${_filters.minRating!.toStringAsFixed(1)}+ ⭐');
    }
    if (_filters.maxPrice != null) {
      activeFilters.add('Hasta \$${_filters.maxPrice!.toStringAsFixed(0)}');
    }
    if (_filters.freeDelivery == true) {
      activeFilters.add('Envío gratis');
    }
    if (_filters.openNow == true) {
      activeFilters.add('Abierto ahora');
    }
    
    return activeFilters.length > 3
        ? '${activeFilters.take(3).join(', ')} +${activeFilters.length - 3} más'
        : activeFilters.join(', ');
  }
}
