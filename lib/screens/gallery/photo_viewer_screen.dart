import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';

/// Nombres de mes en español para la cabecera del visor.
const _kMonthsEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// 'Septiembre 11, 2026'.
String _formatViewerDate(DateTime date) =>
    '${_kMonthsEs[date.month - 1]} ${date.day}, ${date.year}';

/// '21:38'.
String _formatViewerTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

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

  /// Giros de visualización por foto (solo sesión, no se persiste).
  final Map<String, int> _rotations = {};

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

        if (photos.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: NEmptyState(
              icon: Icons.broken_image_outlined,
              title: 'No hay imagen disponible',
              foregroundColor: Colors.white,
            ),
          );
        }

        // La lista puede recargarse con menos elementos mientras se mira una
        // foto: se recorta el índice para el chrome (fecha y acciones).
        final safeIndex = _currentIndex.clamp(0, photos.length - 1);
        final currentPhoto = photos[safeIndex];

        return NPhotoViewer(
          title: _formatViewerDate(currentPhoto.dateModified),
          subtitle: _formatViewerTime(currentPhoto.dateModified),
          onRotate: () => setState(() {
            _rotations[currentPhoto.id] =
                ((_rotations[currentPhoto.id] ?? 0) + 1) % 4;
          }),
          // TODO: implementar compartir (p. ej. con share_plus).
          onShare: () {},
          // TODO: implementar edición.
          onEdit: () {},
          onDelete: () {
            widget.controller.moveToTrash(currentPhoto.id);
            Navigator.of(context).pop();
          },
          isFavorite: currentPhoto.isFavorite,
          onFavoriteToggle: () =>
              widget.controller.toggleFavorite(currentPhoto.id),
          child: PageView.builder(
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
                  child: RotatedBox(
                    quarterTurns: _rotations[photo.id] ?? 0,
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
