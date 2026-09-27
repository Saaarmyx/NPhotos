import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';
import 'photo_viewer_screen.dart';

class GalleryScreen extends StatelessWidget {
  final GalleryController controller;

  const GalleryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        switch (controller.state) {
          case GalleryState.initial:
          case GalleryState.loading:
            return const Center(child: CircularProgressIndicator());

          case GalleryState.permissionDenied:
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, size: 60, color: Colors.amber),
                  const SizedBox(height: 16),
                  const Text('Se requieren permisos para acceder a tus fotos'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: controller.fetchPhotos,
                    child: const Text('Conceder Permiso'),
                  ),
                ],
              ),
            );

          case GalleryState.error:
            return Center(
              child: Text(controller.errorMessage ?? 'Error al cargar fotos'),
            );

          case GalleryState.loaded:
            if (controller.photos.isEmpty) {
              return Center(
                child: Text(
                  Platform.isAndroid
                      ? 'No hay fotos en DCIM o Pictures.'
                      : 'No hay fotos en ~/Pictures o ~/Downloads.',
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: Platform.isAndroid ? 3 : 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: controller.photos.length,
              itemBuilder: (context, index) {
                final photo = controller.photos[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(
                          controller: controller,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                  child: _PhotoItemCard(photo: photo),
                );
              },
            );
        }
      },
    );
  }
}

class _PhotoItemCard extends StatelessWidget {
  final Photo photo;

  const _PhotoItemCard({required this.photo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(photo.path),
        fit: BoxFit.cover,
        cacheWidth: 250,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black12,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white24,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
