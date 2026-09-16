import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/album_card.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../widgets/photo_grid.dart' show askAlbumName;
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';
import 'album_view_page.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _createAlbum() async {
    final name = await askAlbumNameFromAlbums(context);
    if (name == null || name.isEmpty) return;
    final controller = await StoreController.instance();
    await controller.createAlbum(name);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Albums',
          subtitle: 'Your collections, organized',
          trailing: NPhotosNewAlbumButton(onPressed: _createAlbum),
        ),
        Expanded(
          child: FutureBuilder<StoreController>(
            future: StoreController.instance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const NPhotosLoadingState();
              }
              final controller = snapshot.data!;
              if (controller.albums.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Create your first album',
                  subtitle:
                      'Group your favorite moments, trips and memories together.',
                  actionLabel: 'New Album',
                  onAction: _createAlbum,
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  NXSpace.s24,
                  NXSpace.s4,
                  NXSpace.s24,
                  NXSpace.s32,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  crossAxisSpacing: NXSpace.s20,
                  mainAxisSpacing: NXSpace.s20,
                ),
                itemCount: controller.albums.length,
                itemBuilder: (context, index) {
                  final album = controller.albums[index];
                  return NPhotosAlbumCard(
                    album: album,
                    variant: album.id.hashCode,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlbumViewPage(album: album),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    onRename: () async {
                      final newName = await askAlbumNameFromAlbums(
                        context,
                        initial: album.name,
                      );
                      if (newName == null || newName.isEmpty) return;
                      final c = await StoreController.instance();
                      await c.renameAlbum(album.id, newName);
                      if (mounted) setState(() {});
                    },
                    onDelete: () async {
                      final c = await StoreController.instance();
                      await c.deleteAlbum(album.id);
                      if (mounted) setState(() {});
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class NPhotosNewAlbumButton extends StatelessWidget {
  const NPhotosNewAlbumButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NXSpace.s12, vertical: NXSpace.s6),
      decoration: BoxDecoration(
        color: NexoraPalette.of(context).surface,
        borderRadius: BorderRadius.circular(NXRadius.radius10),
        border: Border.all(color: NexoraPalette.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_rounded, size: 16, color: NexoraPalette.of(context).textPrimary),
          const SizedBox(width: NXSpace.s6),
          Text(
            'New Album',
            style: NXText.albumName(context).copyWith(color: NexoraPalette.of(context).textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Helpers de nombre de álbum (aprovecha el diálogo compartido de galería).
Future<String?> askAlbumNameFromAlbums(BuildContext context, {String? initial}) =>
    askAlbumName(context, initial: initial);

/// Portada de álbum (mantiene la lógica de miniatura local, reutilizable).
class AlbumCover extends StatelessWidget {
  const AlbumCover({super.key, required this.album, this.size = 48});

  final Album album;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (album.photoPaths.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.photo_library_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(NXRadius.radius8),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder<Uint8List?>(
          future: StoreController.instance()
              .then((c) => c.thumbnail(album.photoPaths.first, size: 128)),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null) {
              return Image.memory(bytes, fit: BoxFit.cover);
            }
            return ColoredBox(color: NexoraPalette.of(context).placeholderA);
          },
        ),
      ),
    );
  }
}