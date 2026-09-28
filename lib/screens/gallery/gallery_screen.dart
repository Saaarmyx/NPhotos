import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/photo_tile.dart';
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
            return const NLoadingView();

          case GalleryState.permissionDenied:
            return NPermissionDeniedView(
              icon: Icons.security,
              title: 'Permiso necesario',
              message: 'Se requieren permisos para acceder a tus fotos',
              actionLabel: 'Conceder permiso',
              onAction: controller.fetchPhotos,
            );

          case GalleryState.error:
            return NErrorView(
              message: controller.errorMessage ?? 'Error al cargar fotos',
              retryLabel: 'Reintentar',
              onRetry: controller.fetchPhotos,
            );

          case GalleryState.loaded:
            if (controller.photos.isEmpty) {
              return NEmptyState(
                icon: Icons.photo_outlined,
                title: 'No hay fotos',
                subtitle: Platform.isAndroid
                    ? 'No hay fotos en DCIM o Pictures.'
                    : 'No hay fotos en ~/Pictures o ~/Downloads.',
              );
            }

            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: PhotoGrid.photos(
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
                    child: PhotoTile(
                      path: photo.path,
                      isVideo: photo.isVideo,
                    ),
                  );
                },
              ),
            );
        }
      },
    );
  }
}
