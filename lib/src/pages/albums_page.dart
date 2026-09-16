import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/album_card.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';
import 'album_view_page.dart';

class AlbumsPage extends StatefulWidget {
  const AlbumsPage({super.key});

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  Future<void> _createAlbum() async {
    final name = await askAlbumNameFromAlbums(context);
    if (name == null || name.isEmpty) return;
    final controller = await StoreController.instance();
    await controller.createAlbum(name);
    if (mounted) setState(() {});
  }

  Future<void> _open(Album album) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AlbumViewPage(album: album)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreController>(
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
              onTap: () => _open(album),
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
    );
  }
}

/// Helpers de nombre de álbum (aprovecha el diálogo compartido de galería).
Future<String?> askAlbumNameFromAlbums(
  BuildContext context, {
  String? initial,
}) => askAlbumName(context, initial: initial);
