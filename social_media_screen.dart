import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/social_media_service.dart';
import '../widgets/social_share_widget.dart';
import 'package:intl/intl.dart';

class SocialMediaScreen extends StatefulWidget {
  const SocialMediaScreen({Key? key}) : super(key: key);

  @override
  State<SocialMediaScreen> createState() => _SocialMediaScreenState();
}

class _SocialMediaScreenState extends State<SocialMediaScreen>
    with TickerProviderStateMixin {
  final SocialMediaService _socialService = SocialMediaService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  late TabController _tabController;
  List<SocialProfile> _connectedProfiles = [];
  Map<String, dynamic> _sharingStats = {};
  List<Referral> _referrals = [];
  bool _isLoading = true;
  String? _userId;

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
      // Cargar perfiles conectados
      final profiles = await _socialService.getUserSocialProfiles(_userId!);
      
      // Cargar estadísticas de compartición
      final stats = await _socialService.getSharingStats(_userId!);
      
      setState(() {
        _connectedProfiles = profiles;
        _sharingStats = stats;
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
                      _buildConnectedProfilesTab(),
                      _buildSharingStatsTab(),
                      _buildReferralsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Redes Sociales'),
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
              case 'connect':
                _showConnectDialog();
                break;
              case 'settings':
                _showSettings();
                break;
              case 'help':
                _showHelp();
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'connect',
              child: Row(
                children: [
                  Icon(Icons.link, size: 20),
                  SizedBox(width: 8),
                  Text('Conectar red social'),
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
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Ayuda'),
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
            icon: Icon(Icons.link),
            text: 'Conectadas',
          ),
          Tab(
            icon: Icon(Icons.bar_chart),
            text: 'Estadísticas',
          ),
          Tab(
            icon: Icon(Icons.people),
            text: 'Referidos',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    if (_sharingStats.isEmpty) return const SizedBox.shrink();

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
            'Tus Estadísticas Sociales',
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
                  'Compartidos',
                  '${_sharingStats['totalShares'] ?? 0}',
                  Icons.share,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Referidos',
                  '${_sharingStats['totalReferrals'] ?? 0}',
                  Icons.people,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Tasa Conversión',
                  _sharingStats['conversionRate'] ?? '0%',
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
                  'Ganancias',
                  '\$${(_sharingStats['totalEarned'] ?? 0).toStringAsFixed(2)}',
                  Icons.attach_money,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Completados',
                  '${_sharingStats['completedReferrals'] ?? 0}',
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Plataformas',
                  '${(_sharingStats['platformStats'] as Map<String, dynamic>?)?.length ?? 0}',
                  Icons.devices,
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
            icon: Icon(Icons.link),
            text: 'Conectadas',
          ),
          Tab(
            icon: Icon(Icons.bar_chart),
            text: 'Estadísticas',
          ),
          Tab(
            icon: Icon(Icons.people),
            text: 'Referidos',
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
              'Inicia sesión para conectar redes sociales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Comparte contenido y gana recompensas',
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

  Widget _buildConnectedProfilesTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_connectedProfiles.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_off,
        title: 'No hay redes sociales conectadas',
        subtitle: 'Conecta tus redes sociales para empezar a compartir',
        action: _showConnectDialog,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _connectedProfiles.length,
      itemBuilder: (context, index) {
        final profile = _connectedProfiles[index];
        return _buildProfileCard(profile);
      },
    );
  }

  Widget _buildSharingStatsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sharingStats.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        title: 'No hay estadísticas disponibles',
        subtitle: 'Comienza a compartir contenido para ver tus estadísticas',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estadísticas generales
          _buildStatsCard('Estadísticas Generales', [
            _buildStatRow('Total de compartidos', '${_sharingStats['totalShares'] ?? 0}'),
            _buildStatRow('Total de referidos', '${_sharingStats['totalReferrals'] ?? 0}'),
            _buildStatRow('Referidos completados', '${_sharingStats['completedReferrals'] ?? 0}'),
            _buildStatRow('Tasa de conversión', _sharingStats['conversionRate'] ?? '0%'),
            _buildStatRow('Ganancias totales', '\$${(_sharingStats['totalEarned'] ?? 0).toStringAsFixed(2)}'),
          ]),
          
          const SizedBox(height: 16),
          
          // Estadísticas por plataforma
          _buildPlatformStats(),
          
          const SizedBox(height: 16),
          
          // Botón para generar código de referido
          _buildReferralCodeSection(),
        ],
      ),
    );
  }

  Widget _buildReferralsTab() {
    return Column(
      children: [
        // Header con código de referido
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu Código de Referido',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Text(
                        _socialService.generateReferralCode(_userId!),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _copyReferralCode,
                    icon: const Icon(Icons.copy, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: _shareReferralCode,
                    icon: const Icon(Icons.share, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Lista de referidos
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _referrals.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.people_outline,
                      title: 'No hay referidos aún',
                      subtitle: 'Comparte tu código para empezar a ganar recompensas',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _referrals.length,
                      itemBuilder: (context, index) {
                        final referral = _referrals[index];
                        return _buildReferralCard(referral);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(SocialProfile profile) {
    final platformInfo = _socialService.getPlatformInfo(profile.platform);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar de la plataforma
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: platformInfo['color'],
                shape: BoxShape.circle,
              ),
              child: profile.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      _getPlatformIcon(profile.platform),
                      color: Colors.white,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            
            // Información del perfil
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    platformInfo['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${profile.username}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (profile.displayName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.displayName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: profile.isActive ? Colors.green : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          profile.isActive ? 'Activo' : 'Inactivo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Conectado el ${DateFormat('d MMMM yyyy').format(profile.connectedAt)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Acciones
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'disconnect':
                    _disconnectProfile(profile);
                    break;
                  case 'refresh':
                    _refreshProfile(profile);
                    break;
                  case 'share':
                    _shareProfile(profile);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('Compartir perfil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 8),
                      Text('Actualizar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.link_off, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Desconectar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(String title, List<Widget> stats) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...stats,
          ],
        ),
      ),
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
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformStats() {
    final platformStats = _sharingStats['platformStats'] as Map<String, dynamic>? ?? {};
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas por Plataforma',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...platformStats.entries.map((entry) {
              final platformInfo = _socialService.getPlatformInfo(
                _getPlatformFromName(entry.key),
              );
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: platformInfo['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getPlatformIcon(_getPlatformFromName(entry.key)),
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      platformInfo['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.value} compartidos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCodeSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Promociona tu código',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Comparte tu código de referido en redes sociales para ganar recompensas cuando tus amigos se registren.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareReferralCode,
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir código'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _copyReferralCode,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralCard(Referral referral) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: referral.isCompleted ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    referral.isCompleted ? Icons.check_circle : Icons.pending,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        referral.isCompleted ? 'Referido Completado' : 'Referido Pendiente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: referral.isCompleted ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Código: ${referral.referralCode}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (referral.platform != null) ...[
              Row(
                children: [
                  Icon(Icons.devices, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _socialService.getPlatformInfo(referral.platform!)['name'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Creado: ${DateFormat('d MMMM yyyy').format(referral.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            if (referral.isCompleted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Recompensa: \$${referral.rewardAmount?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? action,
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
                color: Colors.grey.shade600,
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
            if (action != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Conectar Red Social'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  SocialPlatform _getPlatformFromName(String name) {
    switch (name.toLowerCase()) {
      case 'facebook':
        return SocialPlatform.facebook;
      case 'twitter':
        return SocialPlatform.twitter;
      case 'instagram':
        return SocialPlatform.instagram;
      case 'whatsapp':
        return SocialPlatform.whatsapp;
      case 'telegram':
        return SocialPlatform.telegram;
      case 'linkedin':
        return SocialPlatform.linkedin;
      case 'pinterest':
        return SocialPlatform.pinterest;
      case 'tiktok':
        return SocialPlatform.tiktok;
      case 'snapchat':
        return SocialPlatform.snapchat;
      default:
        return SocialPlatform.facebook;
    }
  }

  IconData _getPlatformIcon(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.twitter:
        return Icons.alternate_email;
      case SocialPlatform.instagram:
        return Icons.camera_alt;
      case SocialPlatform.whatsapp:
        return Icons.message;
      case SocialPlatform.telegram:
        return Icons.send;
      case SocialPlatform.linkedin:
        return Icons.work;
      case SocialPlatform.pinterest:
        return Icons.push_pin;
      case SocialPlatform.tiktok:
        return Icons.music_note;
      case SocialPlatform.snapchat:
        return Icons.camera;
    }
  }

  void _showConnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conectar Red Social'),
        content: const Text('Selecciona la red social que deseas conectar'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Configuración próximamente')),
    );
  }

  void _showHelp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ayuda próximamente')),
    );
  }

  void _disconnectProfile(SocialProfile profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Desconectar ${_socialService.getPlatformInfo(profile.platform)['name']}'),
        content: const Text('¿Estás seguro de que quieres desconectar esta red social?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _socialService.disconnectSocialProfile(profile.id);
                _refreshData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Red social desconectada'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al desconectar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Desconectar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _refreshProfile(SocialProfile profile) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Actualizando perfil...')),
    );
    _refreshData();
  }

  void _shareProfile(SocialProfile profile) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compartiendo perfil...')),
    );
  }

  void _copyReferralCode() {
    final code = _socialService.generateReferralCode(_userId!);
    // Aquí se implementaría la funcionalidad de copiar al portapapeles
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código $code copiado al portapapeles'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareReferralCode() {
    final code = _socialService.generateReferralCode(_userId!);
    final content = ShareableContent(
      id: 'referral',
      type: ShareContentType.referral,
      title: '¡Únete a la mejor app de delivery!',
      description: 'Usa mi código $code para obtener un bono especial en tu primer pedido.',
      url: 'https://tuapp.com/referral/$code',
      createdAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SocialShareWidget(
        content: content,
        onShareComplete: (success) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Código de referido compartido!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}
