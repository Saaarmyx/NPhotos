// lib/screens/collections/collections_screen.dart
//
// Solo [visibleCollectionKinds]: Vídeos y Papelera viven pineados en
// Álbumes. Lugares agrupa por carpeta de origen (el modelo no trae GPS,
// la carpeta es la única señal de procedencia real); Recientes ordena
// por creación. El resto muestra su estado honesto.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/collection.dart';
import '../../models/photo.dart';
import '../../utils/photo_viewer.dart';
import '../../widgets/photo_tile.dart';

/// Pantalla "Colecciones": lista de opciones especiales construida con
/// piezas del kit ([NSettingsSectionCard]), para que el diseño propague.
class CollectionsScreen extends StatelessWidget {
  final GalleryController controller;

  const CollectionsScreen({super.key, required this.controller});

  void _open(BuildContext context, CollectionKind kind) {
    pushNPage(
      context,
      CollectionDetailScreen(controller: controller, kind: kind),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // Compacto (defecto): todo en una sola lista sin título.
        // Por grupo: tarjetas separadas por grupo, cada una con título.
        // El popup "Orden" (A→Z / Z→A) ordena las colecciones por nombre.
        bool az = controller.collectionsSort == CollectionsSort.az;
        List<CollectionKind> byName(Iterable<CollectionKind> kinds) {
          final list = kinds.toList()
            ..sort(
              (a, b) => az
                  ? a.label.toLowerCase().compareTo(b.label.toLowerCase())
                  : b.label.toLowerCase().compareTo(a.label.toLowerCase()),
            );
          return list;
        }

        final groups = controller.collectionsViewMode ==
                CollectionsViewMode.grouped
            ? collectionGroups
                .map(
                  (g) => _GroupCard(
                    title: g.title,
                    kinds: byName(g.kinds),
                    controller: controller,
                    onOpen: (kind) => _open(context, kind),
                  ),
                )
                .toList()
            : [
                _GroupCard(
                  title: '',
                  kinds: byName(visibleCollectionKinds),
                  controller: controller,
                  onOpen: (kind) => _open(context, kind),
                ),
              ];
        return ListView(
          padding: const EdgeInsets.all(NSpacing.spaceMd),
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: NSpacing.spaceMd),
              groups[i],
            ],
          ],
        );
      },
    );
  }
}

/// Tarjeta de colecciones: título vacío = sin cabecera (modo compacto).
class _GroupCard extends StatelessWidget {
  final String title;
  final List<CollectionKind> kinds;
  final GalleryController controller;
  final ValueChanged<CollectionKind> onOpen;

  const _GroupCard({
    required this.title,
    required this.kinds,
    required this.controller,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return NSettingsSectionCard(
      section: NSettingsSection(
        title: title,
        items: [
          for (final kind in kinds)
            NNavigationItem.standard(
              icon: kind.icon,
              title: kind.label,
              subtitle: subtitleFor(kind, controller),
              onTap: () => onOpen(kind),
            ),
        ],
      ),
    );
  }

  String subtitleFor(CollectionKind kind, GalleryController controller) {
    return switch (kind) {
      CollectionKind.places =>
        controller.placesGroups.isEmpty
            ? 'Sin fotos todavía'
            : '${controller.placesGroups.length} orígenes',
      CollectionKind.recent =>
        controller.recentWeek.isEmpty
            ? 'Nada en los últimos 7 días'
            : '${controller.recentWeek.length} elementos',
      CollectionKind.people =>
        controller.peoplePhotos.isEmpty
            ? 'Sin selfies todavía'
            : '${controller.peoplePhotos.length} elementos',
      CollectionKind.documents =>
        controller.documentPhotos.isEmpty
            ? 'Sin documentos todavía'
            : '${controller.documentPhotos.length} elementos',
      CollectionKind.hd =>
        controller.hdPhotos.isEmpty
            ? 'Sin fotos HD todavía'
            : '${controller.hdPhotos.length} elementos',
      CollectionKind.locked =>
        controller.privatePhotos.isEmpty
            ? 'Vacía'
            : '${controller.privatePhotos.length} elementos',
      CollectionKind.hiddenAlbums =>
        controller.hiddenAlbums.isEmpty
            ? 'Ningún álbum oculto'
            : '${controller.hiddenAlbums.length} álbumes',
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
          switch (kind) {
            case CollectionKind.recent:
              return _PhotosGrid(
                controller: controller,
                photos: controller.recentWeek,
                emptyIcon: Icons.access_time_outlined,
                emptyTitle: 'Nada en los últimos 7 días',
                emptySubtitle: 'Lo nuevo de esta semana aparecerá aquí.',
              );
            case CollectionKind.people:
              return _PhotosGrid(
                controller: controller,
                photos: controller.peoplePhotos,
                emptyIcon: Icons.people_outline,
                emptyTitle: 'Sin personas todavía',
                emptySubtitle:
                    'v1 por aproximación: selfies y cámara frontal.',
              );
            case CollectionKind.documents:
              return _PhotosGrid(
                controller: controller,
                photos: controller.documentPhotos,
                emptyIcon: Icons.description_outlined,
                emptyTitle: 'Sin documentos todavía',
                emptySubtitle: 'Documentos y escaneos aparecerán aquí.',
              );
            case CollectionKind.hd:
              return _PhotosGrid(
                controller: controller,
                photos: controller.hdPhotos,
                emptyIcon: Icons.hd_outlined,
                emptyTitle: 'Sin fotos HD todavía',
                emptySubtitle: 'Fotos de 12 MP o más.',
              );
            case CollectionKind.locked:
              return _PrivateGrid(controller: controller);
            case CollectionKind.places:
              return _PlacesGrid(controller: controller);
            case CollectionKind.hiddenAlbums:
              return _HiddenAlbumsGrid(controller: controller);
            case CollectionKind.videos:
            case CollectionKind.archive:
            case CollectionKind.trash:
              // No viven en Colecciones (pineados en Álbumes o sin lógica).
              return NEmptyState(
                icon: kind.icon,
                title: kind.label,
                subtitle: kind.description,
              );
          }
        },
      ),
    );
  }
}

