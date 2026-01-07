// ============================================================================
// widgets/detailed_recommendation_card.dart - Versión funcional y simplificada
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/ai_recommendation_service.dart';
import '../models/business_model.dart' as business_model;

class DetailedRecommendationCard extends StatefulWidget {
  final Recommendation recommendation;
  final String userId;
  final Function(String businessId)? onBusinessTap;
  final Function(bool)? onFeedback;

  const DetailedRecommendationCard({
    Key? key,
    required this.recommendation,
    required this.userId,
    this.onBusinessTap,
    this.onFeedback,
  }) : super(key: key);

  @override
  State<DetailedRecommendationCard> createState() => _DetailedRecommendationCardState();
}

class _DetailedRecommendationCardState extends State<DetailedRecommendationCard> {
  bool _isExpanded = false;
  bool _showFeedbackButtons = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          
          // Contenido expandible
          _buildContent(),
          
          // Botones de feedback
          if (_showFeedbackButtons) _buildFeedbackButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
          if (_isExpanded) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _showFeedbackButtons = true;
                });
              }
            });
          }
        });
      },
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Imagen del negocio
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: widget.recommendation.business.imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: widget.recommendation.business.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.store,
                            color: Colors.grey[400],
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.store,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            
            // Información principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.recommendation.business.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Badge de tipo
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(widget.recommendation.type),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getTypeLabel(widget.recommendation.type),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.recommendation.reason,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Score
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.psychology,
                              color: Colors.purple,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${(widget.recommendation.score * 100).toStringAsFixed(0)}% match',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rating
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.recommendation.business.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_isExpanded) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información del negocio
          Text(
            'Información del negocio',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Categorías
          if (widget.recommendation.business.categories.isNotEmpty) ...[
            const Text(
              'Categorías',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: widget.recommendation.business.categories.map((category) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.blue,
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
          ],
          
          // Información adicional
          Row(
            children: [
              if (widget.recommendation.business.averageDeliveryTime != null) ...[
                Icon(
                  Icons.access_time,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.recommendation.business.averageDeliveryTime} min',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
              ],
              if (widget.recommendation.business.deliveryFee != null) ...[
                Icon(
                  Icons.delivery_dining,
                  color: Colors.grey[600],
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '\$${widget.recommendation.business.deliveryFee}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Te gusta esta recomendación?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _saveFeedback(true),
                  icon: const Icon(Icons.thumb_up, size: 16),
                  label: const Text('Me gusta'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveFeedback(false),
                  icon: const Icon(Icons.thumb_down, size: 16),
                  label: const Text('No me gusta'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveFeedback(bool liked) async {
    try {
      // Aquí iría el servicio para guardar feedback
      widget.onFeedback?.call(liked);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            liked ? '¡Gracias! Tu feedback ayudará a mejorar las recomendaciones.' : 'Gracias por tu feedback. Lo usaremos para mejorar.',
          ),
          backgroundColor: liked ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar feedback: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getTypeColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.content_based:
        return Colors.blue;
      case RecommendationType.collaborative:
        return Colors.green;
      case RecommendationType.time_based:
        return Colors.orange;
      case RecommendationType.location_based:
        return Colors.purple;
      case RecommendationType.hybrid:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getTypeLabel(RecommendationType type) {
    switch (type) {
      case RecommendationType.content_based:
        return 'Basado en contenido';
      case RecommendationType.collaborative:
        return 'Colaborativo';
      case RecommendationType.time_based:
        return 'Basado en tiempo';
      case RecommendationType.location_based:
        return 'Basado en ubicación';
      case RecommendationType.hybrid:
        return 'Híbrido';
      default:
        return 'Desconocido';
    }
  }
}
