// ============================================================================
// screens/order_history_screen.dart - Pantalla Mejorada de Historial de Pedidos
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/order_history_service.dart';
import '../models/order_history_model.dart';
import '../widgets/order_history_card_widget.dart';
import '../widgets/order_stats_widget.dart';
import 'package:intl/intl.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with TickerProviderStateMixin {
  final _orderHistoryService = OrderHistoryService();
  final _searchController = TextEditingController();
  
  late TabController _tabController;
  
  List<OrderHistoryItem> _allOrders = [];
  List<OrderHistoryItem> _filteredOrders = [];
  List<OrderHistoryItem> _activeOrders = [];
  List<OrderHistoryItem> _favoriteOrders = [];
  List<OrderHistoryItem> _frequentOrders = [];
  
  OrderHistoryStats? _stats;
  bool _isLoadingStats = true;
  bool _isSearching = false;
  
  // Filtros
  OrderStatus? _selectedStatus;
  String? _selectedBusiness;
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'date'; // date, total, business, frequency
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    
    // Migrar pedidos antiguos si es necesario
    _orderHistoryService.migrateOldOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStats(),
    ]);
  }

  Future<void> _loadStats() async {
    final stats = await _orderHistoryService.getOrderHistoryStats();
    setState(() {
      _stats = stats;
      _isLoadingStats = false;
    });
  }

  void _applySearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredOrders = _allOrders;
        _isSearching = false;
      });
    } else {
      setState(() {
        _isSearching = true;
      });
      
      _orderHistoryService.searchOrders(query).then((results) {
        setState(() {
          _filteredOrders = results;
        });
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedBusiness = null;
      _startDate = null;
      _endDate = null;
      _sortBy = 'date';
    });
    _applySearch(_searchController.text);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        selectedStatus: _selectedStatus,
        selectedBusiness: _selectedBusiness,
        startDate: _startDate,
        endDate: _endDate,
        sortBy: _sortBy,
        onApply: (status, business, start, end, sort) {
          setState(() {
            _selectedStatus = status;
            _selectedBusiness = business;
            _startDate = start;
            _endDate = end;
            _sortBy = sort;
          });
          _applySearch(_searchController.text);
        },
      ),
    );
  }

  Future<void> _refreshData() async {
    _loadStats();
    _applySearch(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Historial de Pedidos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Todos', icon: Icon(Icons.list)),
            Tab(text: 'Activos', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Favoritos', icon: Icon(Icons.favorite)),
            Tab(text: 'Frecuentes', icon: Icon(Icons.repeat)),
            Tab(text: 'Estadísticas', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
          ),
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          _buildSearchBar(),
          
          // Pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllOrdersTab(),
                _buildActiveOrdersTab(),
                _buildFavoriteOrdersTab(),
                _buildFrequentOrdersTab(),
                _buildStatsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por negocio o producto...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _applySearch('');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        onChanged: _applySearch,
      ),
    );
  }

  Widget _buildAllOrdersTab() {
    return StreamBuilder<List<OrderHistoryItem>>(
      stream: _orderHistoryService.getOrderHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final orders = _isSearching ? _filteredOrders : snapshot.data ?? [];
        _allOrders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return _buildEmptyState('No tienes pedidos aún', 'Tu historial aparecerá aquí');
        }

        return _buildOrdersList(orders);
      },
    );
  }

  Widget _buildActiveOrdersTab() {
    return StreamBuilder<List<OrderHistoryItem>>(
      stream: _orderHistoryService.getActiveOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        _activeOrders = orders;

        if (orders.isEmpty) {
          return _buildEmptyState('No tienes pedidos activos', 'Los pedidos en curso aparecerán aquí');
        }

        return _buildOrdersList(orders);
      },
    );
  }

  Widget _buildFavoriteOrdersTab() {
    return StreamBuilder<List<OrderHistoryItem>>(
      stream: _orderHistoryService.getFavoriteOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        _favoriteOrders = orders;

        if (orders.isEmpty) {
          return _buildEmptyState('No tienes pedidos favoritos', 'Marca tus pedidos favoritos con ❤️');
        }

        return _buildOrdersList(orders);
      },
    );
  }

  Widget _buildFrequentOrdersTab() {
    return StreamBuilder<List<OrderHistoryItem>>(
      stream: _orderHistoryService.getFrequentOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data ?? [];
        _frequentOrders = orders;

        if (orders.isEmpty) {
          return _buildEmptyState('No tienes pedidos frecuentes', 'Reordena pedidos para verlos aquí');
        }

        return _buildOrdersList(orders);
      },
    );
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_stats == null) {
      return _buildEmptyState('No hay estadísticas', 'Tus estadísticas aparecerán aquí');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Tarjeta de estadísticas principales
          OrderStatsWidget(stats: _stats!),
          
          const SizedBox(height: 20),
          
          // Gastos mensuales
          _buildMonthlySpendingSection(),
          
          const SizedBox(height: 20),
          
          // Negocios frecuentes
          _buildFrequentBusinessesSection(),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderHistoryItem> orders) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderHistoryCard(
            order: order,
            onReorder: () => _reorderOrder(order),
            onToggleFavorite: () => _toggleFavorite(order),
            onTap: () => _navigateToOrderDetail(order),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySpendingSection() {
    return FutureBuilder<List<MonthlySpending>>(
      future: _orderHistoryService.getMonthlySpending(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final monthlyData = snapshot.data ?? [];

        if (monthlyData.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gastos Mensuales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...monthlyData.take(6).map((data) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(data.formattedMonth),
                        ),
                        Text(
                          data.formattedTotalSpent,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequentBusinessesSection() {
    return FutureBuilder<List<FrequentBusiness>>(
      future: _orderHistoryService.getFrequentBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final businesses = snapshot.data ?? [];

        if (businesses.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Negocios Más Frecuentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...businesses.take(5).map((business) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: business.businessImage.isNotEmpty
                              ? NetworkImage(business.businessImage)
                              : null,
                          child: business.businessImage.isEmpty
                              ? Text(
                                  business.businessName.isNotEmpty
                                      ? business.businessName[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                          backgroundColor: Colors.grey[400],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                business.businessName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${business.orderCount} pedidos • ${business.formattedLastOrderDate}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          business.formattedTotalSpent,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reorderOrder(OrderHistoryItem order) async {
    final result = await _orderHistoryService.reorderOrder(order.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          action: result['success']
              ? SnackBarAction(
                  label: 'Ver Carrito',
                  onPressed: () {
                    Navigator.pushNamed(context, '/cart');
                  },
                )
              : null,
        ),
      );
    }
  }

  Future<void> _toggleFavorite(OrderHistoryItem order) async {
    final success = await _orderHistoryService.toggleFavorite(order.id);
    
    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pedido actualizado'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _navigateToOrderDetail(OrderHistoryItem order) {
    // Navegar a pantalla de detalles del pedido
    Navigator.pushNamed(
      context,
      '/order_detail',
      arguments: {
        'orderId': order.id,
        'orderData': order,
      },
    );
  }
}

// Dialogo de filtros
class _FilterDialog extends StatefulWidget {
  final OrderStatus? selectedStatus;
  final String? selectedBusiness;
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy;
  final Function(OrderStatus?, String?, DateTime?, DateTime?, String) onApply;

  const _FilterDialog({
    required this.selectedStatus,
    required this.selectedBusiness,
    required this.startDate,
    required this.endDate,
    required this.sortBy,
    required this.onApply,
  });

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late OrderStatus? _selectedStatus;
  String? _selectedBusiness;
  DateTime? _startDate;
  DateTime? _endDate;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.selectedStatus;
    _selectedBusiness = widget.selectedBusiness;
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _sortBy = widget.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filtros'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Estado del pedido
            DropdownButtonFormField<OrderStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Estado del pedido',
                border: OutlineInputBorder(),
              ),
              items: OrderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_getStatusLabel(status)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Ordenar por
            DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: const InputDecoration(
                labelText: 'Ordenar por',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'date', child: Text('Fecha')),
                DropdownMenuItem(value: 'total', child: Text('Total')),
                DropdownMenuItem(value: 'business', child: Text('Negocio')),
                DropdownMenuItem(value: 'frequency', child: Text('Frecuencia')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortBy = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Rango de fechas
            ListTile(
              title: const Text('Rango de fechas'),
              subtitle: Text(_getDateRangeText()),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDateRange,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onApply(null, null, null, null, 'date');
            Navigator.pop(context);
          },
          child: const Text('Limpiar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selectedStatus, _selectedBusiness, _startDate, _endDate, _sortBy);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  String _getStatusLabel(OrderStatus status) {
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

  String _getDateRangeText() {
    if (_startDate == null && _endDate == null) {
      return 'Todos';
    } else if (_startDate != null && _endDate != null) {
      return '${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
    } else if (_startDate != null) {
      return 'Desde ${DateFormat('dd/MM/yyyy').format(_startDate!)}';
    } else {
      return 'Hasta ${DateFormat('dd/MM/yyyy').format(_endDate!)}';
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}
