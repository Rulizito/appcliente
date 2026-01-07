// ============================================================================
// widgets/rating_stars_widget.dart - Widget de Estrellas de Calificación
// ============================================================================

import 'package:flutter/material.dart';

class RatingStarsWidget extends StatelessWidget {
  final int rating;
  final double size;
  final Color color;
  final bool interactive;
  final Function(int)? onRatingChanged;
  final bool showRating;
  final MainAxisAlignment alignment;

  const RatingStarsWidget({
    Key? key,
    required this.rating,
    this.size = 16.0,
    this.color = Colors.amber,
    this.interactive = false,
    this.onRatingChanged,
    this.showRating = false,
    this.alignment = MainAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return _buildStar(index);
          }),
        ),
        if (showRating) ...[
          const SizedBox(width: 8),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStar(int index) {
    final starValue = index + 1;
    final isFilled = starValue <= rating;
    final isHalfFilled = starValue == rating + 0.5;

    Widget starWidget;

    if (interactive) {
      starWidget = GestureDetector(
        onTap: () => onRatingChanged?.call(starValue),
        child: _buildStarIcon(isFilled, isHalfFilled),
      );
    } else {
      starWidget = _buildStarIcon(isFilled, isHalfFilled);
    }

    return SizedBox(
      width: size,
      height: size,
      child: starWidget,
    );
  }

  Widget _buildStarIcon(bool isFilled, bool isHalfFilled) {
    if (isFilled) {
      return Icon(
        Icons.star,
        color: color,
        size: size,
      );
    } else if (isHalfFilled) {
      return Icon(
        Icons.star_half,
        color: color,
        size: size,
      );
    } else {
      return Icon(
        Icons.star_border,
        color: color.withOpacity(0.3),
        size: size,
      );
    }
  }
}

// Widget para mostrar calificación con barra de progreso
class RatingBarWidget extends StatelessWidget {
  final int rating;
  final int totalReviews;
  final double barWidth;

  const RatingBarWidget({
    Key? key,
    required this.rating,
    required this.totalReviews,
    this.barWidth = 100.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final percentage = totalReviews > 0 ? (rating / totalReviews) * 100 : 0.0;

    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$rating',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// Widget para mostrar distribución de calificaciones
class RatingDistributionWidget extends StatelessWidget {
  final Map<int, int> distribution;
  final int totalReviews;

  const RatingDistributionWidget({
    Key? key,
    required this.distribution,
    required this.totalReviews,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (index) {
        final rating = 5 - index; // 5, 4, 3, 2, 1
        final count = distribution[rating] ?? 0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: RatingBarWidget(
            rating: count,
            totalReviews: totalReviews,
          ),
        );
      }),
    );
  }
}

// Widget interactivo para seleccionar calificación
class InteractiveRatingWidget extends StatefulWidget {
  final int initialRating;
  final double size;
  final Color color;
  final Function(int) onRatingChanged;
  final String? label;

  const InteractiveRatingWidget({
    Key? key,
    this.initialRating = 0,
    this.size = 32.0,
    this.color = Colors.amber,
    required this.onRatingChanged,
    this.label,
  }) : super(key: key);

  @override
  State<InteractiveRatingWidget> createState() => _InteractiveRatingWidgetState();
}

class _InteractiveRatingWidgetState extends State<InteractiveRatingWidget> {
  late int _currentRating;
  int _hoverRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isFilled = starValue <= (_hoverRating > 0 ? _hoverRating : _currentRating);
                
                return MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _hoverRating = starValue;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _hoverRating = 0;
                    });
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentRating = starValue;
                      });
                      widget.onRatingChanged(starValue);
                    },
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      child: Icon(
                        isFilled ? Icons.star : Icons.star_border,
                        color: isFilled ? widget.color : Colors.grey[300],
                        size: widget.size,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 12),
            Text(
              _getRatingText(_currentRating),
              style: TextStyle(
                fontSize: widget.size * 0.6,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Malo';
      case 2:
        return 'Regular';
      case 3:
        return 'Bueno';
      case 4:
        return 'Muy bueno';
      case 5:
        return 'Excelente';
      default:
        return 'Seleccioná una calificación';
    }
  }
}
