// ============================================================================
// screens/promotion_banners_screen.dart - Pantalla de Banners Promocionales
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promotion_banner_model.dart';
import '../services/promotion_banner_service.dart';
import '../widgets/promotion_banner_widget.dart';
import '../widgets/promotion_banner_carousel.dart';
import 'package:intl/intl.dart';

class PromotionBannersScreen extends StatefulWidget {
  const PromotionBannersScreen({Key? key}) : super(key: key);

  @override
  State<PromotionBannersScreen> createState() => _PromotionBannersScreenState();
}

class _PromotionBannersScreenState extends State<PromotionBannersScreen>
    with SingleTickerProviderStateMixin {
  final _bannerService = PromotionBannerService();
  late TabController _tabController;
  
  List<PromotionBanner> _heroBanners = [];
  List<PromotionBanner> _carouselBanners = [];
  List<PromotionBanner> _flashBanners = [];
  List<PromotionBanner> _allBanners = [];
  
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

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
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadHeroBanners(),
        _loadCarouselBanners(),
        _loadFlashBanners(),
        _loadAllBanners(),
        _loadStats(),
      ]);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHeroBanners() async {
    _heroBanners = await _bannerService.getHeroBanners().first;
  }

  Future<void> _loadCarouselBanners() async {
    _carouselBanners = await _bannerService.getCarouselBanners().first;
  }

  Future<void> _loadFlashBanners() async {
    _flashBanners = await _bannerService.getFlashBanners().first;
  }

  Future<void> _loadAllBanners() async {
    _allBanners = await _bannerService.getActiveBannersForUser().first;
  }

  Future<void> _loadStats() async {
    _stats = await _bannerService.getBannerStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Promociones',
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
            Tab(text: 'Destacados', icon: Icon(Icons.star)),
            Tab(text: 'Carrusel', icon: Icon(Icons.view_carousel)),
            Tab(text: 'Flash', icon: Icon(Icons.flash_on)),
            Tab(text: 'Todas', icon: Icon(Icons.list)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          if (_stats != null)
            IconButton(
              onPressed: _showStatsDialog,
              icon: const Icon(Icons.analytics),
              tooltip: 'Estadísticas',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildHeroBannersTab(),
                _buildCarouselBannersTab(),
                _buildFlashBannersTab(),
                _buildAllBannersTab(),
              ],
            ),
    );
  }

  Widget _buildHeroBannersTab() {
    if (_heroBanners.isEmpty) {
      return _buildEmptyState('No hay banners destacados', 'Los banners principales aparecerán aquí');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Banner principal
          if (_heroBanners.isNotEmpty)
            PromotionBannerWidget(
              banner: _heroBanners.first,
              margin: const EdgeInsets.only(bottom: 16),
            ),
          
          // Banners secundarios
          if (_heroBanners.length > 1)
            PromotionBannerGrid(
              banners: _heroBanners.skip(1).take(4).toList(),
              crossAxisCount: 2,
            ),
        ],
      ),
    );
  }

  Widget _buildCarouselBannersTab() {
    if (_carouselBanners.isEmpty) {
      return _buildEmptyState('No hay banners en carrusel', 'Los banners del carrusel aparecerán aquí');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carrusel principal
          PromotionBannerCarousel(
            banners: _carouselBanners,
            height: 180,
            autoPlay: true,
            onBannerTap: _handleBannerTap,
          ),
          
          const SizedBox(height: 20),
          
          // Grid de banners adicionales
          if (_carouselBanners.length > 3)
            PromotionBannerGrid(
              banners: _carouselBanners.skip(3).take(6).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildFlashBannersTab() {
    if (_flashBanners.isEmpty) {
      return _buildEmptyState('No hay ofertas flash', 'Las ofertas flash aparecerán aquí');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: PromotionBannerList(
        banners: _flashBanners,
        onBannerTap: _handleBannerTap,
      ),
    );
  }

  Widget _buildAllBannersTab() {
    if (_allBanners.isEmpty) {
      return _buildEmptyState('No hay promociones activas', 'Las promociones activas aparecerán aquí');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Estadísticas rápidas
          if (_stats != null) _buildQuickStats(),
          
          const SizedBox(height: 20),
          
          // Todos los banners
          PromotionBannerList(
            banners: _allBanners,
            onBannerTap: _handleBannerTap,
          ),
        ],
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
              Icons.local_offer,
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadísticas Rápidas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Banners',
                    '${_stats!['totalBanners'] ?? 0}',
                    Icons.local_offer,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Activos',
                    '${_stats!['activeBanners'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Impresiones',
                    '${_stats!['totalImpressions'] ?? 0}',
                    Icons.visibility,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Clics',
                    '${_stats!['totalClicks'] ?? 0}',
                    Icons.touch_app,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'CTR',
                    '${(_stats!['ctr'] ?? 0.0).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Tipos',
                    '${_stats!['statsByType']?.length ?? 0}',
                    Icons.category,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _handleBannerTap(PromotionBanner banner) {
    // Mostrar detalles del banner
    showDialog(
      context: context,
      builder: (context) => _BannerDetailsDialog(banner: banner),
    );
  }

  void _refreshData() {
    _loadData();
  }

  void _showStatsDialog() {
    if (_stats == null) return;

    showDialog(
      context: context,
      builder: (context) => _StatsDialog(stats: _stats!),
    );
  }
}

class _BannerDetailsDialog extends StatelessWidget {
  final PromotionBanner banner;
  final PromotionBannerService _bannerService = PromotionBannerService();

  _BannerDetailsDialog({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: banner.backgroundColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            banner.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        banner.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Preview del banner
              Container(
                padding: const EdgeInsets.all(20),
                child: PromotionBannerWidget(
                  banner: banner,
                  margin: EdgeInsets.zero,
                ),
              ),
              
              // Detalles
              Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDetailRow('Tipo', banner.type.value),
                    _buildDetailRow('Acción', banner.action.value),
                    _buildDetailRow('Prioridad', banner.priority.toString()),
                    _buildDetailRow('Estado', banner.isCurrentlyActive ? 'Activo' : 'Inactivo'),
                    _buildDetailRow('Inicio', DateFormat('dd/MM/yyyy').format(banner.startDate)),
                    _buildDetailRow('Fin', DateFormat('dd/MM/yyyy').format(banner.endDate)),
                    _buildDetailRow('Impresiones', '${banner.currentImpressions}'),
                    _buildDetailRow('Clics', '${banner.currentClicks}'),
                    
                    if (banner.targetBusinessIds?.isNotEmpty == true)
                      _buildDetailRow('Negocios', '${banner.targetBusinessIds!.length}'),
                    
                    if (banner.targetCategories?.isNotEmpty == true)
                      _buildDetailRow('Categorías', '${banner.targetCategories!.length}'),
                  ],
                ),
              ),
              
              // Acciones
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _bannerService.executeBannerAction(banner, context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: banner.buttonColor,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(banner.formattedButtonText),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsDialog extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _StatsDialog({required this.stats});

  @override
  Widget build(BuildContext context) {
    final statsByType = stats['statsByType'] as Map<String, dynamic>? ?? {};
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Estadísticas de Banners',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Estadísticas principales
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatsSection('Generales', [
                      'Total de banners: ${stats['totalBanners'] ?? 0}',
                      'Banners activos: ${stats['activeBanners'] ?? 0}',
                      'Impresiones totales: ${stats['totalImpressions'] ?? 0}',
                      'Clics totales: ${stats['totalClicks'] ?? 0}',
                      'CTR: ${(stats['ctr'] ?? 0.0).toStringAsFixed(2)}%',
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    _buildStatsSection('Por Tipo', statsByType.entries.map((entry) {
                      return '${entry.key}: ${entry.value}';
                    }).toList()),
                  ],
                ),
              ),
            ),
            
            // Botón cerrar
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
