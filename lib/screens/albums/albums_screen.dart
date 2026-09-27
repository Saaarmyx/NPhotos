// lib/screens/albums/albums_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';

class AlbumsScreen extends StatelessWidget {
  final GalleryController controller;
  const AlbumsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final albums = controller.albums;

        if (albums.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron álbumes o carpetas con fotos',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Platform.isAndroid ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _AlbumDetailScreen(
                      album: album,
                      controller: controller,
                    ),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(album.coverPhoto.path),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey[800]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${album.photos.length} elementos',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Vista Detalle del Álbum
class _AlbumDetailScreen extends StatelessWidget {
  final Album album;
  final GalleryController controller;

  const _AlbumDetailScreen({
    Key? key,
    required this.album,
    required this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(album.name)),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Platform.isAndroid ? 3 : 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: album.photos.length,
        itemBuilder: (context, index) {
          final photo = album.photos[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              cacheWidth: 250,
            ),
          );
        },
      ),
    );
  }
}
