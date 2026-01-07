// ============================================================================
// screens/business_reviews_screen.dart - Pantalla Mejorada de Reseñas de Negocio
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/review_service.dart';
import '../models/review_model.dart';
import '../widgets/rating_stars_widget.dart';
import '../widgets/review_card_widget.dart';
import '../screens/write_review_screen.dart';
import 'package:intl/intl.dart';

class BusinessReviewsScreen extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessReviewsScreen({
    Key? key,
    required this.businessId,
    required this.businessName,
  }) : super(key: key);

  @override
  State<BusinessReviewsScreen> createState() => _BusinessReviewsScreenState();
}

class _BusinessReviewsScreenState extends State<BusinessReviewsScreen> {
  final _reviewService = ReviewService();
  
  BusinessReviewStats? _stats;
  List<Review> _reviews = [];
  bool _isLoadingStats = true;
  bool _isLoadingReviews = true;
  bool _hasMoreReviews = true;
  
  DocumentSnapshot? _lastDocument;
  
  // Filtros
  int? _selectedRating;
  bool _verifiedOnly = false;
  bool _withImagesOnly = false;
  List<String> _selectedTags = [];
  String _sortBy = 'newest'; // newest, oldest, highest, lowest, helpful

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadStats(),
      _loadReviews(),
    ]);
  }

  Future<void> _loadStats() async {
    final stats = await _reviewService.getBusinessReviewStats(widget.businessId);
    setState(() {
      _stats = stats;
      _isLoadingStats = false;
    });
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoadingReviews = true;
        _reviews = [];
        _lastDocument = null;
        _hasMoreReviews = true;
      });
    }

    try {
      final reviews = await _reviewService.getBusinessReviews(
        widget.businessId,
        limit: 10,
        lastDocument: _lastDocument,
        minRating: _selectedRating,
        verifiedOnly: _verifiedOnly,
        withImages: _withImagesOnly,
        tags: _selectedTags.isNotEmpty ? _selectedTags : null,
      );

      setState(() {
        if (refresh) {
          _reviews = reviews;
        } else {
          _reviews.addAll(reviews);
        }
        
        _hasMoreReviews = reviews.length == 10;
        _isLoadingReviews = false;
        
        if (reviews.isNotEmpty) {
          _lastDocument = null; // En una implementación real, guardaríamos el último documento
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingReviews = false;
      });
    }
  }

  Future<void> _refreshData() async {
    _loadStats();
    _loadReviews(refresh: true);
  }

  void _applyFilters() {
    _loadReviews(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _selectedRating = null;
      _verifiedOnly = false;
      _withImagesOnly = false;
      _selectedTags = [];
      _sortBy = 'newest';
    });
    _applyFilters();
  }

  void _sortReviews() {
    setState(() {
      switch (_sortBy) {
        case 'newest':
          _reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'oldest':
          _reviews.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'highest':
          _reviews.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'lowest':
          _reviews.sort((a, b) => a.rating.compareTo(b.rating));
          break;
        case 'helpful':
          _reviews.sort((a, b) => b.helpfulCount.compareTo(a.helpfulCount));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reseñas de ${widget.businessName}'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortReviews();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'newest',
                child: Text('Más recientes'),
              ),
              const PopupMenuItem(
                value: 'oldest',
                child: Text('Más antiguas'),
              ),
              const PopupMenuItem(
                value: 'highest',
                child: Text('Mejor calificadas'),
              ),
              const PopupMenuItem(
                value: 'lowest',
                child: Text('Peor calificadas'),
              ),
              const PopupMenuItem(
                value: 'helpful',
                child: Text('Más útiles'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Column(
          children: [
            // Estadísticas
            if (_stats != null) _buildStatsSection(),
            
            // Filtros
            _buildFiltersSection(),
            
            // Lista de reseñas
            Expanded(
              child: _buildReviewsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WriteReviewScreen(
                businessId: widget.businessId,
                businessName: widget.businessName,
              ),
            ),
          );
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.rate_review),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stats!.formattedRating,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  Text(
                    '${_stats!.totalReviews} reseñas',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: RatingDistributionWidget(
                  distribution: _stats!.ratingDistribution,
                  totalReviews: _stats!.totalReviews,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_stats!.verifiedReviews > 0) ...[
                Icon(Icons.verified, color: Colors.green, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${_stats!.verifiedPercentage.toStringAsFixed(0)}% verificadas',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 16),
              ],
              Icon(Icons.thumb_up, color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_stats!.recommendedPercentage}% recomiendan',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (_stats!.commonTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _stats!.commonTags.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: Colors.grey[200],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro por estrellas
                DropdownButton<int?>(
                  value: _selectedRating,
                  hint: const Text('Estrellas'),
                  items: [null, 5, 4, 3, 2, 1].map((rating) {
                    return DropdownMenuItem<int?>(
                      value: rating,
                      child: rating != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('$rating'),
                                const SizedBox(width: 4),
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                              ],
                            )
                          : const Text('Todas'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRating = value;
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 12),
                
                // Filtro verificadas
                FilterChip(
                  label: const Text('Solo verificadas'),
                  selected: _verifiedOnly,
                  onSelected: (value) {
                    setState(() {
                      _verifiedOnly = value;
                    });
                    _applyFilters();
                  },
                ),
                const SizedBox(width: 8),
                
                // Filtro con imágenes
                FilterChip(
                  label: const Text('Con imágenes'),
                  selected: _withImagesOnly,
                  onSelected: (value) {
                    setState(() {
                      _withImagesOnly = value;
                    });
                    _applyFilters();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_isLoadingReviews && _reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Este negocio aún no tiene reseñas',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¡Sé el primero en compartir tu experiencia!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (!_isLoadingReviews &&
            _hasMoreReviews &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadReviews();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _reviews.length + (_hasMoreReviews ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final review = _reviews[index];
          return ReviewCardWidget(
            review: review,
            onHelpfulPressed: () async {
              await _reviewService.markReviewAsHelpful(review.id);
              _refreshData();
            },
          );
        },
      ),
    );
  }
}
