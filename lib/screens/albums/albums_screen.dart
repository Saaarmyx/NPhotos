// lib/screens/albums/albums_screen.dart
//
// - Arriba: 4 álbumes pineados (Cámara, Capturas, Vídeos, Papelera).
// - Abajo: parrilla de álbumes con carátula + nombre, nada más.
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';
import '../../widgets/photo_grid.dart';
import '../../widgets/photo_tile.dart';
import '../../widgets/trash_grid.dart';

class AlbumsScreen extends StatelessWidget {
  final GalleryController controller;
  const AlbumsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final camera = controller.cameraAlbum;
        final screenshots = controller.screenshotsAlbum;
        final videos = controller.videos;
        final trashCount = controller.trash.length;
        final albums = controller.unpinnedAlbums;

        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Fijados')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: NSpacing.spaceSm,
              ),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate([
                  _PinnedCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Cámara',
                    coverPath: camera?.coverPhoto.path,
                    count: camera?.photos.length ?? 0,
                    onTap: camera == null
                        ? null
                        : () => _openAlbum(context, camera),
                  ),
                  _PinnedCard(
                    icon: Icons.screenshot_monitor_outlined,
                    title: 'Capturas',
                    coverPath: screenshots?.coverPhoto.path,
                    count: screenshots?.photos.length ?? 0,
                    onTap: screenshots == null
                        ? null
                        : () => _openAlbum(context, screenshots),
                  ),
                  _PinnedCard(
                    icon: Icons.videocam_outlined,
                    title: 'Vídeos',
                    coverPath: videos.isEmpty ? null : videos.first.path,
                    isVideoCover: videos.isNotEmpty,
                    count: videos.length,
                    onTap: () => _openPhotos(
                      context,
                      title: 'Vídeos',
                      icon: Icons.videocam_outlined,
                      photos: videos,
                      emptyTitle: 'No hay vídeos',
                    ),
                  ),
                  _PinnedCard(
                    icon: Icons.delete_outline,
                    title: 'Papelera',
                    coverPath: controller.trash.isEmpty
                        ? null
                        : controller.trash.first.photo.path,
                    count: trashCount,
                    onTap: () => _openTrash(context),
                  ),
                ]),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: NSpacing.spaceSm,
                      mainAxisSpacing: NSpacing.spaceSm,
                      childAspectRatio: 1.6,
                    ),
              ),
            ),
            const SliverToBoxAdapter(child: _SectionHeader(title: 'Álbumes')),
            if (albums.isEmpty)
              const SliverToBoxAdapter(
                child: NEmptyState(
                  icon: Icons.photo_album_outlined,
                  title: 'No hay más álbumes',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(NSpacing.spaceSm),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      return GestureDetector(
                        onTap: () => _openAlbum(context, album),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: PhotoTile(
                                path: album.coverPhoto.path,
                                isVideo: album.coverPhoto.isVideo,
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
                          ],
                        ),
                      );
                    },
                    childCount: albums.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: NSpacing.spaceSm,
                        mainAxisSpacing: NSpacing.spaceSm,
                        childAspectRatio: 0.85,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openAlbum(BuildContext context, Album album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _AlbumDetailScreen(album: album, controller: controller),
      ),
    );
  }

  void _openPhotos(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Photo> photos,
    required String emptyTitle,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotosDetailScreen(
          title: title,
          icon: icon,
          photos: photos,
          emptyTitle: emptyTitle,
        ),
      ),
    );
  }

  void _openTrash(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrashDetailScreen(controller: controller),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NSpacing.spaceMd,
        NSpacing.spaceMd,
        NSpacing.spaceMd,
        NSpacing.spaceSm,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: NTypography.fontFamilyBase,
          fontWeight: NTypography.weightBold,
          fontSize: NTypography.sizeMd,
          color: context.nPrimaryTextColor,
        ),
      ),
    );
  }
}

/// Tarjeta pineada: carátula (o icono si está vacío) + nombre + conteo.
class _PinnedCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? coverPath;
  final bool isVideoCover;
  final int count;
  final VoidCallback? onTap;

  const _PinnedCard({
    required this.icon,
    required this.title,
    this.coverPath,
    this.isVideoCover = false,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cover = coverPath;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null && count == 0 ? 0.6 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: cover == null
                    ? Container(
                        color: context.nSurfaceTranslucentColor,
                        child: Icon(
                          icon,
                          color: context.nMutedTextColor,
                          size: 32,
                        ),
                      )
                    : PhotoTile(
                        path: cover,
                        isVideo: isVideoCover,
                        cacheWidth: 300,
                        width: double.infinity,
                      ),
              ),
            ),
            const SizedBox(height: NSpacing.space2xs),
            Row(
              children: [
                Icon(icon, size: 16, color: context.nMutedTextColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NTypography.fontFamilyBase,
                      fontWeight: NTypography.weightBold,
                      fontSize: NTypography.sizeSm,
                      color: context.nPrimaryTextColor,
                    ),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontFamily: NTypography.fontFamilyBase,
                    fontSize: NTypography.sizeXs,
                    color: context.nMutedTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista Detalle del Álbum
class _AlbumDetailScreen extends StatelessWidget {
  final Album album;
  final GalleryController controller;

  const _AlbumDetailScreen({required this.album, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(title: album.name),
      body: PhotoGrid.photos(
        itemCount: album.photos.length,
        itemBuilder: (context, index) {
          final photo = album.photos[index];
          return PhotoTile(path: photo.path, isVideo: photo.isVideo);
        },
      ),
    );
  }
}

/// Detalle genérico para listas sintéticas (Vídeos).
class _PhotosDetailScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Photo> photos;
  final String emptyTitle;

  const _PhotosDetailScreen({
    required this.title,
    required this.icon,
    required this.photos,
    required this.emptyTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(title: title),
      body: photos.isEmpty
          ? NEmptyState(icon: icon, title: emptyTitle)
          : PhotoGrid.photos(
              itemCount: photos.length,
              itemBuilder: (context, index) {
                final photo = photos[index];
                return PhotoTile(path: photo.path, isVideo: photo.isVideo);
              },
            ),
    );
  }
}

/// Detalle de Papelera con vaciado.
class _TrashDetailScreen extends StatelessWidget {
  final GalleryController controller;

  const _TrashDetailScreen({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NSecondaryTopBar(
        title: 'Papelera',
        actions: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => controller.trash.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: 'Vaciar papelera',
                    onPressed: () async {
                      final confirmed = await confirmDestructive(
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
        builder: (context, _) => TrashGrid(controller: controller),
      ),
    );
  }
}
