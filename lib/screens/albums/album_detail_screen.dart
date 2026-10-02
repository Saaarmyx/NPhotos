// lib/screens/albums/album_detail_screen.dart
//
// Molde de detalle de álbum: portada + grilla con visor. Cada álbum
// que se cree o se tenga se renderiza con esta pantalla.
import 'package:flutter/material.dart';
import 'package:NexoraUi/NexoraUi.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';
import '../../utils/photo_viewer.dart';
import '../../widgets/photo_tile.dart';

class AlbumDetailScreen extends StatelessWidget {
  final Album album;
  final GalleryController controller;

  const AlbumDetailScreen({
    super.key,
    required this.album,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(title: album.name),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          // Re-resuelve el álbum en vivo: si la galería cambia (papelera,
          // privada), el detalle no muestra fotos fantasma.
          final live = controller.albums.where((a) => a.path == album.path);
          final photos = live.isEmpty ? album.photos : live.first.photos;
          if (photos.isEmpty) {
            return NEmptyState(
              icon: Icons.photo_album_outlined,
              title: album.name,
              subtitle: 'Este álbum quedó vacío.',
            );
          }
          return NResponsiveGrid.dense(
            itemCount: photos.length,
            itemBuilder: (context, index) {
              final Photo photo = photos[index];
              return GestureDetector(
                onTap: () => openPhotoViewer(
                  context,
                  controller: controller,
                  photos: photos,
                  initialId: photo.id,
                ),
                child: PhotoTile(photo: photo, path: photo.path),
              );
            },
          );
        },
      ),
    );
  }
}
