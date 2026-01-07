// ============================================================================
// widgets/detailed_recommendation_card_simple.dart - Versión simplificada
// ============================================================================

import 'package:flutter/material.dart';
import '../services/ai_recommendation_service_simple.dart';

class DetailedRecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  final String userId;
  final Function(String)? onBusinessTap;
  final Function(bool)? onFeedback;

  const DetailedRecommendationCard({
    Key? key,
    required this.recommendation,
    required this.userId,
    this.onBusinessTap,
    this.onFeedback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.business.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.reason,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      onBusinessTap?.call(recommendation.businessId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Ver',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    onFeedback?.call(true);
                  },
                  icon: const Icon(Icons.thumb_up, color: Colors.green),
                ),
                IconButton(
                  onPressed: () {
                    onFeedback?.call(false);
                  },
                  icon: const Icon(Icons.thumb_down, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
