import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scheduled_order_service.dart';
import '../models/scheduled_order_model.dart';
import '../models/business_model.dart' as business_model;
import '../widgets/schedule_order_widget.dart';

class ScheduledOrdersScreen extends StatefulWidget {
  const ScheduledOrdersScreen({Key? key}) : super(key: key);

  @override
  State<ScheduledOrdersScreen> createState() => _ScheduledOrdersScreenState();
}

class _ScheduledOrdersScreenState extends State<ScheduledOrdersScreen>
    with TickerProviderStateMixin {
  final ScheduledOrderService _scheduleService = ScheduledOrderService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  List<ScheduledOrder> _upcomingOrders = [];
  List<ScheduledOrder> _pastOrders = [];
  List<ScheduledOrder> _allOrders = [];
  bool _isLoading = true;
  String? _userId;
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar estadísticas
      final stats = await _scheduleService.getScheduledOrderStats(_userId!);
      
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _userId == null
          ? _buildNotLoggedInState()
          : Column(
              children: [
                _buildStatsHeader(),
                _buildTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpcomingOrders(),
                      _buildPastOrders(),
                      _buildAllOrders(),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _userId != null
          ? FloatingActionButton(
              onPressed: _showNewScheduleDialog,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Pedidos Programados'),
      backgroundColor: Theme.of(context).primaryColor,
      actions: [
        IconButton(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'calendar':
                _showCalendarView();
                break;
              case 'stats':
                _showDetailedStats();
                break;
              case 'settings':
                _showSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'calendar',
              child: Row(
                children: [
                  Icon(Icons.calendar_month, size: 20),
                  SizedBox(width: 8),
                  Text('Vista calendario'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'stats',
              child: Row(
                children: [
                  Icon(Icons.bar_chart, size: 20),
                  SizedBox(width: 8),
                  Text('Estadísticas'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Configuración'),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(
            icon: Icon(Icons.upcoming),
            text: 'Próximos',
          ),
          Tab(
            icon: Icon(Icons.history),
            text: 'Pasados',
          ),
          Tab(
            icon: Icon(Icons.list),
            text: 'Todos',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_stats.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tus Estadísticas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Pedidos',
                  '${_stats['totalOrders'] ?? 0}',
                  Icons.shopping_cart,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completados',
                  '${_stats['completedOrders'] ?? 0}',
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Tasa de Éxito',
                  '${(_stats['completionRate'] ?? 0).toStringAsFixed(1)}%',
                  Icons.trending_up,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Gasto Total',
                  '\$${(_stats['totalSpent'] ?? 0).toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Promedio',
                  '\$${(_stats['averageOrderValue'] ?? 0).toStringAsFixed(2)}',
                  Icons.receipt_long,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Pendientes',
                  '${_stats['pendingOrders'] ?? 0}',
                  Icons.pending,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Theme.of(context).primaryColor,
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        tabs: const [
          Tab(
            icon: Icon(Icons.upcoming),
            text: 'Próximos',
          ),
          Tab(
            icon: Icon(Icons.history),
            text: 'Pasados',
          ),
          Tab(
            icon: Icon(Icons.list),
            text: 'Todos',
          ),
        ],
      ),
    );
  }

  Widget _buildNotLoggedInState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Inicia sesión para programar pedidos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Agenda tus pedidos con anticipación',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingOrders() {
    return StreamBuilder<List<ScheduledOrder>>(
      stream: _scheduleService.getUserScheduledOrders(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allOrders = snapshot.data ?? [];
        final upcomingOrders = allOrders.where((order) {
          return order.scheduledDateTime.isAfter(DateTime.now()) &&
                 order.status != ScheduledOrderStatus.cancelled;
        }).toList();

        if (upcomingOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.schedule,
            title: 'No hay pedidos próximos',
            subtitle: 'Programa tu primer pedido para verlo aquí',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: upcomingOrders.length,
          itemBuilder: (context, index) {
            final order = upcomingOrders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildPastOrders() {
    return StreamBuilder<List<ScheduledOrder>>(
      stream: _scheduleService.getUserScheduledOrders(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allOrders = snapshot.data ?? [];
        final pastOrders = allOrders.where((order) {
          return order.scheduledDateTime.isBefore(DateTime.now()) ||
                 order.status == ScheduledOrderStatus.delivered ||
                 order.status == ScheduledOrderStatus.cancelled;
        }).toList();

        if (pastOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.history,
            title: 'No hay pedidos pasados',
            subtitle: 'Tus pedidos completados aparecerán aquí',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: pastOrders.length,
          itemBuilder: (context, index) {
            final order = pastOrders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildAllOrders() {
    return StreamBuilder<List<ScheduledOrder>>(
      stream: _scheduleService.getUserScheduledOrders(_userId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        final allOrders = snapshot.data ?? [];

        if (allOrders.isEmpty) {
          return _buildEmptyState(
            icon: Icons.list_alt,
            title: 'No hay pedidos programados',
            subtitle: 'Crea tu primer pedido programado',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: allOrders.length,
          itemBuilder: (context, index) {
            final order = allOrders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(ScheduledOrder order) {
    final isUpcoming = order.scheduledDateTime.isAfter(DateTime.now());
    final isOverdue = order.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      order.statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (order.isRecurring)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Recurrente',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Fecha y hora
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('EEEE d MMMM, HH:mm', 'es').format(order.scheduledDateTime),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? Colors.red : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Items y total
              Row(
                children: [
                  Icon(Icons.receipt_long, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${order.items.length} productos • \$${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.note, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Acciones
              if (isUpcoming && order.status == ScheduledOrderStatus.pending)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _cancelOrder(order),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _modifyOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Modificar'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ScheduledOrderStatus status) {
    switch (status) {
      case ScheduledOrderStatus.pending:
        return Colors.orange;
      case ScheduledOrderStatus.confirmed:
        return Colors.blue;
      case ScheduledOrderStatus.preparing:
        return Colors.purple;
      case ScheduledOrderStatus.ready:
        return Colors.green;
      case ScheduledOrderStatus.on_way:
        return Colors.indigo;
      case ScheduledOrderStatus.delivered:
        return Colors.green;
      case ScheduledOrderStatus.cancelled:
        return Colors.red;
      case ScheduledOrderStatus.no_show:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showNewScheduleDialog() {
    // Aquí se mostraría el diálogo para crear un nuevo pedido programado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de programación próximamente')),
    );
  }

  void _showOrderDetails(ScheduledOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                const Spacer(),
                Text(
                  'Detalles del Pedido',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            
            // Contenido del pedido
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado y fecha
                    _buildDetailItem(
                      'Estado',
                      order.statusText,
                      Icons.info,
                      _getStatusColor(order.status),
                    ),
                    _buildDetailItem(
                      'Fecha programada',
                      DateFormat('EEEE d MMMM yyyy, HH:mm', 'es').format(order.scheduledDateTime),
                      Icons.schedule,
                      Colors.grey[600]!,
                    ),
                    
                    if (order.isRecurring)
                      _buildDetailItem(
                        'Recurrencia',
                        _getRecurrenceText(order.recurrencePattern),
                        Icons.repeat,
                        Colors.purple,
                      ),
                    
                    // Items
                    const SizedBox(height: 16),
                    const Text(
                      'Productos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '${item.quantity}x',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.productName),
                          ),
                          Text(
                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )),
                    
                    // Totales
                    const SizedBox(height: 16),
                    const Divider(),
                    _buildTotalRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                    _buildTotalRow('Envío', '\$${order.deliveryFee.toStringAsFixed(2)}'),
                    if (order.tip > 0)
                      _buildTotalRow('Propina', '\$${order.tip.toStringAsFixed(2)}'),
                    const Divider(),
                    _buildTotalRow(
                      'Total',
                      '\$${order.total.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                    
                    // Notas
                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Notas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(order.notes!),
                    ],
                    
                    // Instrucciones especiales
                    if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Instrucciones Especiales',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(order.specialInstructions!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getRecurrenceText(RecurrencePattern? pattern) {
    if (pattern == null) return 'No recurrente';
    
    switch (pattern.type) {
      case RecurrenceType.daily:
        return 'Diario';
      case RecurrenceType.weekly:
        return 'Semanal';
      case RecurrenceType.monthly:
        return 'Mensual';
      case RecurrenceType.yearly:
        return 'Anual';
    }
  }

  void _cancelOrder(ScheduledOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Pedido'),
        content: const Text('¿Estás seguro de que quieres cancelar este pedido programado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _scheduleService.cancelScheduledOrder(order.id, 'Cancelado por el usuario');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pedido cancelado exitosamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al cancelar pedido: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Sí, cancelar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _modifyOrder(ScheduledOrder order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de modificación próximamente')),
    );
  }

  void _showCalendarView() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vista calendario próximamente')),
    );
  }

  void _showDetailedStats() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estadísticas detalladas próximamente')),
    );
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración próximamente')),
    );
  }
}
