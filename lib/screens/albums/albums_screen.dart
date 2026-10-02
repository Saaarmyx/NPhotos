// lib/screens/albums/albums_screen.dart
//
// - Pines (máx 4, gestionables): cuadrícula 2 columnas o filas de lista.
// - Listas del sistema no pineadas (Favoritos, Vídeos, Papelera) en filas.
// - Álbumes: cuadrícula 3 columnas o filas de lista.
// - El popup de la topbar controla vista (lista/cuadrícula) y qué
//   secciones/portadas se ocultan.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:NexoraUi/NexoraUi.dart';

import '../../controllers/gallery_controller.dart';
import '../../controllers/selection_controller.dart';
import '../../models/photo.dart';
import '../../widgets/album_actions_sheet.dart';
import '../../widgets/trash_grid.dart';
import 'album_detail_screen.dart';
import '../favorites/favorites_screen.dart';
import '../trash/trash_screen.dart';
import '../videos/videos_screen.dart';
import '../../widgets/photo_tile.dart';

class AlbumsScreen extends StatelessWidget {
  final GalleryController controller;
  final SelectionController selection;

  const AlbumsScreen({
    super.key,
    required this.controller,
    required this.selection,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, selection]),
      builder: (context, _) {
        final pins = controller.hidePins
            ? const <AlbumPin>[]
            : controller.pins;
        final albums = controller.hideAlbums
            ? const <Album>[]
            : controller.unpinnedAlbums;
        final isList = controller.albumsViewMode == AlbumsViewMode.list;
        final hideCovers = controller.hideCovers;

        if (controller.hidePins && controller.hideAlbums) {
          return const NEmptyState(
            icon: Icons.visibility_off_outlined,
            title: 'Todo oculto',
            subtitle: 'Activa Pines o Álbumes desde el popup (⋮).',
          );
        }
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: NSpacing.spaceMd),
            ),
            if (!controller.hidePins) ...[
              if (pins.isEmpty)
                const SliverToBoxAdapter(child: _EmptyPinsHint())
              else if (isList)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NSpacing.spaceMd,
                    ),
                    child: _SystemRowsCard(
                      rows: [
                        for (final pin in pins)
                          _SystemRow(
                            icon: pin.icon,
                            tint: pin.tint,
                            title: pin.title,
                            count: pin.count,
                            cover: hideCovers ? null : pin.cover,
                            onTap: () => _openPin(context, pin),
                            onLongPress: () => _unpin(context, pin),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.spaceMd,
                  ),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pin = pins[index];
                        return _PinCard(
                          pin: pin,
                          hideCovers: hideCovers,
                          onTap: () => _openPin(context, pin),
                          onLongPress: () => _pinActions(context, pin),
                        );
                      },
                      childCount: pins.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: NSpacing.spaceSm,
                          mainAxisSpacing: NSpacing.spaceSm,
                          // Alto fijo: evita el overflow vertical en pines.
                          mainAxisExtent: 78,
                        ),
                  ),
                ),
            ],
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  if (controller.hideSystem) {
                    return const SizedBox.shrink();
                  }
                  final systemRows = _systemRows(context);
                  if (systemRows.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NSpacing.spaceMd,
                      NSpacing.spaceMd,
                      NSpacing.spaceMd,
                      0,
                    ),
                    child: _SystemRowsCard(rows: systemRows),
                  );
                },
              ),
            ),
            if (!controller.hideAlbums) ...[
              if (albums.isEmpty && pins.isNotEmpty)
                const SliverToBoxAdapter(
                  child: NEmptyState(
                    icon: Icons.photo_album_outlined,
                    title: 'No hay más álbumes',
                  ),
                )
              else if (albums.isNotEmpty && isList)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NSpacing.spaceMd,
                      NSpacing.spaceMd,
                      NSpacing.spaceMd,
                      NSpacing.spaceMd,
                    ),
                    child: NCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        children: [
                          for (var i = 0; i < albums.length; i++)
                            _AlbumRowTile(
                              album: albums[i],
                              hideCovers: hideCovers,
                              isLast: i == albums.length - 1,
                              onTap: () => _onAlbumTap(context, albums[i]),
                              onLongPress: () =>
                                  _onAlbumLongPress(context, albums[i]),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (albums.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    NSpacing.spaceMd,
                    NSpacing.spaceMd,
                    NSpacing.spaceMd,
                    NSpacing.spaceMd,
                  ),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final album = albums[index];
                        return _AlbumTile(
                          album: album,
                          hideCovers: hideCovers,
                          onTap: () => _onAlbumTap(context, album),
                          onLongPress: () => _onAlbumLongPress(context, album),
                        );
                      },
                      childCount: albums.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: NSpacing.spaceSm,
                          mainAxisSpacing: NSpacing.spaceSm,
                          childAspectRatio: 0.78,
                        ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  /// Listas del sistema que no están pineadas (evita duplicarlas).
  List<_SystemRow> _systemRows(BuildContext context) {
    final rows = <_SystemRow>[];
    if (!controller.isPinned(GalleryController.favoritesPinId)) {
      rows.add(
        _SystemRow(
          icon: Icons.favorite_border,
          tint: Colors.pink,
          title: 'Favoritos',
          count: controller.favoritePhotos.length,
          onTap: () => pushNPage(
            context,
            FavoritesScreen(controller: controller, selection: selection),
          ),
        ),
      );
    }
    if (!controller.isPinned(GalleryController.videosPinId)) {
      rows.add(
        _SystemRow(
          icon: Icons.videocam_outlined,
          tint: Colors.red,
          title: 'Vídeos',
          count: controller.videos.length,
          onTap: () => pushNPage(
            context,
            VideosScreen(controller: controller, selection: selection),
          ),
        ),
      );
    }
    if (!controller.isPinned(GalleryController.trashPinId)) {
      rows.add(
        _SystemRow(
          icon: Icons.delete_outline,
          tint: Colors.grey,
          title: 'Papelera',
          count: controller.trash.length,
          onTap: () => pushNPage(
            context,
            TrashScreen(controller: controller, selection: selection),
          ),
        ),
      );
    }
    return rows;
  }

  void _openPin(BuildContext context, AlbumPin pin) {
    switch (pin.id) {
      case GalleryController.videosPinId:
        pushNPage(context, VideosScreen(controller: controller, selection: selection));
        break;
      case GalleryController.trashPinId:
        pushNPage(context, TrashScreen(controller: controller, selection: selection));
        break;
      case GalleryController.favoritesPinId:
        pushNPage(context, FavoritesScreen(controller: controller, selection: selection));
        break;
      default:
        for (final album in controller.albums) {
          if (album.path == pin.albumPath) {
            _openAlbum(context, album);
            return;
          }
        }
    }
  }

  Future<void> _unpin(BuildContext context, AlbumPin pin) async {
    await controller.togglePin(pin.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pin quitado')));
  }

  /// Toque en un álbum. En modo selección alterna; si no, abre.
  void _onAlbumTap(BuildContext context, Album album) {
    if (selection.isActive && selection.kind == SelectionKind.albums) {
      selection.toggle(album.path);
      return;
    }
    _openAlbum(context, album);
  }

  /// Mantener presionado inicia (o amplía) la selección de álbumes.
  void _onAlbumLongPress(BuildContext context, Album album) {
    if (selection.isActive && selection.kind == SelectionKind.albums) {
      selection.toggle(album.path);
      return;
    }
    if (selection.isActive) return; // selección de fotos: no interferir.
    selection.selectOnly(album.path, kind: SelectionKind.albums);
  }

  /// Acciones de un pin (mantener presionado). Sin pinear/eliminar.
  Future<void> _pinActions(BuildContext context, AlbumPin pin) async {
    if (!pin.isAlbum) return; // los de sistema no se renombran.
    final album = controller.albums
        .where((a) => a.path == pin.albumPath)
        .firstOrNull;
    if (album == null) return;
    final action = await showAlbumActionsSheet(
      context,
      controller: controller,
      title: album.name,
      isPinned: true,
      isHidden: album.hidden,
      isSystem: false,
    );
    if (action == null || !context.mounted) return;
    await _runAlbumAction(context, album, action);
  }

  Future<void> _runAlbumAction(
    BuildContext context,
    Album album,
    AlbumAction action,
  ) async {
    switch (action) {
      case AlbumAction.togglePin:
        await _pinAlbum(context, album);
        break;

      case AlbumAction.rename:
        final name = await showAlbumRenameDialog(
          context,
          currentName: album.name,
        );
        if (name == null || !context.mounted) return;
        final ok = await controller.renameAlbum(album.path, name);
        if (!context.mounted) return;
        _toast(context, ok ? 'Álbum renombrado' : 'No se pudo renombrar');

      case AlbumAction.changeCover:
        final cover = await showAlbumCoverPicker(
          context,
          controller: controller,
          albumPath: album.path,
        );
        if (cover == null) return; // null = "Automática" no cambia nada.
        await controller.setAlbumCover(album.path, cover);
        if (!context.mounted) return;
        _toast(context, 'Carátula actualizada');

      case AlbumAction.hide:
        await controller.setAlbumHidden(album.path, true);
        if (!context.mounted) return;
        _toast(context, 'Álbum oculto');

      case AlbumAction.unhide:
        await controller.setAlbumHidden(album.path, false);
        if (!context.mounted) return;
        _toast(context, 'Álbum visible');

      case AlbumAction.delete:
        final confirmed = await confirmDestructive(
          context,
          title: 'Eliminar álbum',
          message:
              'Se borrará la carpeta "${album.name}" y todas sus fotos. '
              'No se puede deshacer.',
        );
        if (!confirmed || !context.mounted) return;
        final ok = await controller.deleteAlbum(album.path);
        if (!context.mounted) return;
        _toast(context, ok ? 'Álbum eliminado' : 'No se pudo eliminar');
    }
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pinAlbum(BuildContext context, Album album) async {
    final ok = await controller.togglePin('album:${album.path}');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Álbum fijado en Pines' : 'Solo puedes fijar 4 pines',
          ),
        ),
      );
  }

  void _openAlbum(BuildContext context, Album album) {
    pushNPage(
      context,
      AlbumDetailScreen(album: album, controller: controller),
    );
  }
}

