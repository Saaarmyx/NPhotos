// lib/screens/albums/albums_screen.dart
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/photo_tile.dart';

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
          return const NEmptyState(
            icon: Icons.photo_album_outlined,
            title: 'No se encontraron álbumes o carpetas con fotos',
          );
        }

        return PhotoGrid.albums(
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
                    child: PhotoTile(
                      path: album.coverPhoto.path,
                      borderRadius: NSpacing.radiusMd,
                      cacheWidth: 300,
                      width: double.infinity,
                    ),
                  ),
                  const SizedBox(height: NSpacing.space2xs),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightBold,
                      fontSize: NTypography.sizeSm,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                  Text(
                    '${album.photos.length} elementos',
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontSize: NTypography.sizeXs,
                      color: context.nMutedTextColor,
                    ),
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
    required this.album,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(title: album.name),
      body: PhotoGrid.photos(
        itemCount: album.photos.length,
        itemBuilder: (context, index) {
          final photo = album.photos[index];
          return PhotoTile(path: photo.path);
        },
      ),
    );
  }
}
