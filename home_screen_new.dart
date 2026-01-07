import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'business_list_screen.dart';
import 'search_screen.dart';
import 'orders_screen.dart';
import 'favorites_screen.dart';
import 'nearby_businesses_screen.dart';
import 'order_tracking_screen.dart';
import 'edit_profile_screen.dart';
import 'support_conversations_screen.dart';
import 'chat_screen.dart';
import 'coupons_screen.dart';
import 'referral_screen.dart';
import 'recommendations_screen.dart';
import '../services/theme_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/cart_service.dart';
import '../services/favorites_service.dart';
import '../models/order_model.dart' as order_model;
import 'package:intl/intl.dart';
import 'enhanced_search_screen.dart';
import 'advanced_filters_screen.dart';
import 'order_history_screen.dart';
import '../services/advanced_search_service.dart';
import 'promotion_banners_screen.dart';
import '../services/promotion_banner_service.dart';
import '../widgets/promotion_banner_widget.dart';
import '../widgets/promotion_banner_carousel.dart';
import '../models/promotion_banner_model.dart';
import '../services/loyalty_service.dart';
import '../widgets/loyalty_tier_widget.dart';
import '../models/loyalty_model.dart';
import '../services/notification_preference_service.dart';
import '../widgets/smart_notification_widget.dart';
import '../models/notification_preference_model.dart';
import 'notification_settings_screen.dart';
import 'notification_history_screen.dart';
import 'scheduled_orders_screen.dart';
import 'social_media_screen.dart';
import 'ai_recommendations_screen.dart';
import 'business_chat_list_screen.dart';
import '../widgets/social_share_widget.dart';
import '../widgets/floating_share_button.dart';
import '../widgets/ai_recommendations_widget.dart';
import '../services/social_media_service.dart';
import '../models/business_model.dart' as business_model;

class HomeScreenNew extends StatefulWidget {
  const HomeScreenNew({Key? key}) : super(key: key);

