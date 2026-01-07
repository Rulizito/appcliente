// ============================================================================
// widgets/promotion_banner_carousel.dart - Carrusel de Banners Promocionales
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/promotion_banner_model.dart';
import '../services/promotion_banner_service.dart';
import 'promotion_banner_widget.dart';

class PromotionBannerCarousel extends StatefulWidget {
  final List<PromotionBanner> banners;
  final double? height;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final bool showIndicators;
  final EdgeInsets? margin;
  final Function(PromotionBanner)? onBannerTap;

  const PromotionBannerCarousel({
    Key? key,
    required this.banners,
    this.height,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 5),
    this.showIndicators = true,
    this.margin,
    this.onBannerTap,
  }) : super(key: key);

  @override
  State<PromotionBannerCarousel> createState() => _PromotionBannerCarouselState();
}

class _PromotionBannerCarouselState extends State<PromotionBannerCarousel> {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController();
    
    if (widget.autoPlay && widget.banners.isNotEmpty) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (widget.banners.isNotEmpty) {
        _nextPage();
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _nextPage() {
    if (_currentIndex < widget.banners.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _currentIndex--;
    } else {
      _currentIndex = widget.banners.length - 1;
    }
    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    // Reiniciar auto play cuando el usuario cambia manualmente
    if (widget.autoPlay) {
      _stopAutoPlay();
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: widget.height ?? 180,
      child: Stack(
        children: [
          // Carrusel
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return PromotionBannerWidget(
                banner: banner,
                onTap: () => widget.onBannerTap?.call(banner),
                customHeight: widget.height,
                margin: EdgeInsets.zero,
              );
            },
          ),
          
          // Controles de navegación
          if (widget.banners.length > 1) ...[
            // Botón anterior
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _previousPage,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            
            // Botón siguiente
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _nextPage,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
          
          // Indicadores
          if (widget.showIndicators && widget.banners.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.banners.asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        entry.key,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == entry.key
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget para banners verticales (para sidebar)
class VerticalBannerCarousel extends StatefulWidget {
  final List<PromotionBanner> banners;
  final double? width;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final EdgeInsets? margin;
  final Function(PromotionBanner)? onBannerTap;

  const VerticalBannerCarousel({
    Key? key,
    required this.banners,
    this.width,
    this.autoPlay = true,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.margin,
    this.onBannerTap,
  }) : super(key: key);

  @override
  State<VerticalBannerCarousel> createState() => _VerticalBannerCarouselState();
}

class _VerticalBannerCarouselState extends State<VerticalBannerCarousel> {
  late PageController _pageController;
  late int _currentIndex;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _pageController = PageController(
      viewportFraction: 0.8,
      initialPage: 0,
    );
    
    if (widget.autoPlay && widget.banners.isNotEmpty) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(widget.autoPlayInterval, (timer) {
      if (widget.banners.isNotEmpty) {
        _nextPage();
      }
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  void _nextPage() {
    if (_currentIndex < widget.banners.length - 1) {
      _currentIndex++;
    } else {
      _currentIndex = 0;
    }
    _pageController.animateToPage(
      _currentIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    
    if (widget.autoPlay) {
      _stopAutoPlay();
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      width: widget.width ?? 300,
      height: 400,
      child: Column(
        children: [
          // Título
          Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Promociones Especiales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          // Carrusel vertical
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              scrollDirection: Axis.vertical,
              itemCount: widget.banners.length,
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: PromotionBannerWidget(
                    banner: banner,
                    onTap: () => widget.onBannerTap?.call(banner),
                    customHeight: 350,
                    margin: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
          
          // Indicadores verticales
          if (widget.banners.length > 1)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.banners.asMap().entries.map((entry) {
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        entry.key,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == entry.key
                            ? Colors.red
                            : Colors.grey[300],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// Widget para grid de banners
class PromotionBannerGrid extends StatelessWidget {
  final List<PromotionBanner> banners;
  final int crossAxisCount;
  final double childAspectRatio;
  final EdgeInsets? margin;
  final Function(PromotionBanner)? onBannerTap;

  const PromotionBannerGrid({
    Key? key,
    required this.banners,
    this.crossAxisCount = 2,
    this.childAspectRatio = 1.5,
    this.margin,
    this.onBannerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Más Promociones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          // Grid de banners
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return PromotionBannerWidget(
                banner: banner,
                onTap: () => onBannerTap?.call(banner),
                margin: EdgeInsets.zero,
              );
            },
          ),
        ],
      ),
    );
  }
}

// Widget para lista de banners
class PromotionBannerList extends StatelessWidget {
  final List<PromotionBanner> banners;
  final EdgeInsets? margin;
  final Function(PromotionBanner)? onBannerTap;

  const PromotionBannerList({
    Key? key,
    required this.banners,
    this.margin,
    this.onBannerTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: margin ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Todas las Promociones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          
          // Lista de banners
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PromotionBannerWidget(
                  banner: banner,
                  onTap: () => onBannerTap?.call(banner),
                  margin: EdgeInsets.zero,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
