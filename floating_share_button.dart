import 'package:flutter/material.dart';
import '../services/social_media_service.dart';

class FloatingShareButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String? tooltip;

  const FloatingShareButton({
    Key? key,
    required this.onPressed,
    this.tooltip,
  }) : super(key: key);

  @override
  State<FloatingShareButton> createState() => _FloatingShareButtonState();
}

class _FloatingShareButtonState extends State<FloatingShareButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
        widget.onPressed();
      },
      tooltip: widget.tooltip ?? 'Compartir',
      backgroundColor: Colors.blue,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: const Icon(Icons.share),
          );
        },
      ),
    );
  }
}
