// lib/screens/favorites/favorites_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';

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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No tienes fotos marcadas como favoritas',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
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
    Key? key,
    required this.photo,
    required this.onRemoveFavorite,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(photo.path),
            fit: BoxFit.cover,
            cacheWidth: 250,
            errorBuilder: (_, __, ___) => Container(color: Colors.black12),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemoveFavorite,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Colors.red, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
