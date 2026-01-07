// ============================================================================
// screens/rate_order_screen.dart
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart' as order_model;
import '../services/rating_service.dart';
import '../services/auth_service.dart';

class RateOrderScreen extends StatefulWidget {
  final order_model.Order? order;
  final String? orderId;

  const RateOrderScreen({Key? key, this.order, this.orderId}) : super(key: key);

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  final _ratingService = RatingService();
  final _authService = AuthService();
  final _commentController = TextEditingController();
  
  int _selectedStars = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedStars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccioná una calificación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Si tenemos orderId pero no order, cargamos los datos
    order_model.Order? orderToRate = widget.order;
    
    if (orderToRate == null && widget.orderId != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .get();
        
        if (doc.exists) {
          final orderData = doc.data() as Map<String, dynamic>;
          orderToRate = order_model.Order.fromMap(orderData);
        }
      } catch (e) {
        print('Error cargando pedido: $e');
      }
    }

    if (orderToRate == null) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo cargar la información del pedido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await _ratingService.createRating(
      userId: user.uid,
      userName: orderToRate.userName,
      orderId: orderToRate.id,
      businessId: orderToRate.businessId,
      businessName: orderToRate.businessName,
      stars: _selectedStars,
      comment: _commentController.text.trim().isEmpty 
          ? null 
          : _commentController.text.trim(),
    );

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
        ),
      );

      if (result['success']) {
        Navigator.pop(context, true); // Retornar true para indicar que se calificó
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si tenemos orderId pero no order, mostramos loading mientras cargamos
    if (widget.order == null && widget.orderId != null) {
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Calificar pedido'),
                backgroundColor: Colors.red,
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Calificar pedido'),
                backgroundColor: Colors.red,
              ),
              body: const Center(
                child: Text('Error: Pedido no encontrado'),
              ),
            );
          }

          try {
            final orderData = snapshot.data!.data() as Map<String, dynamic>;
            final loadedOrder = order_model.Order.fromMap(orderData);
            return _buildRatingForm(context, loadedOrder);
          } catch (e) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Calificar pedido'),
                backgroundColor: Colors.red,
              ),
              body: Center(
                child: Text('Error al cargar pedido: $e'),
              ),
            );
          }
        },
      );
    }

    // Si tenemos order, lo mostramos directamente
    if (widget.order != null) {
      return _buildRatingForm(context, widget.order!);
    }

    // Si no tenemos nada
    return const Scaffold(
      body: Center(
        child: Text('No se proporcionó información del pedido'),
      ),
    );
  }

  Widget _buildRatingForm(BuildContext context, order_model.Order order) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calificar pedido'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Icono del negocio
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store,
                size: 50,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 20),

            // Nombre del negocio
            Text(
              order.businessName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              'Pedido #${order.id.substring(0, 8)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 40),

            // Pregunta
            const Text(
              '¿Cómo fue tu experiencia?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 24),

            // Estrellas
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStars = starNumber;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      starNumber <= _selectedStars
                          ? Icons.star
                          : Icons.star_border,
                      size: 48,
                      color: starNumber <= _selectedStars
                          ? Colors.amber
                          : Colors.grey[400],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            // Texto de la calificación
            if (_selectedStars > 0)
              Text(
                _getRatingText(_selectedStars),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _getRatingColor(_selectedStars),
                ),
              ),

            const SizedBox(height: 40),

            // Campo de comentario
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: 'Comentario (opcional)',
                hintText: 'Contanos sobre tu experiencia...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botón enviar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Enviar calificación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Botón cancelar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Calificar después',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText(int stars) {
    switch (stars) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return '¡Excelente!';
      default:
        return '';
    }
  }

  Color _getRatingColor(int stars) {
    if (stars <= 2) return Colors.red;
    if (stars == 3) return Colors.orange;
    return Colors.green;
  }
}