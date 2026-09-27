// lib/screens/collections/collections_screen.dart
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/collection.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/photo_tile.dart';

/// Pantalla "Colecciones": lista de opciones especiales construida con
/// piezas del kit ([NSettingsSectionCard]), para que el diseño propague.
class CollectionsScreen extends StatelessWidget {
  final GalleryController controller;

  const CollectionsScreen({super.key, required this.controller});

  void _open(BuildContext context, CollectionKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CollectionDetailScreen(controller: controller, kind: kind),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(NSpacing.spaceMd),
      children: [
        NSettingsSectionCard(
          section: NSettingsSection(
            title: 'Colecciones',
            items: CollectionKind.values
                .map(
                  (kind) => NNavigationItem.standard(
                    icon: kind.icon,
                    title: kind.label,
                    subtitle: kind.description,
                    onTap: () => _open(context, kind),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

/// Detalle de una colección especial.
///
/// Solo "Añadidos recientemente" tiene contenido real hoy (las fotos
/// ordenadas por creación); el resto muestra su estado vacío honesto hasta
/// que se implemente su lógica.
class CollectionDetailScreen extends StatelessWidget {
  final GalleryController controller;
  final CollectionKind kind;

  const CollectionDetailScreen({
    super.key,
    required this.controller,
    required this.kind,
  });

  Future<bool> _confirm(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(
        title: kind.label,
        actions: [
          if (kind == CollectionKind.trash)
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) => controller.trash.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined),
                      tooltip: 'Vaciar papelera',
                      onPressed: () async {
                        final confirmed = await _confirm(
                          context,
                          title: 'Vaciar papelera',
                          message:
                              'Se eliminarán definitivamente todas las fotos de la papelera.',
                        );
                        if (confirmed) await controller.emptyTrash();
                      },
                    ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (kind == CollectionKind.recent) {
            return _RecentGrid(controller: controller);
          }
          if (kind == CollectionKind.trash) {
            return _TrashGrid(controller: controller, onConfirm: _confirm);
          }

          return NEmptyState(
            icon: kind.icon,
            title: kind.label,
            subtitle: kind.description,
          );
        },
      ),
    );
  }
}

/// Añadidos recientemente: fotos ordenadas por creación.
class _RecentGrid extends StatelessWidget {
  final GalleryController controller;

  const _RecentGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final recent = List.of(controller.photos)
      ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    if (recent.isEmpty) {
      return const NEmptyState(
        icon: Icons.access_time_outlined,
        title: 'Nada reciente todavía',
      );
    }
    return PhotoGrid.photos(
      itemCount: recent.length,
      itemBuilder: (context, index) => PhotoTile(path: recent[index].path),
    );
  }
}

/// Papelera: restaurar o eliminar definitivamente por foto.
class _TrashGrid extends StatelessWidget {
  final GalleryController controller;
  final Future<bool> Function(
    BuildContext context, {
    required String title,
    required String message,
  })
  onConfirm;

  const _TrashGrid({required this.controller, required this.onConfirm});

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
          onRestore: () => controller.restoreFromTrash(trashed.photo.id),
          onDelete: () async {
            final confirmed = await onConfirm(
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
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _TrashCard({
    required this.photoPath,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoTile(path: photoPath),
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
