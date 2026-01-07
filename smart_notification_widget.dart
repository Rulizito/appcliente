// ============================================================================
// widgets/smart_notification_widget.dart - Widget de Notificaciones Inteligentes
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_preference_model.dart';
import '../services/notification_preference_service.dart';
import '../services/notification_schedule_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SmartNotificationWidget extends StatefulWidget {
  const SmartNotificationWidget({Key? key}) : super(key: key);

  @override
  State<SmartNotificationWidget> createState() => _SmartNotificationWidgetState();
}

class _SmartNotificationWidgetState extends State<SmartNotificationWidget> {
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();
  final NotificationScheduleService _scheduleService = NotificationScheduleService();

  List<Map<String, dynamic>> _scheduledNotifications = [];
  List<Map<String, dynamic>> _campaigns = [];
  Map<String, dynamic> _prediction = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() => _isLoading = true);

    // Cargar campañas
    _scheduleService.getCurrentUserCampaigns().listen((campaigns) {
      if (mounted) {
        setState(() {
          _campaigns = campaigns.map((c) => c.toMap()).toList();
          _isLoading = false;
        });
      }
    });

    // Cargar predicción (simulada por ahora)
    setState(() {
      _prediction = {
        'predictedEngagement': 0.75,
        'confidence': 0.8,
        'recommendations': ['Optimizar horarios de envío', 'Personalizar contenido'],
      };
    });
  }

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
            Row(
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Notificaciones Inteligentes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _navigateToSettings(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // Predicción de engagement
            if (_prediction.isNotEmpty) ...[
              _buildPredictionCard(),
              const SizedBox(height: 16),
            ],

            // Notificaciones programadas
            if (_scheduledNotifications.isNotEmpty) ...[
              _buildScheduledNotificationsCard(),
              const SizedBox(height: 16),
            ],

            // Campañas activas
            if (_campaigns.isNotEmpty) ...[
              _buildCampaignsCard(),
              const SizedBox(height: 16),
            ],

            // Acciones rápidas
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionCard() {
    final predictedEngagement = _prediction['predictedEngagement'] ?? 0.0;
    final confidence = _prediction['confidence'] ?? 0.0;
    final recommendations = (_prediction['recommendations'] as List<dynamic>?) ?? [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red[50]!,
            Colors.red[100]!,
          ],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Predicción de Engagement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Engagement score
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${(predictedEngagement * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      'Probabilidad de interacción',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  children: [
                    CircularProgressIndicator(
                      value: predictedEngagement,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      strokeWidth: 8,
                    ),
                    Center(
                      child: Icon(
                        _getEngagementIcon(predictedEngagement),
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Confidence
          Text(
            'Confianza: ${(confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          
          // Recommendations
          if (recommendations.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    color: Colors.amber[600],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      recommendation.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildScheduledNotificationsCard() {
    final upcomingNotifications = _scheduledNotifications
        .where((n) => !n['isSent'])
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.schedule,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Programadas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Spacer(),
            if (_scheduledNotifications.length > 3)
              Text(
                '+${_scheduledNotifications.length - 3} más',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        ...upcomingNotifications.map((notification) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    _getScheduledIcon(notification['templateType']),
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getScheduledTitle(notification['templateType']),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('dd MMM, HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              (notification['scheduledAt'] as int),
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, size: 16),
                    onPressed: () => _cancelScheduledNotification(notification['id']),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildCampaignsCard() {
    final activeCampaigns = _campaigns
        .where((c) => (c['isActive'] == true) && (c['isCompleted'] == false))
        .take(2)
        .toList();

    if (activeCampaigns.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.campaign,
              color: Colors.red,
              size: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'Campañas Activas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        ...activeCampaigns.map((campaign) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_offer,
                    color: Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign['name'] ?? 'Campaña',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          campaign['description'] ?? 'Descripción',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Programar',
                Icons.schedule,
                () => _scheduleNotification(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionButton(
                'Historial',
                Icons.history,
                () => _navigateToHistory(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
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

  IconData _getEngagementIcon(double engagement) {
    if (engagement >= 0.7) return Icons.trending_up;
    if (engagement >= 0.4) return Icons.trending_flat;
    return Icons.trending_down;
  }

  IconData _getScheduledIcon(String templateType) {
    switch (templateType) {
      case 'order_status_update':
        return Icons.receipt_long;
      case 'promotion_new':
        return Icons.local_offer;
      case 'loyalty_points_earned':
        return Icons.stars;
      case 'review_request':
        return Icons.rate_review;
      default:
        return Icons.notifications;
    }
  }

  String _getScheduledTitle(String templateType) {
    switch (templateType) {
      case 'order_status_update':
        return 'Actualización de Pedido';
      case 'promotion_new':
        return 'Nueva Promoción';
      case 'loyalty_points_earned':
        return 'Puntos Ganados';
      case 'review_request':
        return 'Solicitud de Reseña';
      default:
        return 'Notificación Programada';
    }
  }

  void _navigateToSettings() {
    Navigator.pushNamed(context, '/notification_settings');
  }

  void _navigateToHistory() {
    Navigator.pushNamed(context, '/notification_history');
  }

  void _scheduleNotification() {
    // Aquí iría la lógica para programar una notificación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Función de programación en desarrollo'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _cancelScheduledNotification(String scheduledId) async {
    try {
      await _scheduleService.cancelScheduledNotification(scheduledId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notificación cancelada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cancelar notificación'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class NotificationInsightsWidget extends StatelessWidget {
  final Map<String, dynamic> insights;

  const NotificationInsightsWidget({
    Key? key,
    required this.insights,
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
              'Insights de Notificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Mejor hora para enviar
            if (insights['optimalSendTimes'] != null) ...[
              _buildInsightItem(
                'Mejor hora para enviar',
                '${insights['optimalSendTimes']['peakHour']}:00',
                Icons.access_time,
                Colors.green,
              ),
              const SizedBox(height: 12),
            ],
            
            // Tasa de engagement
            if (insights['engagementRate'] != null) ...[
              _buildInsightItem(
                'Tasa de Engagement',
                '${((insights['engagementRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.blue,
              ),
              const SizedBox(height: 12),
            ],
            
            // Recomendaciones
            if (insights['recommendations'] != null) ...[
              _buildInsightItem(
                'Recomendaciones',
                '${(insights['recommendations'] as List).length} sugerencias',
                Icons.lightbulb,
                Colors.amber,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NotificationPreferencesSummaryWidget extends StatelessWidget {
  final NotificationProfile profile;
  final List<NotificationPreference> preferences;

  const NotificationPreferencesSummaryWidget({
    Key? key,
    required this.profile,
    required this.preferences,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final enabledCategories = NotificationCategory.values
        .where((category) => profile.isCategoryEnabled(category))
        .length;
    
    final enabledChannels = NotificationChannel.values
        .where((channel) => profile.isChannelGloballyEnabled(channel))
        .length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de Preferencias',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Categorías Activas',
                    '$enabledCategories/${NotificationCategory.values.length}',
                    Icons.category,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'Canales Activos',
                    '$enabledChannels/${NotificationChannel.values.length}',
                    Icons.notifications,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Horas silenciosas
            if (profile.quietHoursEnabled) ...[
              Row(
                children: [
                  Icon(
                    Icons.do_not_disturb,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Horas silenciosas: ${_formatTime(profile.quietHoursStart)} - ${_formatTime(profile.quietHoursEnd)}',
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
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
