import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';
import 'photo_grid.dart';
import 'photo_tile.dart';

/// Confirma una acción destructiva. Retorna true si se confirma.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Parrilla de papelera compartida (pineado de Álbumes).
/// Restaurar o eliminar definitivamente por foto.
class TrashGrid extends StatelessWidget {
  final GalleryController controller;

  const TrashGrid({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final trash = controller.trash;
    if (trash.isEmpty) {
      return const NEmptyState(
        icon: Icons.delete_outline,
        title: 'Papelera vacía',
      );
    }
    return PhotoGrid.photos(
      itemCount: trash.length,
      itemBuilder: (context, index) {
        final trashed = trash[index];
        return _TrashCard(
          photoPath: trashed.photo.path,
          isVideo: trashed.photo.isVideo,
          onRestore: () => controller.restoreFromTrash(trashed.photo.id),
          onDelete: () async {
            final confirmed = await confirmDestructive(
              context,
              title: 'Eliminar definitivamente',
              message:
                  'Se borrará el archivo "${trashed.photo.title}". No se puede deshacer.',
            );
            if (confirmed) {
              await controller.deletePermanently(trashed.photo.id);
            }
          },
        );
      },
    );
  }
}

class _TrashCard extends StatelessWidget {
  final String photoPath;
  final bool isVideo;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashCard({
    required this.photoPath,
    required this.isVideo,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoTile(path: photoPath, isVideo: isVideo),
        Positioned(
          left: NSpacing.space2xs,
          right: NSpacing.space2xs,
          bottom: NSpacing.space2xs,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TrashAction(
                icon: Icons.restore_from_trash_outlined,
                tooltip: 'Restaurar',
                onTap: onRestore,
              ),
              _TrashAction(
                icon: Icons.delete_forever_outlined,
                tooltip: 'Eliminar',
                onTap: onDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrashAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TrashAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(NSpacing.space2xs),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
