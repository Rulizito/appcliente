// ============================================================================
// widgets/social_share_widget.dart - Widget para compartir en redes sociales
// ============================================================================

import 'package:flutter/material.dart';
import '../services/social_media_service.dart';
import '../models/business_model.dart' as business_model;
import '../models/order_model.dart' as order_model;

class SocialShareWidget extends StatefulWidget {
  final ShareableContent content;
  final Function(bool success)? onShareComplete;
  final bool showPreview;

  const SocialShareWidget({
    Key? key,
    required this.content,
    this.onShareComplete,
    this.showPreview = true,
  }) : super(key: key);

  @override
  State<SocialShareWidget> createState() => _SocialShareWidgetState();
}

class _SocialShareWidgetState extends State<SocialShareWidget> {
  final SocialMediaService _socialService = SocialMediaService();
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Compartir en Redes Sociales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Preview
          if (widget.showPreview) ...[
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.content.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.content.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (widget.content.imageUrl != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.content.imageUrl!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 40),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Social Platforms
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: SocialPlatform.values.length,
              itemBuilder: (context, index) {
                final platform = SocialPlatform.values[index];
                final platformInfo = _socialService.getPlatformInfo(platform);
                
                return InkWell(
                  onTap: _isSharing ? null : () => _shareToPlatform(platform),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: platformInfo['color'],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: platformInfo['color'].withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getPlatformIcon(platform),
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          platformInfo['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Share Button
          if (_isSharing)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Compartiendo...'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _getPlatformIcon(SocialPlatform platform) {
    switch (platform) {
      case SocialPlatform.facebook:
        return Icons.facebook;
      case SocialPlatform.twitter:
        return Icons.alternate_email;
      case SocialPlatform.whatsapp:
        return Icons.message;
      case SocialPlatform.instagram:
        return Icons.camera_alt;
      case SocialPlatform.telegram:
        return Icons.send;
      case SocialPlatform.linkedin:
        return Icons.work;
      case SocialPlatform.pinterest:
        return Icons.push_pin;
      case SocialPlatform.tiktok:
        return Icons.music_video;
      case SocialPlatform.snapchat:
        return Icons.flash_on;
      default:
        return Icons.share;
    }
  }

  Future<void> _shareToPlatform(SocialPlatform platform) async {
    setState(() {
      _isSharing = true;
    });

    try {
      final success = await _socialService.shareContent(
        widget.content,
        platform,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Compartido en ${platform.name}!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onShareComplete?.call(true);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al compartir'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }
}
