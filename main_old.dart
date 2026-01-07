// ============================================================================
// main.dart - ACTUALIZADO CON NOTIFICACIONES Y MODO OSCURO
// ============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Importar pantallas
import 'screens/home_screen_new.dart';
import 'screens/business_detail_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/promotion_banners_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/notification_center_screen.dart';
import 'screens/scheduled_orders_screen.dart';
import 'screens/social_media_screen.dart';
import 'screens/ai_recommendations_screen.dart';
import 'screens/business_chat_list_screen.dart';
import 'screens/payment_methods_screen.dart';
import 'screens/add_payment_method_screen.dart';
import 'screens/write_review_screen.dart';
import 'screens/business_reviews_screen_new.dart';

// Importar servicios
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/payment_service.dart';
import 'services/mercado_pago_service.dart';
import 'services/auth_service.dart';
import 'services/enhanced_notification_service.dart';
import 'services/theme_service.dart';
import 'services/advanced_search_service.dart';
import 'services/order_history_service.dart';
import 'services/promotion_banner_service.dart';
import 'screens/loyalty_screen.dart';
import '../services/loyalty_service.dart';
import 'screens/notification_center_screen.dart';
import '../services/notification_preference_service.dart';
import '../services/notification_schedule_service.dart';
import '../services/notification_analytics_service.dart';
import '../models/notification_preference_model.dart';
import '../models/notification_template_model.dart';
import 'screens/scheduled_orders_screen.dart';
import 'screens/social_media_screen.dart';
import 'screens/ai_recommendations_screen.dart';
import 'screens/business_chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Inicializar servicios
  await NotificationService().initialize();
  await EnhancedNotificationService().initialize();
  final themeService = ThemeService();
  await themeService.loadThemePreference();
  
  runApp(
    ChangeNotifierProvider.value(
      value: themeService,
      child: const DeliveryApp(),
    ),
  );
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      title: 'Delivery App',
      debugShowCheckedModeBanner: false,
      theme: themeService.lightTheme,
      darkTheme: themeService.darkTheme,
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreenNew(),
      routes: {
        '/business_detail': (context) {
          final businessId = ModalRoute.of(context)?.settings.arguments as String?;
          if (businessId != null) {
            return BusinessDetailScreen(businessId: businessId, businessName: '');
          } else {
            return const Scaffold(
              body: Center(
                child: Text('Error: ID de negocio no proporcionado'),
              ),
            );
          }
        },
        '/write_review': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          if (args != null) {
            return WriteReviewScreen(
              businessId: args['businessId']!,
              businessName: args['businessName']!,
              orderId: args['orderId'],
            );
          } else {
            return const Scaffold(
              body: Center(
                child: Text('Error: Argumentos no proporcionados'),
              ),
            );
          }
        },
        '/business_reviews': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
          if (args != null) {
            return BusinessReviewsScreen(
              businessId: args['businessId']!,
              businessName: args['businessName']!,
            );
          } else {
            return const Scaffold(
              body: Center(
                child: Text('Error: Argumentos no proporcionados'),
              ),
            );
          }
        },
        '/order_history': (context) => const OrderHistoryScreen(),
        '/promotion_banners': (context) => const PromotionBannersScreen(),
        '/loyalty': (context) => LoyaltyScreen(),
        '/notification_center': (context) => const NotificationCenterScreen(),
        '/scheduled_orders': (context) => const ScheduledOrdersScreen(),
        '/social_media': (context) => const SocialMediaScreen(),
        '/ai_recommendations': (context) => const AIRecommendationsScreen(),
        '/business_chat': (context) => const BusinessChatListScreen(),
        '/payment_methods': (context) => PaymentMethodsScreen(),
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _authService = AuthService();
  final _notificationService = NotificationService();
  User? _currentUser;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    
    // Configurar callbacks de notificaciones
    _notificationService.onOrderNotificationTap = _handleOrderNotificationTap;
    _notificationService.onChatNotificationTap = _handleChatNotificationTap;
    
    _authService.authStateChanges.listen((User? user) {
      setState(() {
        _currentUser = user;
      });
      if (user != null) {
        _loadUserData();
        // Re-inicializar notificaciones cuando el usuario inicie sesión
        _notificationService.initialize();
      } else {
        setState(() {
          _userData = null;
        });
      }
    });
  }

  void _handleNotificationTap(String orderId) {
    print('🔔 Usuario tocó notificación del pedido: $orderId');
    
    // Mostrar mensaje simple por ahora
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pedido $orderId actualizado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleOrderNotificationTap(String orderId) {
    print('🔔 Usuario tocó notificación del pedido: $orderId');
    
    // Mostrar mensaje simple por ahora
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pedido $orderId actualizado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleChatNotificationTap(String conversationId) {
    print('💬 Usuario tocó notificación del chat: $conversationId');
    
    // Mostrar mensaje simple por ahora
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nuevo mensaje en chat $conversationId'),
        duration: const Duration(seconds: 2),
      ),
    );
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

  String _getTitle() {
    switch (_currentIndex) {
      case 0:
        return '¿Qué querés pedir?';
      case 1:
        return 'Buscar';
      case 2:
        return 'Mis Pedidos';
      case 3:
        return 'Perfil';
      default:
        return 'Delivery App';
    }
  }

  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return const Center(child: Text('Búsqueda - En desarrollo'));
      case 2:
        return const Center(child: Text('Pedidos - En desarrollo'));
      case 3:
        return _buildProfileBody();
      default:
        return _buildHomeBody();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 1 ? null : AppBar(
        title: Text(_getTitle()),
        elevation: 0,
        backgroundColor: Colors.red,
        actions: _currentIndex == 0 ? [
          // Botón de prueba de notificaciones (solo en desarrollo)
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: () {
              _notificationService.testNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notificación de prueba enviada'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Probar notificación',
          ),
        ] : null,
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.red,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Buscar',
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
      ),
    );
  }

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner de búsqueda
          Container(
            color: Colors.red,
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = 1;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Buscar restaurantes, productos...',
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Text(
              'Categorías',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              CategoryCard(
                title: 'Cercanos',
                icon: Icons.near_me,
                color: Colors.deepPurple,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cercanos - En desarrollo')),
                  );
                },
              ),
              CategoryCard(
                title: 'Restaurantes',
                icon: Icons.restaurant,
                color: Colors.orange,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Restaurantes - En desarrollo')),
                  );
                },
              ),
              CategoryCard(
                title: 'Supermercado',
                icon: Icons.shopping_cart,
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supermercado - En desarrollo')),
                  );
                },
              ),
              CategoryCard(
                title: 'Farmacia',
                icon: Icons.local_pharmacy,
                color: Colors.blue,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Farmacia - En desarrollo')),
                  );
                },
              ),
              CategoryCard(
                title: 'Mascotas',
                icon: Icons.pets,
                color: Colors.purple,
                onTap: () {

      Widget _getBody() {
        switch (_currentIndex) {
          case 0:
            return _buildHomeBody();
          case 1:
            return const Center(child: Text('Búsqueda - En desarrollo'));
          case 2:
            return const Center(child: Text('Pedidos - En desarrollo'));
          case 3:
            return _buildProfileBody();
          default:
            return _buildHomeBody();
        }
      }

      @override
      Widget build(BuildContext context) {
        return Scaffold(
          appBar: _currentIndex == 1 ? null : AppBar(
            title: Text(_getTitle()),
            elevation: 0,
            backgroundColor: Colors.red,
            actions: _currentIndex == 0 ? [
              // Botón de prueba de notificaciones (solo en desarrollo)
              IconButton(
                icon: const Icon(Icons.notifications_active),
                onPressed: () {
                  _notificationService.testNotification();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificación de prueba enviada'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                tooltip: 'Probar notificación',
              ),
            ] : null,
          ),
          body: _getBody(),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.red,
            unselectedItemColor: Colors.grey,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Buscar',
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
          ),
        );
      }

      Widget _buildHomeBody() {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner de búsqueda
              Container(
                color: Colors.red,
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        hintText: 'Buscar restaurantes, productos...',
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Categorías',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  CategoryCard(
                    title: 'Cercanos',
                    icon: Icons.near_me,
                    color: Colors.deepPurple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cercanos - En desarrollo')),
                      );
                    },
                  ),
                  CategoryCard(
                    title: 'Restaurantes',
                    icon: Icons.restaurant,
                    color: Colors.orange,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restaurantes - En desarrollo')),
                      );
                    },
                  ),
                  CategoryCard(
                    title: 'Supermercado',
                    icon: Icons.shopping_cart,
                    color: Colors.green,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Supermercado - En desarrollo')),
                      );
                    },
                  ),
                  CategoryCard(
                    title: 'Farmacia',
                    icon: Icons.local_pharmacy,
                    color: Colors.blue,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Farmacia - En desarrollo')),
                      );
                    },
                  ),
                  CategoryCard(
                    title: 'Mascotas',
                    icon: Icons.pets,
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Mascotas - En desarrollo')),
                      );
                    },
                  ),
                  CategoryCard(
                    title: 'Bebidas',
                    icon: Icons.local_drink,
                    color: Colors.amber,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bebidas - En desarrollo')),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  'Funciones',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  CategoryCard(
                    title: 'Mis Pedidos',
                    icon: Icons.receipt_long,
                    color: Colors.red,
                    onTap: () {
                      setState(() {
                        _currentIndex = 2;
                      });
                    },
                  ),
                  CategoryCard(
                    title: 'Pagos',
                    icon: Icons.payment,
                    color: Colors.green,
                    onTap: () {
                      Navigator.pushNamed(context, '/payment_methods');
                    },
                  ),
                  CategoryCard(
                    title: 'Notificaciones',
                    icon: Icons.notifications,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pushNamed(context, '/notification_center');
                    },
                  ),
                  CategoryCard(
                    title: 'Lealtad',
                    icon: Icons.star,
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pushNamed(context, '/loyalty');
                    },
        child: Row(
          children: [
            Icon(icon, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CategoryCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE0E0E0) : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Widget para el diálogo de selección de tema
// ============================================================================

class ThemeDialog extends StatelessWidget {
  const ThemeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          const Text('Apariencia'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Opción Modo Claro
          InkWell(
            onTap: () async {
              await themeService.setTheme(false);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !themeService.isDarkMode
                    ? Colors.red.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !themeService.isDarkMode
                      ? Colors.red
                      : Colors.grey[300]!,
                  width: !themeService.isDarkMode ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.light_mode,
                      color: Colors.amber,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo Claro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tema brillante y colorido',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!themeService.isDarkMode)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.red,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Opción Modo Oscuro
          InkWell(
            onTap: () async {
              await themeService.setTheme(true);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeService.isDarkMode
                    ? Colors.red.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeService.isDarkMode
                      ? Colors.red
                      : Colors.grey[300]!,
                  width: themeService.isDarkMode ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.dark_mode,
                      color: Colors.indigo,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo Oscuro',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ideal para la noche',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (themeService.isDarkMode)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.red,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}