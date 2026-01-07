// ============================================================================
// widgets/notification_history_widget.dart - Widgets de Historial de Notificaciones
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_preference_model.dart';
import '../services/notification_preference_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({Key? key}) : super(key: key);

  @override
  State<NotificationHistoryScreen> createState() => _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen>
    with SingleTickerProviderStateMixin {
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();
  late TabController _tabController;

  List<NotificationAnalytics> _notifications = [];
  bool _isLoading = true;
  NotificationType? _selectedType;
  NotificationChannel? _selectedChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadNotifications() {
    setState(() => _isLoading = true);

    _preferenceService.getCurrentUserHistory(
      limit: 50,
      type: _selectedType,
      channel: _selectedChannel,
    ).listen((notifications) {
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Notificaciones'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterChips(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildNotificationsList(),
                      _buildAnalyticsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (_selectedType != null)
                Chip(
                  label: Text(_selectedType!.displayName),
                  onDeleted: () {
                    setState(() {
                      _selectedType = null;
                    });
                    _loadNotifications();
                  },
                  backgroundColor: Colors.red[100],
                ),
              if (_selectedChannel != null)
                Chip(
                  label: Text(_selectedChannel!.displayName),
                  onDeleted: () {
                    setState(() {
                      _selectedChannel = null;
                    });
                    _loadNotifications();
                  },
                  backgroundColor: Colors.red[100],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No hay notificaciones',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => _loadNotifications(),
      child: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return NotificationHistoryItem(
            notification: notification,
            onTap: () => _markAsOpened(notification.id),
          );
        },
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _preferenceService.getCurrentUserStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Estadísticas generales
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estadísticas Generales',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('Total Enviadas', '${stats['totalSent'] ?? 0}'),
                      _buildStatRow('Entregadas', '${stats['totalDelivered'] ?? 0}'),
                      _buildStatRow('Abiertas', '${stats['totalOpened'] ?? 0}'),
                      _buildStatRow('Clickeadas', '${stats['totalClicked'] ?? 0}'),
                      const SizedBox(height: 16),
                      _buildStatRow(
                        'Tasa de Apertura',
                        '${((stats['openRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                      ),
                      _buildStatRow(
                        'Tasa de Clic',
                        '${((stats['clickRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Estadísticas por tipo
              if (stats['statsByType'] != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Por Tipo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(stats['statsByType'] as Map<String, dynamic>).entries.map((entry) {
                          return _buildTypeStat(entry.key, entry.value as Map<String, dynamic>);
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Estadísticas por canal
              if (stats['statsByChannel'] != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Por Canal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...(stats['statsByChannel'] as Map<String, dynamic>).entries.map((entry) {
                          return _buildChannelStat(entry.key, entry.value as Map<String, dynamic>);
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeStat(String type, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getTypeIcon(type), color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            '${stats['sent'] ?? 0}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelStat(String channel, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(_getChannelIcon(channel), color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              channel,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            '${stats['sent'] ?? 0}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Notificaciones'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filtro por tipo
                const Text(
                  'Tipo de Notificación',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: NotificationType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return FilterChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = selected ? type : null;
                        });
                      },
                      backgroundColor: isSelected ? Colors.red[100] : null,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Filtro por canal
                const Text(
                  'Canal',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: NotificationChannel.values.map((channel) {
                    final isSelected = _selectedChannel == channel;
                    return FilterChip(
                      label: Text(channel.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedChannel = selected ? channel : null;
                        });
                      },
                      backgroundColor: isSelected ? Colors.red[100] : null,
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadNotifications();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsOpened(String analyticsId) async {
    await _preferenceService.markNotificationAsOpened(analyticsId);
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'order_status':
        return Icons.receipt_long;
      case 'order_delivered':
        return Icons.check_circle;
      case 'promotion_new':
        return Icons.local_offer;
      case 'promotion_expiring':
        return Icons.timer;
      case 'loyalty_points':
        return Icons.stars;
      case 'loyalty_tier_upgrade':
        return Icons.trending_up;
      case 'loyalty_reward':
        return Icons.card_giftcard;
      case 'recommendation':
        return Icons.thumb_up;
      case 'review_request':
        return Icons.rate_review;
      case 'referral':
        return Icons.share;
      case 'reminder_cart':
        return Icons.shopping_cart;
      case 'reminder_favorite':
        return Icons.favorite;
      case 'system_update':
        return Icons.system_update;
      case 'security':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  IconData _getChannelIcon(String channel) {
    switch (channel) {
      case 'push':
        return Icons.notifications;
      case 'email':
        return Icons.email;
      case 'sms':
        return Icons.sms;
      case 'in_app':
        return Icons.phone_android;
      default:
        return Icons.notifications;
    }
  }
}

class NotificationHistoryItem extends StatelessWidget {
  final NotificationAnalytics notification;
  final VoidCallback? onTap;

  const NotificationHistoryItem({
    Key? key,
    required this.notification,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(),
          child: Icon(
            _getStatusIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          _getTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(notification.sentAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStatusChip('Entregado', notification.isDelivered),
                const SizedBox(width: 4),
                _buildStatusChip('Abierta', notification.isOpened),
                const SizedBox(width: 4),
                _buildStatusChip('Clickeada', notification.isClicked),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTypeIcon(),
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              _getChannelDisplayName(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _getTitle() {
    // Intentar obtener el título de los metadatos
    if (notification.metadata.containsKey('title')) {
      return notification.metadata['title'] as String;
    }
    
    // Si no hay título, usar el tipo de notificación
    return notification.type.displayName;
  }

  Color _getStatusColor() {
    if (!notification.isDelivered) return Colors.grey;
    if (notification.isClicked) return Colors.green;
    if (notification.isOpened) return Colors.blue;
    return Colors.orange;
  }

  IconData _getStatusIcon() {
    if (!notification.isDelivered) return Icons.schedule;
    if (notification.isClicked) return Icons.touch_app;
    if (notification.isOpened) return Icons.visibility;
    return Icons.mark_email_read;
  }

  Widget _buildStatusChip(String label, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[100] : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: isActive ? Colors.green[800] : Colors.grey[600],
        ),
      ),
    );
  }

  IconData _getTypeIcon() {
    switch (notification.type) {
      case NotificationType.order_status:
        return Icons.receipt_long;
      case NotificationType.order_delivered:
        return Icons.check_circle;
      case NotificationType.promotion_new:
        return Icons.local_offer;
      case NotificationType.promotion_expiring:
        return Icons.timer;
      case NotificationType.loyalty_points:
        return Icons.stars;
      case NotificationType.loyalty_tier_upgrade:
        return Icons.trending_up;
      case NotificationType.loyalty_reward:
        return Icons.card_giftcard;
      case NotificationType.recommendation:
        return Icons.thumb_up;
      case NotificationType.review_request:
        return Icons.rate_review;
      case NotificationType.referral:
        return Icons.share;
      case NotificationType.reminder_cart:
        return Icons.shopping_cart;
      case NotificationType.reminder_favorite:
        return Icons.favorite;
      case NotificationType.system_update:
        return Icons.system_update;
      case NotificationType.security:
        return Icons.security;
    }
  }

  String _getChannelDisplayName() {
    switch (notification.channel) {
      case NotificationChannel.push:
        return 'Push';
      case NotificationChannel.email:
        return 'Email';
      case NotificationChannel.sms:
        return 'SMS';
      case NotificationChannel.in_app:
        return 'In-App';
    }
  }
}

class NotificationAnalyticsWidget extends StatelessWidget {
  final Map<String, dynamic> stats;

  const NotificationAnalyticsWidget({
    Key? key,
    required this.stats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tus Estadísticas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Total Enviadas', '${stats['totalSent'] ?? 0}'),
            _buildMetricRow('Tasa de Apertura', '${((stats['openRate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildMetricRow('Tasa de Clic', '${((stats['clickRate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildMetricRow('Tiempo Promedio de Apertura', '${(stats['avgTimeToOpen'] ?? 0.0).toStringAsFixed(1)}s'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
