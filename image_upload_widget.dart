// ============================================================================
// widgets/image_upload_widget.dart - Widget para Subida de Imágenes
// ============================================================================

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageUploadWidget extends StatefulWidget {
  final List<String> initialImages;
  final Function(List<String>) onImagesChanged;
  final int maxImages;
  final double maxWidth;
  final double maxHeight;
  final int imageQuality;

  const ImageUploadWidget({
    Key? key,
    this.initialImages = const [],
    required this.onImagesChanged,
    this.maxImages = 3,
    this.maxWidth = 800.0,
    this.maxHeight = 600.0,
    this.imageQuality = 80,
  }) : super(key: key);

  @override
  State<ImageUploadWidget> createState() => _ImageUploadWidgetState();
}

class _ImageUploadWidgetState extends State<ImageUploadWidget> {
  List<String> _images = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.initialImages);
  }

  Future<void> _pickImages() async {
    if (_images.length >= widget.maxImages) {
      _showMessage('Máximo ${widget.maxImages} imágenes permitidas', Colors.orange);
      return;
    }

    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: widget.imageQuality,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      );

      if (images != null) {
        setState(() {
          _isUploading = true;
        });

        // Simular subida (en una app real, subiríamos a un servicio como Firebase Storage)
        await Future.delayed(const Duration(seconds: 2));

        final remainingSlots = widget.maxImages - _images.length;
        final imagesToAdd = images.take(remainingSlots).toList();
        
        final newImageUrls = imagesToAdd.map((img) => img.path).toList();
        
        setState(() {
          _images.addAll(newImageUrls);
          _isUploading = false;
        });

        widget.onImagesChanged(_images);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showMessage('Error al seleccionar imágenes: $e', Colors.red);
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (_images.length >= widget.maxImages) {
      _showMessage('Máximo ${widget.maxImages} imágenes permitidas', Colors.orange);
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: widget.imageQuality,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      );

      if (image != null) {
        setState(() {
          _isUploading = true;
        });

        // Simular subida
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _images.add(image.path);
          _isUploading = false;
        });

        widget.onImagesChanged(_images);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showMessage('Error al tomar foto: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
    widget.onImagesChanged(_images);
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Seleccionar de galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImages();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Imágenes (${_images.length}/${widget.maxImages})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (_images.length < widget.maxImages)
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _showImageOptions,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.add),
                label: Text(_isUploading ? 'Subiendo...' : 'Agregar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Grid de imágenes
        if (_images.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              final imageUrl = _images[index];
              final isNetworkImage = imageUrl.startsWith('http');
              
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isNetworkImage
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.error),
                              ),
                            )
                          : Image.asset(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error),
                                );
                              },
                            ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        
        // Botón para agregar más imágenes
        if (_images.length < widget.maxImages)
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[300]!,
                style: BorderStyle.solid,
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _showImageOptions,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agregar imagen',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
