import 'package:flutter/material.dart';
import '../services/ai_recommendation_service.dart';
import '../widgets/detailed_recommendation_card.dart';

class AIRecommendationsWidget extends StatefulWidget {
  final String? userId;

  const AIRecommendationsWidget({Key? key, this.userId}) : super(key: key);

  @override
  State<AIRecommendationsWidget> createState() => _AIRecommendationsWidgetState();
}

class _AIRecommendationsWidgetState extends State<AIRecommendationsWidget> {
  final AIRecommendationService _recommendationService = AIRecommendationService();
  
  List<Recommendation> _recommendations = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    if (widget.userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final recommendations = await _recommendationService.getPersonalizedRecommendations(
        widget.userId!,
        limit: 10,
        types: [RecommendationType.hybrid],
      );

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_recommendations.isEmpty) {
      return const Center(
        child: Text(
          'No hay recomendaciones disponibles',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: _recommendations.map((recommendation) {
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            child: DetailedRecommendationCard(
              recommendation: recommendation,
              userId: widget.userId!,
              onBusinessTap: (businessId) {
                // Navegar a detalles del negocio
                Navigator.pushNamed(context, '/business_detail', arguments: {
                  'businessId': businessId,
                });
              },
              onFeedback: (isPositive) {
                _showFeedbackSnackBar(isPositive);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showFeedbackSnackBar(bool isPositive) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPositive 
              ? '¡Gracias! Tu feedback ayudará a mejorar las recomendaciones.'
              : 'Gracias por tu feedback. Lo usaremos para mejorar.',
        ),
        backgroundColor: isPositive ? Colors.green : Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