/// Grilla de colección con visor: plana y ordenada A→Z/Z→A.
/// (La vista compacta/por grupo vive en la lista de colecciones.)
class _PhotosGrid extends StatelessWidget {
  final GalleryController controller;
  final List<Photo> photos;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;

  const _PhotosGrid({
    required this.controller,
    required this.photos,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return NEmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    final sorted = controller.applyNameSort(photos);
    return NResponsiveGrid.dense(
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final photo = sorted[index];
        return GestureDetector(
          onTap: () => openPhotoViewer(
            context,
            controller: controller,
            photos: sorted,
            initialId: photo.id,
          ),
          child: PhotoTile(photo: photo, path: photo.path),
        );
      },
    );
  }
}

/// Carpeta privada v1: grilla + restaurar con long-press.
/// Sin bloqueo de momento: el pie lo declara con honestidad.
class _PrivateGrid extends StatelessWidget {
  final GalleryController controller;

  const _PrivateGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final items = controller.applyNameSort(controller.privatePhotos);
    if (items.isEmpty) {
      return const NEmptyState(
        icon: Icons.lock_outline,
        title: 'Carpeta privada vacía',
        subtitle: 'Mantén una foto de la galería para moverla aquí.',
      );
    }
    return Column(
      children: [
        Expanded(
          child: NResponsiveGrid.dense(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final photo = items[index];
              return GestureDetector(
                onTap: () => openPhotoViewer(
                  context,
                  controller: controller,
                  photos: items,
                  initialId: photo.id,
                ),
                onLongPress: () => _restore(context, photo),
                child: PhotoTile(photo: photo, path: photo.path),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(NSpacing.spaceMd),
          child: Text(
            'v1 sin bloqueo: cualquiera con el móvil abierto puede entrar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NTypography.fontFamilyBase,
              color: context.nMutedTextColor,
              fontSize: NTypography.sizeXs,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _restore(BuildContext context, Photo photo) async {
    await controller.restoreFromPrivate(photo.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Foto devuelta a su carpeta')),
      );
  }
}

/// Álbumes ocultos: lista con "Mostrar" para devolverlos a Álbumes.
class _HiddenAlbumsGrid extends StatelessWidget {
  final GalleryController controller;

  const _HiddenAlbumsGrid({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hidden = controller.hiddenAlbums;
    if (hidden.isEmpty) {
      return const NEmptyState(
        icon: Icons.visibility_outlined,
        title: 'No hay álbumes ocultos',
        subtitle: 'Oculta un álbum desde Álbumes para verlo aquí.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(NSpacing.spaceMd),
      itemCount: hidden.length,
      itemBuilder: (context, index) {
        final album = hidden[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: NSpacing.spaceSm),
          child: NCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.file(
                    File(album.coverPhoto.path),
                    fit: BoxFit.cover,
                    cacheWidth: 128,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).colorScheme.primary,
                      child: const Icon(
                        Icons.photo_album_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: NTypography.fontFamilyBase,
                  fontWeight: NTypography.weightSemibold,
                ),
              ),
              subtitle: Text('${album.photos.length} elementos'),
              trailing: TextButton(
                onPressed: () => controller.setAlbumHidden(album.path, false),
                child: const Text('Mostrar'),
              ),
            ),
          ),
        );
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
    final located = controller.photosWithLocation;
    if (groups.isEmpty && located.isEmpty) {
      return const NEmptyState(
        icon: Icons.place_outlined,
        title: 'Sin lugares todavía',
        subtitle: 'Tus carpetas de origen aparecerán aquí.',
      );
    }
    // El orden A→Z/Z→A del popup ordena las carpetas.
    final entries = groups.entries.toList()
      ..sort(
        (a, b) => controller.collectionsSort == CollectionsSort.az
            ? a.key.toLowerCase().compareTo(b.key.toLowerCase())
            : b.key.toLowerCase().compareTo(a.key.toLowerCase()),
      );
    return ListView.builder(
      padding: const EdgeInsets.all(NSpacing.spaceMd),
      itemCount: entries.length + (located.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        // Primera sección: fotos con GPS EXIF real.
        if (located.isNotEmpty && index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _GroupHeader(title: 'Con ubicación'),
              _InlineGrid(
                controller: controller,
                photos: located,
              ),
              const SizedBox(height: NSpacing.spaceLg),
            ],
          );
        }
        final entry = entries[located.isEmpty ? index : index - 1];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GroupHeader(title: entry.key),
            _InlineGrid(
              controller: controller,
              photos: entry.value,
            ),
            const SizedBox(height: NSpacing.spaceLg),
          ],
        );
      },
    );
  }
}

/// Cabecera de grupo de Lugares.
class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return NSectionLabel(
      title: title,
      color: context.nPrimaryTextColor,
      padding: const EdgeInsets.only(bottom: NSpacing.spaceSm),
    );
  }
}

/// Mini-grilla 3 columnas con visor, reutilizada por cada grupo.
class _InlineGrid extends StatelessWidget {
  final GalleryController controller;
  final List<Photo> photos;

  const _InlineGrid({required this.controller, required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: photos.length,
      itemBuilder: (context, photoIndex) {
        final photo = photos[photoIndex];
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
  }
}