  @override
  State<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends State<HomeScreenNew> {
  int _currentIndex = 0;
  final _authService = AuthService();
  final _notificationService = NotificationService();
  final _cartService = CartService();
  final _favoritesService = FavoritesService();
  final _bannerService = PromotionBannerService();
  final _loyaltyService = LoyaltyService();
  final _notificationPreferenceService = NotificationPreferenceService();
  User? _currentUser;
  Map<String, dynamic>? _userData;
  
  // Datos para el dashboard
  int _activeOrdersCount = 0;
  int _favoriteBusinessesCount = 0;
  List<DocumentSnapshot> _recentOrders = [];
  List<DocumentSnapshot> _featuredBusinesses = [];
  
  // Banners promocionales
  List<PromotionBanner> _heroBanners = [];
  List<PromotionBanner> _carouselBanners = [];
  List<PromotionBanner> _flashBanners = [];
  
  // Datos de lealtad
  UserLoyalty? _userLoyalty;
  LoyaltyProgram? _loyaltyProgram;
  
  // Datos de notificaciones
  NotificationProfile? _notificationProfile;
  List<NotificationPreference> _notificationPreferences = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboardData();
    
    // Configurar callbacks de notificaciones
    _notificationService.onOrderNotificationTap = _handleOrderNotificationTap;
    _notificationService.onChatNotificationTap = _handleChatNotificationTap;
    
    _authService.authStateChanges.listen((User? user) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        _loadUserData();
        _loadDashboardData();
        _notificationService.initialize();
      } else {
        setState(() {
          _userData = null;
        });
      }
    });
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      setState(() {
        _currentUser = user;
        _userData = data;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (_currentUser == null) return;

    try {
      // Cargar datos de lealtad
      await _loadLoyaltyData();

      // Cargar datos de notificaciones
      await _loadNotificationData();

      // Cargar banners promocionales
      await _loadBanners();

      // Cargar pedidos activos
      final activeOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: _currentUser!.uid)
          .where('status', whereIn: ['pending', 'confirmed', 'ready_for_pickup', 'on_way'])
          .get();

      // Cargar negocios favoritos
      final favoriteBusinesses = await _favoritesService.getFavoriteBusinesses();
      setState(() {
        _favoriteBusinessesCount = favoriteBusinesses.length;
      });

      // Cargar pedidos recientes
      final recentOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: _currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      // Cargar negocios destacados
      final featuredSnapshot = await FirebaseFirestore.instance
          .collection('businesses')
          .where('isActive', isEqualTo: true)
          .where('isFeatured', isEqualTo: true)
          .orderBy('rating', descending: true)
          .limit(6)
          .get();

      setState(() {
        _activeOrdersCount = activeOrdersSnapshot.docs.length;
        _recentOrders = recentOrdersSnapshot.docs;
        _featuredBusinesses = featuredSnapshot.docs;
      });
    } catch (e) {
      print('Error cargando datos del dashboard: $e');
    }
  }

  void _handleOrderNotificationTap(String orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderTrackingScreen(orderId: orderId),
      ),
    );
  }

  void _handleChatNotificationTap(String conversationId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(conversationId: conversationId),
      ),
    );
  }

  Future<void> _loadLoyaltyData() async {
    try {
      final program = await _loyaltyService.getActiveProgram().first;
      final userLoyalty = _currentUser != null 
          ? await _loyaltyService.getUserLoyalty(_currentUser!.uid).first
          : null;
      
      setState(() {
        _loyaltyProgram = program;
        _userLoyalty = userLoyalty;
      });
    } catch (e) {
      print('Error loading loyalty data: $e');
    }
  }

  Future<void> _loadNotificationData() async {
    try {
      final profile = await _notificationPreferenceService.getCurrentUserProfile().first;
      final preferences = await _notificationPreferenceService.getCurrentUserPreferences().first;
      
      setState(() {
        _notificationProfile = profile;
        _notificationPreferences = preferences;
      });
    } catch (e) {
      print('Error loading notification data: $e');
    }
  }

  Future<void> _loadBanners() async {
    try {
      final heroBanners = await _bannerService.getHeroBanners().first;
      final carouselBanners = await _bannerService.getCarouselBanners().first;
      final flashBanners = await _bannerService.getFlashBanners().first;
      
      setState(() {
        _heroBanners = heroBanners;
        _carouselBanners = carouselBanners;
        _flashBanners = flashBanners;
      });
    } catch (e) {
      print('Error loading banners: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días ☀️';
    if (hour < 18) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.red,
              elevation: 0,
              expandedHeight: 200,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.red.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userData?['name'] ?? 'Usuario',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Barra de búsqueda rápida
                          TextField(
                            onTap: () {
                              setState(() {
                                _currentIndex = 1;
                              });
                            },
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Buscar negocios o productos...',
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    // Navegar a pantalla de notificaciones
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    switch (value) {
                      case 'theme':
                        themeService.toggleTheme();
                        break;
                      case 'support':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SupportConversationsScreen(),
                          ),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'theme',
                      child: Row(
                        children: [
                          Icon(
                            themeService.isDarkMode 
                                ? Icons.light_mode 
                                : Icons.dark_mode,
                          ),
                          const SizedBox(width: 8),
                          Text(themeService.isDarkMode ? 'Modo claro' : 'Modo oscuro'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'support',
                      child: Row(
                        children: const [
                          Icon(Icons.support_agent),
                          SizedBox(width: 8),
                          Text('Soporte'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
        body: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _currentIndex == 0 ? _buildFloatingActions() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return EnhancedSearchScreen();
      case 2:
        return const OrderHistoryScreen();
      case 3:
        return _buildProfileBody();
      default:
        return _buildHomeBody();
    }
  }

  Widget _buildHomeBody() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banners promocionales
            _buildPromotionalBanners(),
            const SizedBox(height: 20),

            // Tarjetas rápidas
            _buildQuickStatsCards(),
            const SizedBox(height: 20),

            // Widget de lealtad
            if (_userLoyalty != null && _loyaltyProgram != null)
              _buildLoyaltyWidget(),
            const SizedBox(height: 20),

            // Widget de notificaciones inteligentes
            if (_notificationProfile != null)
              SmartNotificationWidget(),
            const SizedBox(height: 20),

            // Acciones rápidas
            _buildQuickActions(),
            const SizedBox(height: 20),

            // Negocios destacados
            _buildFeaturedBusinesses(),
            const SizedBox(height: 20),

            // Pedidos recientes
            _buildRecentOrders(),
            const SizedBox(height: 20),

            // Recomendaciones
            _buildRecommendationsPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pedidos Activos',
            '$_activeOrdersCount',
            Icons.pending_actions,
            Colors.orange,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OrdersScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Favoritos',
            '$_favoriteBusinessesCount',
            Icons.favorite,
            Colors.pink,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FavoritesScreen(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildActionButton(
                'Explorar',
                Icons.explore,
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedSearchScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildActionButton(
                'Cerca de Mí',
                Icons.location_on,
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NearbyBusinessesScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildActionButton(
                'Cupones',
                Icons.local_offer,
                Colors.purple,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CouponsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _buildActionButton(
                'Referidos',
                Icons.share,
                Colors.teal,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReferralScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedBusinesses() {
    if (_featuredBusinesses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Negocios Destacados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusinessListScreen(category: 'Todos'),
                  ),
                );
              },
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredBusinesses.length,
            itemBuilder: (context, index) {
              return _buildBusinessCard(_featuredBusinesses[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessCard(DocumentSnapshot businessDoc) {
    final businessData = businessDoc.data() as Map<String, dynamic>;
    final businessId = businessDoc.id;
    final name = businessData['name'] ?? 'Negocio';
    final rating = (businessData['rating'] ?? 0.0).toDouble();
    final deliveryTime = businessData['deliveryTime'] ?? '30-45 min';
    final imageUrl = businessData['imageUrl'] ?? '';
    final isFavorite = _favoritesService.isFavoriteSimple(businessId);

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 3,
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/business_detail', arguments: businessId);
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        color: Colors.grey[200],
                      ),
                      child: imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.store, size: 30, color: Colors.grey),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.store, size: 30, color: Colors.grey),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          _favoritesService.toggleFavorite(businessId);
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: FutureBuilder<bool>(
                            future: _favoritesService.isFavoriteSimple(businessId),
                            builder: (context, snapshot) {
                              final isFavorite = snapshot.data ?? false;
                              return Icon(
                                isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: isFavorite ? Colors.red : Colors.grey,
                                size: 16,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const Spacer(),
                        Text(
                          deliveryTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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

  Widget _buildRecentOrders() {
    if (_recentOrders.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pedidos Recientes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 2;
                });
              },
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._recentOrders.map((orderDoc) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final businessName = orderData['businessName'] ?? 'Negocio';
          final totalAmount = (orderData['totalAmount'] ?? 0.0).toDouble();
          final status = orderData['status'] ?? 'pending';
          final createdAt = (orderData['createdAt'] as Timestamp?)?.toDate();

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withOpacity(0.1),
                child: const Icon(Icons.receipt_long, color: Colors.red),
              ),
              title: Text(businessName),
              subtitle: Text(
                createdAt != null 
                    ? DateFormat('dd/MM/yyyy - HH:mm').format(createdAt)
                    : 'Fecha desconocida',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    _getOrderStatusText(status),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getOrderStatusColor(status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderTrackingScreen(orderId: orderDoc.id),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildRecommendationsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recomendado para Ti',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecommendationsScreen(),
                  ),
                );
              },
              child: const Text('Ver más'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.blue],
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.recommend, size: 40, color: Colors.purple[600]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Descubre negocios personalizados',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Basados en tus pedidos anteriores y preferencias',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.purple[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.purple[600]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersBody() {
    return const OrdersScreen();
  }

  Widget _buildProfileBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Información del usuario
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.red.withOpacity(0.1),
                    child: Text(
                      _userData?['name']?.substring(0, 1).toUpperCase() ?? 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userData?['name'] ?? 'Usuario',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _userData?['email'] ?? 'email@example.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfileScreen(userData: _userData ?? {}),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Opciones del perfil
          _buildProfileOption(
            'Direcciones',
            Icons.location_on,
            Colors.blue,
            () => Navigator.pushNamed(context, '/addresses'),
          ),
          _buildProfileOption(
            'Métodos de Pago',
            Icons.payment,
            Colors.green,
            () {
              // Navegar a métodos de pago
            },
          ),
          _buildProfileOption(
            'Historial de Pedidos',
            Icons.history,
            Colors.orange,
            () {
              setState(() {
                _currentIndex = 2;
              });
            },
          ),
          _buildProfileOption(
            'Favoritos',
            Icons.favorite,
            Colors.pink,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FavoritesScreen(),
              ),
            ),
          ),
          _buildProfileOption(
            'Soporte',
            Icons.support_agent,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupportConversationsScreen(),
              ),
            ),
          ),
          _buildProfileOption(
            'Configuración',
            Icons.settings,
            Colors.grey,
            () {
              // Navegar a configuración
            },
          ),
          _buildProfileOption(
            'Notificaciones',
            Icons.notifications,
            Colors.red,
            () => Navigator.pushNamed(context, '/notification_settings'),
          ),
          _buildProfileOption(
            'Cerrar Sesión',
            Icons.logout,
            Colors.red,
            () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Explorar',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Pedidos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }

  String _getOrderStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmado';
      case 'ready_for_pickup':
        return 'Listo';
      case 'on_way':
        return 'En camino';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.green;
      case 'on_way':
        return Colors.purple;
      case 'delivered':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPromotionalBanners() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner principal (Hero)
        if (_heroBanners.isNotEmpty)
          PromotionBannerWidget(
            banner: _heroBanners.first,
            margin: const EdgeInsets.only(bottom: 16),
          ),
        
        // Carrusel de banners
        if (_carouselBanners.isNotEmpty)
          PromotionBannerCarousel(
            banners: _carouselBanners,
            height: 150,
            autoPlay: true,
            margin: const EdgeInsets.only(bottom: 16),
          ),
        
        // Banners flash
        if (_flashBanners.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Ofertas Flash',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              ..._flashBanners.take(3).map((banner) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PromotionBannerWidget(
                    banner: banner,
                    margin: EdgeInsets.zero,
                  ),
                );
              }).toList(),
            ],
          ),
        
        // Botón ver todas las promociones
        if (_heroBanners.isNotEmpty || _carouselBanners.isNotEmpty || _flashBanners.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PromotionBannersScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.local_offer),
              label: const Text('Ver todas las promociones'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoyaltyWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                Colors.amber[400]!,
                Colors.amber[600]!,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Programa de Lealtad',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/loyalty');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Colors.white),
                        ),
                      ),
                      child: const Text(
                        'Ver más',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Nivel y puntos
                Row(
                  children: [
                    // Widget del nivel
                    LoyaltyTierWidget(
                      currentTier: _userLoyalty!.currentTier,
                      currentPoints: _userLoyalty!.currentPoints,
                      pointsToNextTier: _userLoyalty!.pointsToNextTier,
                      progress: _userLoyalty!.progressToNextTier,
                      size: 80,
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Información
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nivel ${_userLoyalty!.currentTier.displayName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_userLoyalty!.currentPoints} puntos',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          if (_userLoyalty!.currentTier != LoyaltyTier.diamond) ...[
                            const SizedBox(height: 8),
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: _userLoyalty!.progressToNextTier,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${_userLoyalty!.pointsToNextTier} para siguiente nivel',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Streak
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_userLoyalty!.streakDays} días seguidos',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¡Sigue activo!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de programar pedidos
        FloatingActionButton(
          heroTag: "schedule",
          onPressed: () {
            Navigator.pushNamed(context, '/scheduled_orders');
          },
          backgroundColor: Colors.purple,
          child: const Icon(Icons.schedule, color: Colors.white),
        ),
        const SizedBox(height: 12),
        // Botón de chat con negocios
        FloatingActionButton(
          heroTag: "chat",
          onPressed: () {
            Navigator.pushNamed(context, '/business_chat');
          },
          backgroundColor: Colors.green,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
        const SizedBox(height: 12),
        // Botón de recomendaciones IA
        FloatingActionButton(
          heroTag: "ai",
          onPressed: () {
            Navigator.pushNamed(context, '/ai_recommendations');
          },
          backgroundColor: Colors.blue,
          child: const Icon(Icons.psychology, color: Colors.white),
        ),
      ],
    );
  }
}
