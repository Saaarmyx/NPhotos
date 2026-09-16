import 'dart:typed_data';

import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StoreController>(
      future: StoreController.instance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final controller = snapshot.data!;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Álbumes'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                tooltip: 'Nuevo álbum',
                onPressed: () async {
                  final name = await askAlbumName(context);
                  if (name != null && name.isNotEmpty) {
                    await controller.createAlbum(name);
                    if (mounted) setState(() {});
                  }
                },
              ),
            ],
          ),
          body: controller.albums.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Crea tu primer álbum'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: controller.albums.length,
                  itemBuilder: (context, index) {
                    final album = controller.albums[index];
                    return Card(
                      child: ListTile(
                        leading: _Cover(album: album),
                        title: Text(album.name),
                        subtitle: Text(
                          '${album.photoPaths.length} fotos',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'rename') {
                              final newName = await askAlbumName(context,
                                  initial: album.name);
                              if (newName != null && newName.isNotEmpty) {
                                await controller.renameAlbum(album.id, newName);
                                if (mounted) setState(() {});
                              }
                            } else if (value == 'delete') {
                              await controller.deleteAlbum(album.id);
                              if (mounted) setState(() {});
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumViewPage(album: album),
                            ),
                          );
                          if (mounted) setState(() {});
                        },
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    if (album.photoPaths.isEmpty) {
      return const SizedBox(
        width: 52,
        height: 52,
        child: Icon(Icons.photo_library_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 52,
        height: 52,
        child: FutureBuilder<Uint8List?>(
          future: StoreController.instance().then(
            (c) => c.thumbnail(album.photoPaths.first, size: 128),
          ),
          builder: (context, snapshot) {
            final bytes = snapshot.data;
            if (bytes != null) {
              return Image.memory(bytes, fit: BoxFit.cover);
            }
            return const ColoredBox(color: Color(0xFFE8E8E8));
          },
        ),
      ),
    );
  }
}