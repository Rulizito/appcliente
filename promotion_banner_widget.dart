// ============================================================================
// widgets/promotion_banner_widget.dart - Widget de Banner Promocional
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/promotion_banner_model.dart';
import '../services/promotion_banner_service.dart';
import 'package:intl/intl.dart';

class PromotionBannerWidget extends StatefulWidget {
  final PromotionBanner banner;
  final Function()? onTap;
  final bool showImpressionTracker;
  final double? customHeight;
  final EdgeInsets? margin;

  const PromotionBannerWidget({
    Key? key,
    required this.banner,
    this.onTap,
    this.showImpressionTracker = true,
    this.customHeight,
    this.margin,
  }) : super(key: key);

  @override
  State<PromotionBannerWidget> createState() => _PromotionBannerWidgetState();
}

class _PromotionBannerWidgetState extends State<PromotionBannerWidget>
    with AutomaticKeepAliveClientMixin {
  final _bannerService = PromotionBannerService();
  bool _hasRecordedImpression = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.showImpressionTracker && !_hasRecordedImpression) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recordImpression();
      });
    }
  }

  Future<void> _recordImpression() async {
    if (!_hasRecordedImpression) {
      await _bannerService.recordImpression(widget.banner.id);
      setState(() {
        _hasRecordedImpression = true;
      });
    }
  }

  Future<void> _handleTap() async {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      await _bannerService.executeBannerAction(widget.banner, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: widget.customHeight ?? widget.banner.height,
      child: _buildBannerContent(),
    );
  }

  Widget _buildBannerContent() {
    switch (widget.banner.type) {
      case BannerType.hero:
        return _buildHeroBanner();
      case BannerType.carousel:
        return _buildCarouselBanner();
      case BannerType.flash:
        return _buildFlashBanner();
      case BannerType.category:
        return _buildCategoryBanner();
      case BannerType.business:
        return _buildBusinessBanner();
      case BannerType.referral:
        return _buildReferralBanner();
      case BannerType.loyalty:
        return _buildLoyaltyBanner();
      case BannerType.seasonal:
        return _buildSeasonalBanner();
      case BannerType.countdown:
        return _buildCountdownBanner();
      case BannerType.interactive:
        return _buildInteractiveBanner();
    }
  }

  Widget _buildHeroBanner() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.banner.backgroundColor,
                widget.banner.backgroundColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Imagen de fondo
              if (widget.banner.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: widget.banner.backgroundColor.withOpacity(0.3),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: widget.banner.backgroundColor.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              // Overlay con contenido
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        widget.banner.title,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: widget.banner.textColor,
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 16,
                            color: widget.banner.textColor.withOpacity(0.9),
                          ),
                        ),
                      ],
                      if (widget.banner.buttonText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _handleTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.banner.buttonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            widget.banner.formattedButtonText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselBanner() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.banner.backgroundColor.withOpacity(0.1),
          ),
          child: Row(
            children: [
              // Imagen
              if (widget.banner.imageUrl.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              // Contenido
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.banner.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.banner.textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.banner.textColor.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (widget.banner.buttonText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _handleTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.banner.buttonColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            widget.banner.formattedButtonText,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashBanner() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.orange,
              Colors.red,
            ],
          ),
        ),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono de flash
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.flash_on,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OFERTA FLASH',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.banner.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty)
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                // Flecha
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBanner() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.banner.backgroundColor.withOpacity(0.1),
            border: Border.all(color: widget.banner.backgroundColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              if (widget.banner.imageUrl.isNotEmpty)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: widget.banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.category, size: 20),
                      ),
                    ),
                  ),
                ),
              if (widget.banner.imageUrl.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.banner.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.banner.textColor,
                      ),
                    ),
                    if (widget.banner.subtitle.isNotEmpty)
                      Text(
                        widget.banner.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.banner.textColor.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.banner.buttonText.isNotEmpty)
                TextButton(
                  onPressed: _handleTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    widget.banner.formattedButtonText,
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.banner.buttonColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessBanner() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Logo del negocio
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[300],
                backgroundImage: widget.banner.imageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(widget.banner.imageUrl)
                    : null,
                child: widget.banner.imageUrl.isEmpty
                    ? Text(
                        widget.banner.title.isNotEmpty
                            ? widget.banner.title[0].toUpperCase()
                            : 'N',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.banner.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.banner.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (widget.banner.buttonText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _handleTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.banner.buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          widget.banner.formattedButtonText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferralBanner() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.purple,
              Colors.blue,
            ],
          ),
        ),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono de regalo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.card_giftcard,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INVITA A UN AMIGO',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.banner.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty)
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                    ],
                  ),
                ),
                // Flecha
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoyaltyBanner() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.amber[50],
          border: Border.all(color: Colors.amber[200]!),
        ),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icono de estrella
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber[800],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.banner.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.banner.buttonText.isNotEmpty)
                  ElevatedButton(
                    onPressed: _handleTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.banner.formattedButtonText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeasonalBanner() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green[400]!,
                Colors.green[600]!,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Imagen de fondo
              if (widget.banner.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: widget.banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.green.withOpacity(0.3),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.green.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              // Overlay con contenido
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.5),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'TEMPORADA',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.banner.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBanner() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.red[50],
          border: Border.all(color: Colors.red[200]!),
        ),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Timer
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.timer,
                    color: Colors.red[800],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFERTA POR TIEMPO LIMITADO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.banner.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty)
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                          ),
                        ),
                      // Countdown
                      _buildCountdown(),
                    ],
                  ),
                ),
                if (widget.banner.buttonText.isNotEmpty)
                  ElevatedButton(
                    onPressed: _handleTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      widget.banner.formattedButtonText,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveBanner() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo,
                Colors.purple,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Imagen de fondo
              if (widget.banner.imageUrl.isNotEmpty)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: widget.banner.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.indigo.withOpacity(0.3),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.indigo.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
              // Overlay con contenido
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'INTERACTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.banner.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.banner.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.banner.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                      if (widget.banner.buttonText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _handleTap,
                                icon: const Icon(Icons.play_arrow, size: 16),
                                label: Text(
                                  widget.banner.formattedButtonText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.indigo,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final now = DateTime.now();
    final difference = widget.banner.endDate.difference(now);
    
    if (difference.isNegative) {
      return const SizedBox.shrink();
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${days}d ${hours}h ${minutes}m',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.red[800],
        ),
      ),
    );
  }
}
