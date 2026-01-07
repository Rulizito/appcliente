import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'checkout_screen.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';  // ← NUEVO
import 'login_screen.dart';
import 'business_reviews_screen_new.dart';
import '../widgets/social_share_widget.dart';
import '../services/social_media_service.dart';
import '../models/business_model.dart' as business_model;

class BusinessDetailScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessDetailScreen({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _cartService = CartService();  // ← NUEVO
  
  // Lista del carrito
  Map<String, int> cart = {};
  bool _isLoadingCart = true;  // ← NUEVO

  @override
  void initState() {
    super.initState();
    _loadSavedCart();  // ← NUEVO
  }

  // ← NUEVO: Cargar carrito guardado
  Future<void> _loadSavedCart() async {
    final savedCart = await _cartService.loadCart();
    
    if (savedCart != null && savedCart['businessId'] == widget.businessId) {
      setState(() {
        cart = savedCart['items'] as Map<String, int>;
        _isLoadingCart = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🛒 Carrito recuperado: ${cart.length} productos'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      setState(() {
        _isLoadingCart = false;
      });
    }
  }

  // ← NUEVO: Guardar carrito automáticamente
  Future<void> _saveCart() async {
    if (cart.isNotEmpty) {
      await _cartService.saveCart(
        businessId: widget.businessId,
        businessName: widget.businessName,
        cart: cart,
      );
    }
  }

  // Calcular total del carrito
  double getCartTotal(List<Map<String, dynamic>> products) {
    double total = 0;
    cart.forEach((productName, quantity) {
      try {
        final product = products.firstWhere((p) => p['name'] == productName);
        total += product['price'] * quantity;
      } catch (e) {
        // Producto no encontrado
      }
    });
    return total;
  }

  // Obtener cantidad total de items
  int getTotalItems() {
    int total = 0;
    cart.forEach((_, quantity) {
      total += quantity;
    });
    return total;
  }

  // Agregar producto al carrito
  void addToCart(String productName) {
    setState(() {
      if (cart.containsKey(productName)) {
        cart[productName] = cart[productName]! + 1;
      } else {
        cart[productName] = 1;
      }
    });
    _saveCart();  // ← NUEVO: Guardar automáticamente
  }

  // Remover producto del carrito
  void removeFromCart(String productName) {
    setState(() {
      if (cart.containsKey(productName)) {
        if (cart[productName]! > 1) {
          cart[productName] = cart[productName]! - 1;
        } else {
          cart.remove(productName);
        }
      }
    });
    _saveCart();  // ← NUEVO: Guardar automáticamente
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('businessId', isEqualTo: widget.businessId)
            .where('available', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final productDocs = snapshot.data?.docs ?? [];
          final products = productDocs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          if (products.isEmpty) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: Colors.red,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(widget.businessName),
                    background: Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.menu_book,
                            size: 100,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Este negocio aún no tiene productos',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pronto agregarán su menú',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // Agrupar productos por categoría
          Map<String, List<Map<String, dynamic>>> groupedProducts = {};
          for (var product in products) {
            String category = product['category'] ?? 'Sin categoría';
            if (!groupedProducts.containsKey(category)) {
              groupedProducts[category] = [];
            }
            groupedProducts[category]!.add(product);
          }

          return CustomScrollView(
            slivers: [
              // AppBar con imagen
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: Colors.red,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _shareBusiness,
                    tooltip: 'Compartir negocio',
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(widget.businessName),
                  background: Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),

              // Información del negocio
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 20),
                              const SizedBox(width: 4),
                              const Text(
                                'Nuevo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '30 min',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(Icons.delivery_dining, color: Colors.grey[600], size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '\$50',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          // Botón de ver calificaciones
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BusinessReviewsScreen(
                                    businessId: widget.businessId,
                                    businessName: widget.businessName,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.star_border, size: 18),
                            label: const Text('Ver opiniones'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Lista de productos por categoría
              ...groupedProducts.entries.map((entry) {
                return SliverList(
                  delegate: SliverChildListDelegate([
                    // Título de categoría
                    Container(
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Productos de la categoría
                    ...entry.value.map((product) {
                      int quantity = cart[product['name']] ?? 0;
                      return ProductItem(
                        name: product['name'],
                        description: product['description'],
                        price: (product['price'] ?? 0).toInt(),
                        quantity: quantity,
                        onAdd: () => addToCart(product['name']),
                        onRemove: () => removeFromCart(product['name']),
                      );
                    }).toList(),
                  ]),
                );
              }).toList(),

              // Espacio extra al final
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),

      // Botón flotante del carrito
      bottomNavigationBar: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('businessId', isEqualTo: widget.businessId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || getTotalItems() == 0) {
            return const SizedBox.shrink();
          }

          final products = snapshot.data!.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                // Verificar autenticación ANTES de ir a checkout
                final authService = AuthService();
                final user = authService.currentUser;
  
                if (user == null) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Iniciar sesión'),
                      content: const Text('Necesitás iniciar sesión para hacer un pedido'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Iniciar sesión',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                  return;
                }
  
                // Si está autenticado, continuar a checkout
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      businessId: widget.businessId,
                      businessName: widget.businessName,
                      cart: cart,
                      products: products,
                    ),
                  ),
                ).then((_) {
                  // Limpiar carrito después de confirmar pedido
                  _cartService.clearCart();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${getTotalItems()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    'Ver carrito',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '\$${getCartTotal(products).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _shareBusiness() {
    final socialService = SocialMediaService();
    
    // Crear un modelo de negocio básico para compartir
    final business = business_model.Business(
      id: widget.businessId,
      name: widget.businessName,
      category: 'Restaurantes',
      categories: ['Restaurantes'],
      imageUrl: '', // URL por defecto para compartir
      logoUrl: '', // Logo por defecto
      address: 'Dirección por defecto',
      city: 'Ciudad por defecto',
      province: 'Provincia por defecto',
      latitude: 0.0,
      longitude: 0.0,
      rating: 4.5,
      reviewCount: 100, // Número por defecto para compartir
      averageOrderValue: 50.0,
      averageDeliveryTime: 30, // Tiempo de entrega por defecto
      description: 'Delicioso restaurante',
      phone: '',
      email: '',
      website: '',
      operatingHours: [],
      deliveryFee: 0.0,
      minDeliveryTime: 30,
      maxDeliveryTime: 60,
      freeDelivery: false,
      minOrderAmount: 0.0,
      paymentMethods: [],
      isActive: true,
      isFeatured: false,
      tags: [],
      averagePrice: 2.0,
      createdAt: DateTime.now(),
    );
    
    final content = socialService.generateBusinessContent(business);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SocialShareWidget(
        content: content,
        onShareComplete: (success) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Negocio compartido!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      ),
    );
  }
}

// Widget para cada producto
class ProductItem extends StatelessWidget {
  final String name;
  final String description;
  final int price;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const ProductItem({
    Key? key,
    required this.name,
    required this.description,
    required this.price,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          // Imagen del producto
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fastfood,
              size: 40,
              color: Colors.grey[400],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Información del producto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '\$$price',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          
          // Botones de cantidad
          if (quantity == 0)
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: const Text(
                'Agregar',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove, size: 20),
                    color: Colors.red,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add, size: 20),
                    color: Colors.red,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}