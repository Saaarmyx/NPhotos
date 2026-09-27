import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/gallery_controller.dart';

class PhotoViewerScreen extends StatefulWidget {
  final GalleryController controller;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.controller,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final photos = widget.controller.photos;

        if (photos.isEmpty || _currentIndex >= photos.length) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'No hay imagen disponible',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }

        final currentPhoto = photos[_currentIndex];

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.6),
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              currentPhoto.title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final photo = photos[index];
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          bottomNavigationBar: BottomAppBar(
            color: Colors.black.withOpacity(0.8),
            elevation: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white),
                  onPressed: () {
                    // Acción para compartir
                  },
                ),
                IconButton(
                  icon: Icon(
                    currentPhoto.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: currentPhoto.isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: () {
                    widget.controller.toggleFavorite(currentPhoto.id);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    // Acción para ver detalles de la foto
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