class _EmptyPinsHint extends StatelessWidget {
  const _EmptyPinsHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.spaceMd),
      child: NCard(
        child: Row(
          children: [
            Icon(
              Icons.push_pin_outlined,
              color: context.nMutedTextColor,
              size: 20,
            ),
            const SizedBox(width: NSpacing.spaceSm),
            Expanded(
              child: Text(
                'Sin pines. Mantén presionado un álbum para fijarlo aquí (máx 4).',
                style: TextStyle(
                  fontFamily: NTypography.fontFamilyBase,
                  color: context.nBodyTextColor,
                  fontSize: NTypography.sizeXs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de pin: portada (foto) o icono + nombre + cantidad.
/// Tap abre, mantener presionado abre las acciones.
class _PinCard extends StatelessWidget {
  final AlbumPin pin;
  final bool hideCovers;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PinCard({
    required this.pin,
    required this.hideCovers,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: NSpacing.spaceSm,
          vertical: NSpacing.spaceXs,
        ),
        decoration: BoxDecoration(
          color: context.nSurfaceTranslucentColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            _PinLeading(pin: pin, hideCovers: hideCovers),
            const SizedBox(width: NSpacing.spaceSm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pin.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightBold,
                      fontSize: NTypography.sizeMd,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                  Text(
                    '${pin.count}',
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontSize: NTypography.sizeXs,
                      color: context.nMutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portada del pin: foto recortada o icono con tinte.
class _PinLeading extends StatelessWidget {
  final AlbumPin pin;
  final bool hideCovers;
  const _PinLeading({required this.pin, this.hideCovers = false});

  @override
  Widget build(BuildContext context) {
    final cover = hideCovers ? null : pin.cover;
    return NIconTile(
      icon: pin.icon,
      color: pin.tint,
      image: cover == null
          ? null
          : Image.file(
              File(cover.path),
              fit: BoxFit.cover,
              cacheWidth: 128,
              errorBuilder: (_, _, _) =>
                  NIconTile(icon: pin.icon, color: pin.tint),
            ),
    );
  }
}

class _SystemRow {
  final IconData icon;
  final Color tint;
  final String title;
  final int count;
  final Photo? cover;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SystemRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.count,
    this.cover,
    required this.onTap,
    this.onLongPress,
  });
}

/// Filas de ancho completo con chevron (pines en modo lista y listas
/// del sistema), como la referencia.
class _SystemRowsCard extends StatelessWidget {
  final List<_SystemRow> rows;
  const _SystemRowsCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return NCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _SystemRowTile(row: rows[i], isLast: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _SystemRowTile extends StatelessWidget {
  final _SystemRow row;
  final bool isLast;
  const _SystemRowTile({required this.row, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final cover = row.cover;
    return InkWell(
      onTap: row.onTap,
      onLongPress: row.onLongPress,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(24))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NSpacing.spaceMd,
          vertical: NSpacing.spaceSm,
        ),
        child: Row(
          children: [
            if (cover != null)
              NIconTile(
                icon: row.icon,
                color: row.tint,
                image: Image.file(
                  File(cover.path),
                  fit: BoxFit.cover,
                  cacheWidth: 128,
                  errorBuilder: (_, _, _) =>
                      NIconTile(icon: row.icon, color: row.tint),
                ),
              )
            else
              NIconTile(icon: row.icon, color: row.tint),
            const SizedBox(width: NSpacing.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightSemibold,
                      fontSize: NTypography.sizeMd,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                  Text(
                    '${row.count} elementos',
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      color: context.nBodyTextColor,
                      fontSize: NTypography.sizeXs,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.nBodyTextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Celda de álbum: portada redondeada + nombre y cantidad en la misma fila.
/// La portada de un álbum real va teñida con el color de acento; las de
/// sistema (Favoritos/Vídeos/Papelera) conservan su color propio.
class _AlbumTile extends StatelessWidget {
  final Album album;
  final bool hideCovers;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AlbumTile({
    required this.album,
    required this.hideCovers,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: double.infinity,
                child: hideCovers
                    ? Container(
                        color: accent,
                        child: Icon(
                          Icons.photo_album_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          PhotoTile(
                            photo: album.coverPhoto,
                            path: album.coverPhoto.path,
                            cacheWidth: 300,
                            width: double.infinity,
                          ),
                          // Tinte de acento sobre la portada del álbum.
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  accent.withValues(alpha: 0.18),
                                  accent.withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NTypography.fontFamilyBase,
                    fontWeight: NTypography.weightBold,
                    fontSize: NTypography.sizeMd,
                    color: context.nPrimaryTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${album.photos.length}',
                style: TextStyle(
                  fontFamily: NTypography.fontFamilyBase,
                  fontSize: NTypography.sizeSm,
                  color: context.nMutedTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de álbum en modo lista: portada + nombre y cantidad + chevron.
/// Tap abre, mantener presionado fija el pin.
class _AlbumRowTile extends StatelessWidget {
  final Album album;
  final bool hideCovers;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _AlbumRowTile({
    required this.album,
    required this.hideCovers,
    required this.isLast,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(24))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NSpacing.spaceMd,
          vertical: NSpacing.spaceSm,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: hideCovers
                    ? Container(
                        color: context.nSurfaceTranslucentColor,
                        child: Icon(
                          Icons.photo_album_outlined,
                          color: context.nMutedTextColor,
                          size: 22,
                        ),
                      )
                    : Image.file(
                        File(album.coverPhoto.path),
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                        errorBuilder: (_, _, _) => Container(
                          color: context.nSurfaceTranslucentColor,
                          child: Icon(
                            Icons.photo_album_outlined,
                            color: context.nMutedTextColor,
                            size: 22,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: NSpacing.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightSemibold,
                      fontSize: NTypography.sizeMd,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                  Text(
                    '${album.photos.length} elementos',
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      color: context.nBodyTextColor,
                      fontSize: NTypography.sizeXs,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.nBodyTextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
