// ============================================================================
// widgets/review_card_widget.dart - Widget de Tarjeta de Reseña
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/review_model.dart';
import '../widgets/rating_stars_widget.dart';
import 'package:intl/intl.dart';

class ReviewCardWidget extends StatelessWidget {
  final Review review;
  final VoidCallback? onHelpfulPressed;
  final VoidCallback? onReplyPressed;
  final bool showBusinessResponse;

  const ReviewCardWidget({
    Key? key,
    required this.review,
    this.onHelpfulPressed,
    this.onReplyPressed,
    this.showBusinessResponse = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con usuario y calificación
            Row(
              children: [
                // Avatar del usuario
                CircleAvatar(
                  radius: 20,
                  backgroundImage: review.userPhoto != null
                      ? CachedNetworkImageProvider(review.userPhoto!)
                      : null,
                  child: review.userPhoto == null
                      ? Text(
                          review.userName.isNotEmpty
                              ? review.userName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                  backgroundColor: Colors.grey[400],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (review.isVerifiedReview) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              color: Colors.green,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          RatingStarsWidget(
                            rating: review.rating,
                            size: 14,
                            showRating: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            review.formattedDate,
                            style: TextStyle(
                              fontSize: 12,
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
            
            const SizedBox(height: 12),
            
            // Título de la reseña
            if (review.title.isNotEmpty) ...[
              Text(
                review.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            // Comentario
            Text(
              review.comment,
              style: const TextStyle(fontSize: 14),
            ),
            
            // Tags
            if (review.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: review.tags.map((tag) {
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
            
            // Calificación por aspectos
            if (review.aspects.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...review.aspects.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '${entry.key}:',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      RatingStarsWidget(
                        rating: entry.value,
                        size: 12,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            
            // Imágenes
            if (review.hasImages) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  itemBuilder: (context, index) {
                    final imageUrl = review.images[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _showImageDialog(context, imageUrl);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: const Icon(Icons.error),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // Recomendación
            if (review.isRecommended) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.thumb_up,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Recomienda este negocio',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            
            // Respuesta del negocio
            if (showBusinessResponse && review.hasResponse) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.store,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Respuesta del negocio',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review.response!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (review.responseDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(review.responseDate!),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            
            // Acciones
            const SizedBox(height: 12),
            Row(
              children: [
                // Botón de útil
                TextButton.icon(
                  onPressed: onHelpfulPressed,
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text(
                    'Útil (${review.helpfulCount})',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Botón de respuesta (para negocios)
                if (onReplyPressed != null) ...[
                  TextButton.icon(
                    onPressed: onReplyPressed,
                    icon: const Icon(Icons.reply, size: 16),
                    label: const Text(
                      'Responder',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
                
                const Spacer(),
                
                // Indicador de verificación
                if (review.isVerifiedReview)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          color: Colors.green,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Verificada',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
