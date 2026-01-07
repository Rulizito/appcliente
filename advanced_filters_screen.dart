// ============================================================================
// screens/advanced_filters_screen.dart - Pantalla de Filtros Avanzados
// ============================================================================

import 'package:flutter/material.dart';
import '../services/advanced_search_service.dart';
import '../models/business_model.dart';

class AdvancedFiltersScreen extends StatefulWidget {
  final SearchFilters initialFilters;
  final Function(SearchFilters) onFiltersApplied;

  const AdvancedFiltersScreen({
    Key? key,
    required this.initialFilters,
    required this.onFiltersApplied,
  }) : super(key: key);

  @override
  State<AdvancedFiltersScreen> createState() => _AdvancedFiltersScreenState();
}

class _AdvancedFiltersScreenState extends State<AdvancedFiltersScreen> {
  late SearchFilters _filters;
  final _searchService = AdvancedSearchService();
  
  List<String> _categories = [];
  List<String> _paymentMethods = [];
  List<String> _tags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final categories = await _searchService.getAvailableCategories();
      final paymentMethods = await _searchService.getAvailablePaymentMethods();
      final tags = await _searchService.getPopularTags();

      setState(() {
        _categories = categories;
        _paymentMethods = paymentMethods;
        _tags = tags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtros Avanzados'),
        backgroundColor: Colors.red,
        actions: [
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              'Limpiar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Búsqueda por texto
                  _buildSection(
                    title: 'Búsqueda',
                    child: TextField(
                      controller: TextEditingController(text: _filters.query),
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre o descripción',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _filters.query = value.isEmpty ? null : value;
                      },
                      onSubmitted: (_) => _applyFilters(),
                    ),
                  ),

                  // Categorías
                  _buildSection(
                    title: 'Categorías',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _filters.categories?.contains(category) ?? false;
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _filters.categories ??= [];
                              if (selected) {
                                _filters.categories!.add(category);
                              } else {
                                _filters.categories!.remove(category);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.red.withOpacity(0.2),
                          checkmarkColor: Colors.red,
                        );
                      }).toList(),
                    ),
                  ),

                  // Calificación
                  _buildSection(
                    title: 'Calificación mínima',
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _filters.minRating ?? 0,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            label: '${(_filters.minRating ?? 0).toStringAsFixed(1)} ⭐',
                            onChanged: (value) {
                              setState(() {
                                _filters.minRating = value == 0 ? null : value;
                              });
                            },
                          ),
                        ),
                        Text(
                          '${(_filters.minRating ?? 0).toStringAsFixed(1)} ⭐',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  // Rango de precios
                  _buildSection(
                    title: 'Rango de precios',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('\$ (Económico)'),
                                value: 'low',
                                groupValue: _getPriceGroup(),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == 'low') {
                                      _filters.maxPrice = 500;
                                    } else if (value == 'medium') {
                                      _filters.maxPrice = 1000;
                                    } else if (value == 'high') {
                                      _filters.maxPrice = double.infinity;
                                    } else {
                                      _filters.maxPrice = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('\$\$ (Moderado)'),
                                value: 'medium',
                                groupValue: _getPriceGroup(),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == 'low') {
                                      _filters.maxPrice = 500;
                                    } else if (value == 'medium') {
                                      _filters.maxPrice = 1000;
                                    } else if (value == 'high') {
                                      _filters.maxPrice = double.infinity;
                                    } else {
                                      _filters.maxPrice = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('\$\$\$ (Caro)'),
                                value: 'high',
                                groupValue: _getPriceGroup(),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == 'low') {
                                      _filters.maxPrice = 500;
                                    } else if (value == 'medium') {
                                      _filters.maxPrice = 1000;
                                    } else if (value == 'high') {
                                      _filters.maxPrice = double.infinity;
                                    } else {
                                      _filters.maxPrice = null;
                                    }
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Todos'),
                                value: 'all',
                                groupValue: _getPriceGroup(),
                                onChanged: (value) {
                                  setState(() {
                                    _filters.maxPrice = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Envío gratis
                  _buildSection(
                    title: 'Opciones de envío',
                    child: SwitchListTile(
                      title: const Text('Solo envío gratis'),
                      subtitle: const Text('Mostrar negocios con envío sin costo'),
                      value: _filters.freeDelivery ?? false,
                      onChanged: (value) {
                        setState(() {
                          _filters.freeDelivery = value ? true : null;
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ),

                  // Abierto ahora
                  _buildSection(
                    title: 'Disponibilidad',
                    child: SwitchListTile(
                      title: const Text('Abierto ahora'),
                      subtitle: const Text('Mostrar negocios que están abiertos actualmente'),
                      value: _filters.openNow ?? false,
                      onChanged: (value) {
                        setState(() {
                          _filters.openNow = value ? true : null;
                        });
                      },
                      activeColor: Colors.red,
                    ),
                  ),

                  // Métodos de pago
                  _buildSection(
                    title: 'Métodos de pago',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _paymentMethods.map((method) {
                        final isSelected = _filters.paymentMethods?.contains(method) ?? false;
                        return FilterChip(
                          label: Text(_getPaymentMethodName(method)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _filters.paymentMethods ??= [];
                              if (selected) {
                                _filters.paymentMethods!.add(method);
                              } else {
                                _filters.paymentMethods!.remove(method);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.red.withOpacity(0.2),
                          checkmarkColor: Colors.red,
                        );
                      }).toList(),
                    ),
                  ),

                  // Tags populares
                  _buildSection(
                    title: 'Tags populares',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tags.take(15).map((tag) {
                        final isSelected = _filters.tags?.contains(tag) ?? false;
                        return FilterChip(
                          label: Text('#$tag'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _filters.tags ??= [];
                              if (selected) {
                                _filters.tags!.add(tag);
                              } else {
                                _filters.tags!.remove(tag);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.red.withOpacity(0.2),
                          checkmarkColor: Colors.red,
                        );
                      }).toList(),
                    ),
                  ),

                  // Ordenamiento
                  _buildSection(
                    title: 'Ordenar por',
                    child: DropdownButtonFormField<String>(
                      value: _filters.sortBy,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Criterio de ordenamiento',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'rating', child: Text('Calificación')),
                        DropdownMenuItem(value: 'name', child: Text('Nombre')),
                        DropdownMenuItem(value: 'delivery_fee', child: Text('Costo de envío')),
                        DropdownMenuItem(value: 'distance', child: Text('Distancia')),
                        DropdownMenuItem(value: 'review_count', child: Text('Cantidad de reseñas')),
                        DropdownMenuItem(value: 'price', child: Text('Precio promedio')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filters.sortBy = value;
                        });
                      },
                    ),
                  ),

                  // Orden ascendente/descendente
                  if (_filters.sortBy != null)
                    _buildSection(
                      title: 'Orden',
                      child: Row(
                        children: [
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Descendente'),
                              value: false,
                              groupValue: _filters.ascending,
                              onChanged: (value) {
                                setState(() {
                                  _filters.ascending = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<bool>(
                              title: const Text('Ascendente'),
                              value: true,
                              groupValue: _filters.ascending,
                              onChanged: (value) {
                                setState(() {
                                  _filters.ascending = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Botones de acción
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _applyFilters,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Aplicar filtros',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
        const SizedBox(height: 24),
      ],
    );
  }

  String? _getPriceGroup() {
    if (_filters.maxPrice == null) return 'all';
    if (_filters.maxPrice! <= 500) return 'low';
    if (_filters.maxPrice! <= 1000) return 'medium';
    return 'high';
  }

  String _getPaymentMethodName(String method) {
    switch (method.toLowerCase()) {
      case 'cash':
        return 'Efectivo';
      case 'card':
        return 'Tarjeta';
      case 'transfer':
        return 'Transferencia';
      case 'qr':
        return 'QR';
      case 'wallet':
        return 'Billetera digital';
      default:
        return method;
    }
  }

  void _resetFilters() {
    setState(() {
      _filters = SearchFilters();
    });
  }

  void _applyFilters() {
    widget.onFiltersApplied(_filters);
    Navigator.pop(context);
  }
}
