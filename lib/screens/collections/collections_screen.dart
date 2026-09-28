// lib/screens/collections/collections_screen.dart
//
// Solo [visibleCollectionKinds]: Vídeos y Papelera viven pineados en
// Álbumes. Lugares agrupa por carpeta de origen (el modelo no trae GPS,
// la carpeta es la única señal de procedencia real); Recientes ordena
// por creación. El resto muestra su estado honesto.
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(NSpacing.spaceMd),
        children: [
          NSettingsSectionCard(
            section: NSettingsSection(
              title: 'Colecciones',
              items: visibleCollectionKinds
                  .map(
                    (kind) => NNavigationItem.standard(
                      icon: kind.icon,
                      title: kind.label,
                      subtitle: _subtitleFor(kind, controller),
                      onTap: () => _open(context, kind),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitleFor(CollectionKind kind, GalleryController controller) {
    return switch (kind) {
      CollectionKind.places =>
        controller.placesGroups.isEmpty
            ? 'Sin fotos todavía'
            : '${controller.placesGroups.length} orígenes',
      CollectionKind.recent =>
        controller.photos.isEmpty
            ? 'Nada reciente todavía'
            : '${controller.photos.length} elementos',
      _ => kind.description,
    };
  }
}

/// Detalle de una colección especial.
class CollectionDetailScreen extends StatelessWidget {
  final GalleryController controller;
  final CollectionKind kind;

  const CollectionDetailScreen({
    super.key,
    required this.controller,
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    // Vídeos/Papelera ya no viven aquí (pineados en Álbumes): si se llega
    // por un índice desktop antiguo, se redirige al estado honesto.
    return Scaffold(
      appBar: NSecondaryTopBar(title: kind.label),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (kind == CollectionKind.recent) {
            return _RecentGrid(controller: controller);
          }
          if (kind == CollectionKind.places) {
            return _PlacesGrid(controller: controller);
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
      itemBuilder: (context, index) {
        final photo = recent[index];
        return PhotoTile(path: photo.path, isVideo: photo.isVideo);
      },
    );
  }
}

/// Lugares: fotos agrupadas por carpeta de origen, con cabecera por grupo.
class _PlacesGrid extends StatelessWidget {
  final GalleryController controller;

  const _PlacesGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final groups = controller.placesGroups;
    if (groups.isEmpty) {
      return const NEmptyState(
        icon: Icons.place_outlined,
        title: 'Sin lugares todavía',
        subtitle: 'Tus carpetas de origen aparecerán aquí.',
      );
    }
    final entries = groups.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(NSpacing.spaceMd),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: NSpacing.spaceSm),
              child: Text(
                '${entry.key} · ${entry.value.length}',
                style: TextStyle(
                  fontFamily: NTypography.fontFamilyBase,
                  fontWeight: NTypography.weightBold,
                  fontSize: NTypography.sizeSm,
                  color: context.nPrimaryTextColor,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.0,
                  ),
              itemCount: entry.value.length,
              itemBuilder: (context, photoIndex) {
                final photo = entry.value[photoIndex];
                return PhotoTile(path: photo.path, isVideo: photo.isVideo);
              },
            ),
            const SizedBox(height: NSpacing.spaceLg),
          ],
        );
      },
    );
  }
}
