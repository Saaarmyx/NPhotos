// lib/screens/favorites/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/photo_tile.dart';

class FavoritesScreen extends StatelessWidget {
  final GalleryController controller;
  const FavoritesScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final favorites = controller.favoritePhotos;

        if (favorites.isEmpty) {
          return const NEmptyState(
            icon: Icons.favorite_border,
            title: 'No tienes fotos marcadas como favoritas',
            subtitle: 'Toca el corazón en una foto para añadirla aquí.',
          );
        }

        return PhotoGrid.photos(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final photo = favorites[index];
            return _FavoriteCard(
              photo: photo,
              onRemoveFavorite: () => controller.toggleFavorite(photo.id),
            );
          },
        );
      },
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Photo photo;
  final VoidCallback onRemoveFavorite;

  const _FavoriteCard({
    required this.photo,
    required this.onRemoveFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoTile(path: photo.path),
        Positioned(
          top: NSpacing.space2xs,
          right: NSpacing.space2xs,
          child: GestureDetector(
            onTap: onRemoveFavorite,
            child: Container(
              padding: const EdgeInsets.all(NSpacing.space2xs),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.red, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
