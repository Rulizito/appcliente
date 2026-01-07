// ============================================================================
// screens/notification_center_screen.dart - Centro de Notificaciones
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_preference_model.dart';
import '../services/notification_preference_service.dart';
import '../services/notification_schedule_service.dart';
import '../services/notification_analytics_service.dart';
import '../widgets/notification_settings_widget.dart';
import '../widgets/notification_history_widget.dart';
import '../widgets/smart_notification_widget.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({Key? key}) : super(key: key);

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen>
    with SingleTickerProviderStateMixin {
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();
  final NotificationScheduleService _scheduleService = NotificationScheduleService();
  final NotificationAnalyticsService _analyticsService = NotificationAnalyticsService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController;

  NotificationProfile? _profile;
  List<NotificationPreference> _preferences = [];
  List<NotificationAnalytics> _recentNotifications = [];
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _prediction = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Cargar datos en paralelo
      await Future.wait([
        _loadProfile(),
        _loadPreferences(),
        _loadRecentNotifications(),
        _loadUserStats(),
        _loadPrediction(),
      ]);
    } catch (e) {
      print('Error loading notification center data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfile() async {
    _preferenceService.getCurrentUserProfile().listen((profile) {
      if (mounted) {
        setState(() {
          _profile = profile;
        });
      }
    });
  }

  Future<void> _loadPreferences() async {
    _preferenceService.getCurrentUserPreferences().listen((preferences) {
      if (mounted) {
        setState(() {
          _preferences = preferences;
        });
      }
    });
  }

  Future<void> _loadRecentNotifications() async {
    _preferenceService.getCurrentUserHistory(limit: 10).listen((notifications) {
      if (mounted) {
        setState(() {
          _recentNotifications = notifications;
        });
      }
    });
  }

  Future<void> _loadUserStats() async {
    final stats = await _preferenceService.getCurrentUserStats();
    if (mounted) {
      setState(() {
        _userStats = stats;
      });
    }
  }

  Future<void> _loadPrediction() async {
    final prediction = await _preferenceService.getCurrentUserPrediction();
    if (mounted) {
      setState(() {
        _prediction = prediction;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de Notificaciones'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Inicio', icon: Icon(Icons.home)),
            Tab(text: 'Historial', icon: Icon(Icons.history)),
            Tab(text: 'Configuración', icon: Icon(Icons.settings)),
            Tab(text: 'Análisis', icon: Icon(Icons.analytics)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHomeTab(),
                _buildHistoryTab(),
                _buildSettingsTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Widget inteligente de notificaciones
          SmartNotificationWidget(),
          
          const SizedBox(height: 20),
          
          // Resumen de preferencias
          if (_profile != null) ...[
            NotificationPreferencesSummaryWidget(
              profile: _profile!,
              preferences: _preferences,
            ),
            const SizedBox(height: 20),
          ],
          
          // Notificaciones recientes
          if (_recentNotifications.isNotEmpty) ...[
            const Text(
              'Notificaciones Recientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._recentNotifications.take(5).map((notification) {
              return NotificationHistoryItem(
                notification: notification,
                onTap: () => _markAsOpened(notification.id),
              );
            }).toList(),
            
            const SizedBox(height: 12),
            
            TextButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Ver todo el historial'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const NotificationHistoryScreen();
  }

  Widget _buildSettingsTab() {
    return const NotificationSettingsScreen();
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estadísticas generales
          NotificationAnalyticsWidget(stats: _userStats),
          
          const SizedBox(height: 20),
          
          // Insights
          if (_prediction.isNotEmpty) ...[
            NotificationInsightsWidget(insights: _prediction),
            const SizedBox(height: 20),
          ],
          
          // Análisis detallado
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Análisis Detallado',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Estadísticas por tipo
                  if (_userStats['statsByType'] != null) ...[
                    const Text(
                      'Por Tipo de Notificación',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_userStats['statsByType'] as Map<String, dynamic>).entries.map((entry) {
                      return _buildTypeAnalytics(entry.key, entry.value as Map<String, dynamic>);
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                  
                  // Estadísticas por canal
                  if (_userStats['statsByChannel'] != null) ...[
                    const Text(
                      'Por Canal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...(_userStats['statsByChannel'] as Map<String, dynamic>).entries.map((entry) {
                      return _buildChannelAnalytics(entry.key, entry.value as Map<String, dynamic>);
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeAnalytics(String type, Map<String, dynamic> stats) {
    final sent = stats['sent'] ?? 0;
    final opened = stats['opened'] ?? 0;
    final clicked = stats['clicked'] ?? 0;
    final openRate = sent > 0 ? opened / sent : 0.0;
    final clickRate = opened > 0 ? clicked / opened : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getTypeIcon(type), color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text('$sent enviadas'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip('Apertura', '${(openRate * 100).toStringAsFixed(1)}%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip('Clic', '${(clickRate * 100).toStringAsFixed(1)}%'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelAnalytics(String channel, Map<String, dynamic> stats) {
    final sent = stats['sent'] ?? 0;
    final opened = stats['opened'] ?? 0;
    final clicked = stats['clicked'] ?? 0;
    final openRate = sent > 0 ? opened / sent : 0.0;
    final clickRate = opened > 0 ? clicked / opened : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getChannelIcon(channel), color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text('$sent enviadas'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip('Apertura', '${(openRate * 100).toStringAsFixed(1)}%'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricChip('Clic', '${(clickRate * 100).toStringAsFixed(1)}%'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.red,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
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

class NotificationQuickActionsWidget extends StatelessWidget {
  final NotificationProfile? profile;
  final List<NotificationPreference> preferences;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onHistoryTap;

  const NotificationQuickActionsWidget({
    Key? key,
    this.profile,
    required this.preferences,
    this.onSettingsTap,
    this.onHistoryTap,
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
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Configuración',
                    Icons.settings,
                    () => onSettingsTap?.call(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Historial',
                    Icons.history,
                    () => onHistoryTap?.call(),
                  ),
                ),
              ],
            ),
            
            if (profile != null) ...[
              const SizedBox(height: 16),
              _buildQuickStats(profile!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[50],
        foregroundColor: Colors.red,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.red[200]!),
        ),
      ),
    );
  }

  Widget _buildQuickStats(NotificationProfile profile) {
    final enabledCategories = NotificationCategory.values
        .where((category) => profile.isCategoryEnabled(category))
        .length;
    
    final enabledChannels = NotificationChannel.values
        .where((channel) => profile.isChannelGloballyEnabled(channel))
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickStat('Categorías', '$enabledCategories/${NotificationCategory.values.length}'),
          _buildQuickStat('Canales', '$enabledChannels/${NotificationChannel.values.length}'),
          _buildQuickStat('Horas Silenciosas', profile.quietHoursEnabled ? 'Activas' : 'Inactivas'),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
