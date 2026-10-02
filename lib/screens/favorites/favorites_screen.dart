// lib/screens/favorites/favorites_screen.dart
//
// Pantalla dedicada de Favoritos (se abre desde Álbumes: pin o fila).
// Mantener pulsado inicia la selección múltiple.
import 'package:flutter/material.dart';
import 'package:NexoraUi/NexoraUi.dart';

import '../../controllers/gallery_controller.dart';
import '../../controllers/selection_controller.dart';
import '../../models/photo.dart';
import '../../utils/photo_viewer.dart';
import '../../widgets/photo_tile.dart';

class FavoritesScreen extends StatelessWidget {
  final GalleryController controller;
  final SelectionController? selection;

  const FavoritesScreen({
    super.key,
    required this.controller,
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Favoritos'),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, selection]),
        builder: (context, _) {
          final favorites = controller.favoritePhotos;
          if (favorites.isEmpty) {
            return const NEmptyState(
              icon: Icons.favorite_border,
              title: 'No tienes fotos favoritas',
              subtitle: 'Toca el corazón en una foto para añadirla aquí.',
            );
          }
          final sel = selection;
          final selecting = sel?.isActive ?? false;
          return NResponsiveGrid.dense(
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final Photo photo = favorites[index];
              return GestureDetector(
                onTap: () => selecting
                    ? sel!.toggle(photo.id)
                    : openPhotoViewer(
                        context,
                        controller: controller,
                        photos: favorites,
                        initialId: photo.id,
                      ),
                onLongPress: () => selecting
                    ? sel!.toggle(photo.id)
                    : sel?.selectOnly(
                        photo.id,
                        kind: SelectionKind.photos,
                      ),
                child: PhotoTile(
                  photo: photo,
                  path: photo.path,
                  selected: selecting ? sel!.isSelected(photo.id) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
