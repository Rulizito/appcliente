// ============================================================================
// widgets/notification_settings_widget.dart - Widgets de Configuración de Notificaciones
// ============================================================================

import 'package:flutter/material.dart';
import '../models/notification_preference_model.dart';
import '../services/notification_preference_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with SingleTickerProviderStateMixin {
  final NotificationPreferenceService _preferenceService = NotificationPreferenceService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  NotificationProfile? _profile;
  List<NotificationPreference> _preferences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
      final profileStream = _preferenceService.getCurrentUserProfile();
      final preferencesStream = _preferenceService.getCurrentUserPreferences();

      profileStream.listen((profile) {
        if (mounted) {
          setState(() {
            _profile = profile;
          });
        }
      });

      preferencesStream.listen((preferences) {
        if (mounted) {
          setState(() {
            _preferences = preferences;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Notificaciones'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.settings)),
            Tab(text: 'Categorías', icon: Icon(Icons.category)),
            Tab(text: 'Canales', icon: Icon(Icons.notifications)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralSettings(),
                _buildCategorySettings(),
                _buildChannelSettings(),
              ],
            ),
    );
  }

  Widget _buildGeneralSettings() {
    if (_profile == null) {
      return const Center(child: Text('No se encontró el perfil de notificaciones'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horas silenciosas
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Horas Silenciosas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Activar horas silenciosas'),
                    subtitle: const Text('No recibir notificaciones durante ciertas horas'),
                    value: _profile!.quietHoursEnabled,
                    onChanged: (value) => _updateQuietHoursEnabled(value),
                  ),
                  if (_profile!.quietHoursEnabled) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text('Desde'),
                            subtitle: Text(_formatTime(_profile!.quietHoursStart)),
                            trailing: const Icon(Icons.access_time),
                            onTap: () => _selectTime('start'),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text('Hasta'),
                            subtitle: Text(_formatTime(_profile!.quietHoursEnd)),
                            trailing: const Icon(Icons.access_time),
                            onTap: () => _selectTime('end'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Frecuencia por defecto
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Frecuencia por Defecto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<NotificationFrequency>(
                    value: _profile!.defaultFrequency,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia',
                      border: OutlineInputBorder(),
                    ),
                    items: NotificationFrequency.values.map((frequency) {
                      return DropdownMenuItem(
                        value: frequency,
                        child: Text(frequency.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateDefaultFrequency(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Estadísticas rápidas
          Card(
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
                  FutureBuilder<Map<String, dynamic>>(
                    future: _preferenceService.getCurrentUserStats(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final stats = snapshot.data!;
                      return Column(
                        children: [
                          _buildStatItem('Total Enviadas', '${stats['totalSent'] ?? 0}'),
                          _buildStatItem('Tasa de Apertura', '${((stats['openRate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                          _buildStatItem('Tasa de Clic', '${((stats['clickRate'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySettings() {
    final groupedPreferences = <NotificationCategory, List<NotificationPreference>>{};
    
    for (final preference in _preferences) {
      groupedPreferences.putIfAbsent(preference.category, () => []).add(preference);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: NotificationCategory.values.map((category) {
          final categoryPreferences = groupedPreferences[category] ?? [];
          
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getCategoryIcon(category), color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: _profile?.isCategoryEnabled(category) ?? true,
                        onChanged: (value) => _toggleCategory(category, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...categoryPreferences.map((preference) {
                    return SwitchListTile(
                      title: Text(preference.type.displayName),
                      subtitle: Text(_getPreferenceDescription(preference.type)),
                      value: preference.isEnabled,
                      onChanged: (value) => _updatePreference(preference, value),
                    );
                  }).toList(),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChannelSettings() {
    if (_profile == null) {
      return const Center(child: Text('No se encontró el perfil de notificaciones'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: NotificationChannel.values.map((channel) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getChannelIcon(channel), color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          channel.displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: _profile!.isChannelGloballyEnabled(channel),
                        onChanged: (value) => _toggleChannel(channel, value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getChannelDescription(channel),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
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

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.orders:
        return Icons.receipt_long;
      case NotificationCategory.promotions:
        return Icons.local_offer;
      case NotificationCategory.loyalty:
        return Icons.stars;
      case NotificationCategory.recommendations:
        return Icons.thumb_up;
      case NotificationCategory.social:
        return Icons.people;
      case NotificationCategory.system:
        return Icons.settings;
      case NotificationCategory.reminders:
        return Icons.alarm;
    }
  }

  String _getPreferenceDescription(NotificationType type) {
    switch (type) {
      case NotificationType.order_status:
        return 'Actualizaciones sobre el estado de tus pedidos';
      case NotificationType.order_delivered:
        return 'Confirmación cuando tu pedido ha sido entregado';
      case NotificationType.promotion_new:
        return 'Nuevas promociones y ofertas especiales';
      case NotificationType.promotion_expiring:
        return 'Recordatorios de promociones por expirar';
      case NotificationType.loyalty_points:
        return 'Notificaciones sobre puntos ganados';
      case NotificationType.loyalty_tier_upgrade:
        return 'Cuando subes de nivel en el programa de lealtad';
      case NotificationType.loyalty_reward:
        return 'Nuevas recompensas disponibles';
      case NotificationType.recommendation:
        return 'Recomendaciones personalizadas para ti';
      case NotificationType.review_request:
        return 'Solicitudes para calificar negocios';
      case NotificationType.referral:
        return 'Invitaciones y bonos de referidos';
      case NotificationType.reminder_cart:
        return 'Recordatorios de productos en tu carrito';
      case NotificationType.reminder_favorite:
        return 'Actualizaciones de tus negocios favoritos';
      case NotificationType.system_update:
        return 'Actualizaciones y mantenimiento del sistema';
      case NotificationType.security:
        return 'Alertas de seguridad importantes';
    }
  }

  IconData _getChannelIcon(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.push:
        return Icons.notifications;
      case NotificationChannel.email:
        return Icons.email;
      case NotificationChannel.sms:
        return Icons.sms;
      case NotificationChannel.in_app:
        return Icons.phone_android;
    }
  }

  String _getChannelDescription(NotificationChannel channel) {
    switch (channel) {
      case NotificationChannel.push:
        return 'Notificaciones push en tu dispositivo móvil';
      case NotificationChannel.email:
        return 'Notificaciones enviadas a tu correo electrónico';
      case NotificationChannel.sms:
        return 'Notificaciones enviadas por mensaje de texto';
      case NotificationChannel.in_app:
        return 'Notificaciones mostradas dentro de la aplicación';
    }
  }

  Future<void> _updateQuietHoursEnabled(bool enabled) async {
    if (_profile == null) return;
    
    final updatedProfile = _profile!.copyWith(
      quietHoursEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    
    await _preferenceService.updateProfile(updatedProfile);
  }

  Future<void> _selectTime(String type) async {
    final currentTime = type == 'start' ? _profile!.quietHoursStart : _profile!.quietHoursEnd;
    
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (selectedTime != null) {
      final updatedProfile = _profile!.copyWith(
        quietHoursStart: type == 'start' ? selectedTime : _profile!.quietHoursStart,
        quietHoursEnd: type == 'end' ? selectedTime : _profile!.quietHoursEnd,
        updatedAt: DateTime.now(),
      );
      
      await _preferenceService.updateProfile(updatedProfile);
    }
  }

  Future<void> _updateDefaultFrequency(NotificationFrequency frequency) async {
    if (_profile == null) return;
    
    final updatedProfile = _profile!.copyWith(
      defaultFrequency: frequency,
      updatedAt: DateTime.now(),
    );
    
    await _preferenceService.updateProfile(updatedProfile);
  }

  Future<void> _toggleCategory(NotificationCategory category, bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _preferenceService.toggleCategory(user.uid, category, enabled);
  }

  Future<void> _toggleChannel(NotificationChannel channel, bool enabled) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    await _preferenceService.toggleChannel(user.uid, channel, enabled);
  }

  Future<void> _updatePreference(NotificationPreference preference, bool enabled) async {
    final updatedPreference = preference.copyWith(
      isEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    
    await _preferenceService.updatePreference(updatedPreference);
  }
}

class NotificationQuickSettingsWidget extends StatelessWidget {
  final NotificationProfile profile;
  final List<NotificationPreference> preferences;
  final Function(NotificationCategory, bool) onToggleCategory;
  final Function(NotificationChannel, bool) onToggleChannel;

  const NotificationQuickSettingsWidget({
    Key? key,
    required this.profile,
    required this.preferences,
    required this.onToggleCategory,
    required this.onToggleChannel,
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
              'Notificaciones Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Categorías principales
            Row(
              children: [
                Expanded(
                  child: _buildQuickToggle(
                    'Pedidos',
                    Icons.receipt_long,
                    profile.isCategoryEnabled(NotificationCategory.orders),
                    (value) => onToggleCategory(NotificationCategory.orders, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickToggle(
                    'Promos',
                    Icons.local_offer,
                    profile.isCategoryEnabled(NotificationCategory.promotions),
                    (value) => onToggleCategory(NotificationCategory.promotions, value),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickToggle(
                    'Lealtad',
                    Icons.stars,
                    profile.isCategoryEnabled(NotificationCategory.loyalty),
                    (value) => onToggleCategory(NotificationCategory.loyalty, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickToggle(
                    'Social',
                    Icons.people,
                    profile.isCategoryEnabled(NotificationCategory.social),
                    (value) => onToggleCategory(NotificationCategory.social, value),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Canales
            const Text(
              'Canales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildQuickToggle(
                    'Push',
                    Icons.notifications,
                    profile.isChannelGloballyEnabled(NotificationChannel.push),
                    (value) => onToggleChannel(NotificationChannel.push, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickToggle(
                    'Email',
                    Icons.email,
                    profile.isChannelGloballyEnabled(NotificationChannel.email),
                    (value) => onToggleChannel(NotificationChannel.email, value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickToggle(
    String title,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: value ? Colors.red : Colors.grey),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: value ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
