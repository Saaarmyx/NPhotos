import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';
import '../controllers/selection_controller.dart';
import '../models/photo.dart';
import 'photo_tile.dart';

/// Confirma una acción destructiva. Retorna true si se confirma.
/// Diálogo del kit: estética Nexora (radio amplio, superficie del tema,
/// acción en danger).
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  IconData? icon,
}) {
  return showNConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: 'Eliminar',
    isDestructive: true,
    icon: icon,
  );
}

/// Parrilla de papelera compartida (pineado de Álbumes).
/// Restaurar o eliminar definitivamente por foto.
class TrashGrid extends StatelessWidget {
  final GalleryController controller;
  final SelectionController? selection;

  const TrashGrid({super.key, required this.controller, this.selection});

  @override
  Widget build(BuildContext context) {
    final trash = controller.trash;
    if (trash.isEmpty) {
      return const NEmptyState(
        icon: Icons.delete_outline,
        title: 'Papelera vacía',
      );
    }
    final sel = selection;
    final selecting = sel?.isActive ?? false;
    return NResponsiveGrid.dense(
      itemCount: trash.length,
      itemBuilder: (context, index) {
        final trashed = trash[index];
        return _TrashCard(
          photo: trashed.photo,
          selected: selecting ? sel!.isSelected(trashed.photo.id) : null,
          selection: sel,
          photoPath: trashed.photo.path,
          isVideo: trashed.photo.isVideo,
          onRestore: () => controller.restoreFromTrash(trashed.photo.id),
          onDelete: () async {
            final confirmed = await confirmDestructive(
              context,
              title: 'Eliminar definitivamente',
              message:
                  'Se borrará el archivo "${trashed.photo.title}". No se puede deshacer.',
              icon: Icons.delete_forever_outlined,
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
  final Photo photo;
  final String photoPath;
  final bool isVideo;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final SelectionController? selection;
  final bool? selected;

  const _TrashCard({
    required this.photo,
    required this.photoPath,
    required this.isVideo,
    required this.onRestore,
    required this.onDelete,
    this.selection,
    this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selection;
    final inSelection = selected != null;
    return GestureDetector(
      onTap: inSelection && sel != null
          ? () => sel.toggle(photo.id)
          : onRestore,
      onLongPress: inSelection && sel != null
          ? () => sel.toggle(photo.id)
          : onDelete,
      child: Stack(
      fit: StackFit.expand,
      children: [
        PhotoTile(
          path: photoPath,
          isVideo: isVideo,
          photo: photo,
          selected: selected,
        ),
        if (!inSelection)
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
      ),
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
