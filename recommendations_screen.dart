import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'business_detail_screen.dart';
import '../services/favorites_service.dart';
import '../services/order_service.dart';
import 'package:intl/intl.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({Key? key}) : super(key: key);

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final FavoritesService _favoritesService = FavoritesService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  List<DocumentSnapshot> _recommendations = [];
  List<DocumentSnapshot> _trendingBusinesses = [];
  List<DocumentSnapshot> _newBusinesses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Cargar recomendaciones basadas en historial de pedidos
      await _loadPersonalizedRecommendations();
      
      // Cargar negocios trending
      await _loadTrendingBusinesses();
      
      // Cargar negocios nuevos
      await _loadNewBusinesses();
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando recomendaciones: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPersonalizedRecommendations() async {
    // Obtener categorías favoritas del usuario basadas en sus pedidos
    QuerySnapshot ordersSnapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: _currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    Map<String, int> categoryCount = {};
    Set<String> orderedBusinessIds = {};

    for (var orderDoc in ordersSnapshot.docs) {
      final orderData = orderDoc.data() as Map<String, dynamic>;
      final businessId = orderData['businessId'] as String?;
      final businessCategory = orderData['businessCategory'] as String?;
      
      if (businessId != null) {
        orderedBusinessIds.add(businessId);
      }
      
      if (businessCategory != null) {
        categoryCount[businessCategory] = (categoryCount[businessCategory] ?? 0) + 1;
      }
    }

    // Obtener las categorías más ordenadas
    final sortedCategories = categoryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topCategories = sortedCategories
        .take(3)
        .map((e) => e.key)
        .toList();

    // Obtener negocios de las categorías favoritas que no haya pedido aún
    if (topCategories.isNotEmpty) {
      QuerySnapshot businessesSnapshot = await _firestore
          .collection('businesses')
          .where('category', whereIn: topCategories)
          .where('isActive', isEqualTo: true)
          .limit(10)
          .get();

      final businesses = businessesSnapshot.docs.where((doc) {
        return !orderedBusinessIds.contains(doc.id);
      }).toList();

      setState(() {
        _recommendations = businesses;
      });
    }
  }

  Future<void> _loadTrendingBusinesses() async {
    // Obtener negocios con mejor rating y más pedidos recientes
    QuerySnapshot businessesSnapshot = await _firestore
        .collection('businesses')
        .where('isActive', isEqualTo: true)
        .where('rating', isGreaterThanOrEqualTo: 4.0)
        .orderBy('rating', descending: true)
        .orderBy('orderCount', descending: true)
        .limit(8)
        .get();

    setState(() {
      _trendingBusinesses = businessesSnapshot.docs;
    });
  }

  Future<void> _loadNewBusinesses() async {
    // Obtener negocios nuevos (últimos 30 días)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    QuerySnapshot businessesSnapshot = await _firestore
        .collection('businesses')
        .where('isActive', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
        .orderBy('createdAt', descending: true)
        .limit(8)
        .get();

    setState(() {
      _newBusinesses = businessesSnapshot.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Para Ti'),
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRecommendations,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sección de recomendaciones personalizadas
                    if (_recommendations.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Basado en tus gustos',
                        Icons.recommend,
                        'Negocios similares a los que has pedido',
                      ),
                      const SizedBox(height: 12),
                      _buildHorizontalBusinessList(_recommendations),
                      const SizedBox(height: 24),
                    ],

                    // Sección de trending
                    if (_trendingBusinesses.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Populares Ahora',
                        Icons.trending_up,
                        'Los negocios más solicitados',
                      ),
                      const SizedBox(height: 12),
                      _buildHorizontalBusinessList(_trendingBusinesses),
                      const SizedBox(height: 24),
                    ],

                    // Sección de nuevos
                    if (_newBusinesses.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Nuevos Negocios',
                        Icons.new_releases,
                        'Descubre los últimos incorporados',
                      ),
                      const SizedBox(height: 12),
                      _buildHorizontalBusinessList(_newBusinesses),
                      const SizedBox(height: 24),
                    ],

                    // Mensaje si no hay recomendaciones
                    if (_recommendations.isEmpty && 
                        _trendingBusinesses.isEmpty && 
                        _newBusinesses.isEmpty)
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, String subtitle) {
    return Row(
      children: [
        Icon(icon, color: Colors.red, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalBusinessList(List<DocumentSnapshot> businesses) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: businesses.length,
        itemBuilder: (context, index) {
          return _buildBusinessCard(businesses[index], isHorizontal: true);
        },
      ),
    );
  }

  Widget _buildBusinessCard(DocumentSnapshot businessDoc, {bool isHorizontal = false}) {
    final businessData = businessDoc.data() as Map<String, dynamic>;
    final businessId = businessDoc.id;
    final name = businessData['name'] ?? 'Negocio';
    final category = businessData['category'] ?? 'Categoría';
    final rating = (businessData['rating'] ?? 0.0).toDouble();
    final deliveryTime = businessData['deliveryTime'] ?? '30-45 min';
    final deliveryFee = (businessData['deliveryFee'] ?? 0.0).toDouble();
    final imageUrl = businessData['imageUrl'] ?? '';
    final isOpen = businessData['isOpen'] as bool? ?? false;
    final isFavorite = _favoritesService.isFavoriteSimple(businessId);
    final orderCount = businessData['orderCount'] ?? 0;
    
    final cardWidth = isHorizontal ? 160.0 : double.infinity;

    return Container(
      width: cardWidth,
      margin: isHorizontal 
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BusinessDetailScreen(
                  businessId: businessId,
                  businessName: name,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
              Expanded(
                flex: 3,
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
                                    child: Icon(Icons.store, size: 40, color: Colors.grey),
                                  );
                                },
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.store, size: 40, color: Colors.grey),
                            ),
                    ),
                    
                    // Badge de estado
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOpen ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOpen ? 'Abierto' : 'Cerrado',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Badge de favorito
                    Positioned(
                      top: 8,
                      left: 8,
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
              
              // Información
              Expanded(
                flex: 2,
                child: Padding(
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
                      
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const Spacer(),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          if (orderCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$orderCount pedidos',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.explore_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '¡Empieza a explorar!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Haz algunos pedidos y te recomendaremos negocios basados en tus gustos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.search),
            label: const Text('Explorar Negocios'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
