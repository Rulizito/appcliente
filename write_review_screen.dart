// ============================================================================
// screens/write_review_screen.dart - Pantalla Mejorada para Escribir Reseñas
// ============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/review_model.dart';
import '../services/review_service.dart';
import '../services/auth_service.dart';
import '../widgets/rating_stars_widget.dart';
import '../widgets/image_upload_widget.dart';

class WriteReviewScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String? orderId; // Opcional - si es reseña de pedido

  const WriteReviewScreen({
    Key? key,
    required this.businessId,
    required this.businessName,
    this.orderId,
  }) : super(key: key);

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  final _reviewService = ReviewService();
  final _authService = AuthService();
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  
  int _selectedRating = 0;
  bool _isRecommended = true;
  bool _isLoading = false;
  List<String> _selectedImages = [];
  List<String> _selectedTags = [];
  
  // Calificación por aspectos
  Map<String, int> _aspectRatings = {
    'Comida': 0,
    'Servicio': 0,
    'Envío': 0,
    'Precio': 0,
    'Presentación': 0,
  };

  // Tags disponibles
  final List<String> _availableTags = [
    'Rápido',
    'Buen servicio',
    'Calidad',
    'Buen precio',
    'Limpio',
    'Amable',
    'Puntual',
    'Delicioso',
    'Buenas porciones',
    'Bien empaquetado',
    'Fresco',
    'Variedad',
    'Recomendable',
    'Volveré',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_selectedRating == 0) {
      _showMessage('Por favor seleccioná una calificación', Colors.orange);
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      _showMessage('Por favor escribí un título', Colors.orange);
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      _showMessage('Por favor escribí un comentario', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _reviewService.createReview(
        businessId: widget.businessId,
        businessName: widget.businessName,
        rating: _selectedRating,
        title: _titleController.text.trim(),
        comment: _commentController.text.trim(),
        orderId: widget.orderId,
        images: _selectedImages,
        tags: _selectedTags,
        isRecommended: _isRecommended,
        aspects: _aspectRatings,
      );

      if (result['success']) {
        _showMessage('Reseña publicada exitosamente', Colors.green);
        Navigator.pop(context, true);
      } else {
        _showMessage(result['message'] ?? 'Error al publicar reseña', Colors.red);
      }
    } catch (e) {
      _showMessage('Error al publicar reseña: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        if (_selectedTags.length < 5) { // Límite de 5 tags
          _selectedTags.add(tag);
        } else {
          _showMessage('Máximo 5 tags permitidos', Colors.orange);
        }
      }
    });
  }

  void _updateAspectRating(String aspect, int rating) {
    setState(() {
      _aspectRatings[aspect] = rating;
    });
  }

  Future<void> _pickImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 600,
      );

      if (images != null) {
        setState(() {
          // Limitar a 3 imágenes
          final remainingSlots = 3 - _selectedImages.length;
          if (images.length > remainingSlots) {
            _showMessage('Máximo 3 imágenes permitidas', Colors.orange);
            _selectedImages.addAll(images.take(remainingSlots).map((img) => img.path));
          } else {
            _selectedImages.addAll(images.map((img) => img.path));
          }
        });
      }
    } catch (e) {
      _showMessage('Error al seleccionar imágenes: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reseñar ${widget.businessName}'),
        backgroundColor: Colors.red,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitReview,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Publicar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calificación general
            _buildSection(
              title: 'Calificación General',
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '$_selectedRating',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¿Qué tal tu experiencia?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RatingStarsWidget(
                              rating: _selectedRating,
                              size: 40,
                              interactive: true,
                              onRatingChanged: (rating) {
                                setState(() {
                                  _selectedRating = rating;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _isRecommended,
                        onChanged: (value) {
                          setState(() {
                            _isRecommended = value ?? true;
                          });
                        },
                        activeColor: Colors.red,
                      ),
                      const Text('Recomiendo este negocio'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Calificación por aspectos
            _buildSection(
              title: 'Calificación por Aspectos',
              child: Column(
                children: _aspectRatings.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: RatingStarsWidget(
                            rating: entry.value,
                            size: 24,
                            interactive: true,
                            onRatingChanged: (rating) {
                              _updateAspectRating(entry.key, rating);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Título y comentario
            _buildSection(
              title: 'Tu Reseña',
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título de la reseña',
                      hintText: 'Ej: Excelente servicio y comida deliciosa',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 100,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Comentario detallado',
                      hintText: 'Contanos más sobre tu experiencia...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    maxLength: 500,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tags
            _buildSection(
              title: 'Tags (máximo 5)',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => _toggleTag(tag),
                    backgroundColor: Colors.grey[200],
                    selectedColor: Colors.red.withOpacity(0.2),
                    checkmarkColor: Colors.red,
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Imágenes
            _buildSection(
              title: 'Fotos (máximo 3)',
              child: Column(
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _selectedImages.length < 3 ? _pickImages : null,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Agregar fotos'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text('${_selectedImages.length}/3'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_selectedImages.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedImages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final imagePath = entry.value;
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(imagePath)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  onPressed: () => _removeImage(index),
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  padding: const EdgeInsets.all(4),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Botón de envío
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Publicar Reseña',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
