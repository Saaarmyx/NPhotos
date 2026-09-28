// lib/screens/videos/videos_screen.dart
//
// Pantalla dedicada de Vídeos (se abre desde Álbumes: pin o fila).
// Mantener pulsado inicia la selección múltiple.
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../controllers/selection_controller.dart';
import '../../models/photo.dart';
import '../../utils/photo_viewer.dart';
import '../../widgets/photo_tile.dart';

class VideosScreen extends StatelessWidget {
  final GalleryController controller;
  final SelectionController? selection;

  const VideosScreen({
    super.key,
    required this.controller,
    this.selection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NSecondaryTopBar(title: 'Vídeos'),
      body: AnimatedBuilder(
        animation: Listenable.merge([controller, selection]),
        builder: (context, _) {
          final videos = controller.videos;
          if (videos.isEmpty) {
            return const NEmptyState(
              icon: Icons.videocam_outlined,
              title: 'No hay vídeos',
              subtitle: 'Tus vídeos aparecerán aquí.',
            );
          }
          final sel = selection;
          final selecting = sel?.isActive ?? false;
          return NResponsiveGrid.dense(
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final Photo photo = videos[index];
              return GestureDetector(
                onTap: () => selecting
                    ? sel!.toggle(photo.id)
                    : openPhotoViewer(
                        context,
                        controller: controller,
                        photos: videos,
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
