import 'dart:io';

import 'package:flutter/material.dart';

import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

class AlbumViewPage extends StatefulWidget {
  const AlbumViewPage({super.key, required this.album});

  final Album album;

  @override
  State<AlbumViewPage> createState() => _AlbumViewPageState();
}

class _AlbumViewPageState extends State<AlbumViewPage> {
  late Future<List<Photo>> _photos;

  @override
  void initState() {
    super.initState();
    _photos = _load();
  }

  Future<List<Photo>> _load() async {
    final controller = await StoreController.instance();
    return controller.photosForPaths(widget.album.photoPaths);
  }

  Future<void> _addFromGallery() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final currentPaths = widget.album.photoPaths.toSet();
    final candidates =
        controller.photos.where((p) => !currentPaths.contains(p.path)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero abre una carpeta en la pestaña Galería'),
        ),
      );
      return;
    }
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _PickPhotosDialog(candidates: candidates),
    );
    if (selected != null && selected.isNotEmpty) {
      await controller.addToAlbum(widget.album.id, selected.toList());
      if (mounted) {
        widget.album.photoPaths.addAll(selected);
        setState(() => _photos = _load());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.album.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_add),
            tooltip: 'Añadir fotos',
            onPressed: _addFromGallery,
          ),
        ],
      ),
      body: FutureBuilder<List<Photo>>(
        future: _photos,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          return ThumbnailGrid(
            photos: photos,
            showFavoriteBadge: false,
            onRemoveRequest: (photo) async {
              final controller = await StoreController.instance();
              await controller.removeFromAlbum(widget.album.id, [photo.path]);
              widget.album.photoPaths.remove(photo.path);
              if (mounted) setState(() => _photos = _load());
            },
          );
        },
      ),
    );
  }
}

class _PickPhotosDialog extends StatefulWidget {
  const _PickPhotosDialog({required this.candidates});

  final List<Photo> candidates;

  @override
  State<_PickPhotosDialog> createState() => _PickPhotosDialogState();
}

class _PickPhotosDialogState extends State<_PickPhotosDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar fotos'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: widget.candidates.length,
          itemBuilder: (context, index) {
            final photo = widget.candidates[index];
            final isSelected = _selected.contains(photo.path);
            return GestureDetector(
              onTap: () => setState(() {
                if (isSelected) {
                  _selected.remove(photo.path);
                } else {
                  _selected.add(photo.path);
                }
              }),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(photo.path),
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFEEEEEE)),
                  ),
                  if (isSelected)
                    Container(
                      color: Colors.black45,
                      child: const Icon(Icons.check_circle, color: Colors.white),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text('Añadir (${_selected.length})'),
        ),
      ],
    );
  }
}