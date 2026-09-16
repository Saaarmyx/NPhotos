import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core.dart';
import '../rust/api.dart';

class PhotoViewPage extends StatefulWidget {
  const PhotoViewPage({
    super.key,
    required this.photos,
    required this.initialIndex,
    this.onChanged,
  });

  final List<Photo> photos;
  final int initialIndex;
  final VoidCallback? onChanged;

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  late final PageController _controller;
  late int _index;
  int _rotation = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Photo get _photo => widget.photos[_index];

  Future<void> _reloadCurrent() async {
    final controller = await StoreController.instance();
    final fresh = await controller.photosForPaths([_photo.path]);
    if (fresh.isNotEmpty) {
      widget.photos[_index] = fresh.first;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleFavorite() async {
    final controller = await StoreController.instance();
    await controller.toggleFavorite(_photo);
    await _reloadCurrent();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.photos[_index].isFavorite
                ? 'Marcada como favorita'
                : 'Quitada de favoritos',
          ),
        ),
      );
    }
    widget.onChanged?.call();
  }

  Future<void> _addToAlbum() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final album = await showDialog<Album>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Elegir álbum'),
        children: [
          for (final a in controller.albums)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, a),
              child: Text(a.name),
            ),
        ],
      ),
    );
    if (album != null) {
      await controller.addToAlbum(album.id, [_photo.path]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añadida al álbum')),
        );
      }
      widget.onChanged?.call();
    }
  }

  void _rotate() => setState(() => _rotation = (_rotation + 90) % 360);

  Future<void> _delete() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final path = _photo.path;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: Text('¿Borrar "${_photo.name}" definitivamente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.deletePhoto(path);
    if (!mounted) return;

    final removedIndex = widget.photos.indexWhere((p) => p.path == path);
    if (removedIndex != -1) widget.photos.removeAt(removedIndex);
    if (widget.photos.isEmpty) {
      Navigator.of(context).pop();
    } else {
      final newIndex = removedIndex.clamp(0, widget.photos.length - 1);
      setState(() => _index = newIndex);
      _controller.jumpToPage(newIndex);
    }
    widget.onChanged?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.name),
        actions: [
          IconButton(
            icon: Icon(
              photo.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: photo.isFavorite ? Colors.red : null,
            ),
            tooltip: 'Favorita',
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'album':
                  _addToAlbum();
                case 'rotate':
                  _rotate();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'album',
                child: ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('Añadir a álbum'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'rotate',
                child: ListTile(
                  leading: Icon(Icons.rotate_90_degrees_ccw_outlined),
                  title: Text('Rotar 90°'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Eliminar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _rotation = 0;
        }),
        itemBuilder: (context, index) {
          final p = widget.photos[index];
          return Center(
            child: _zoomable(
              p,
            ),
          );
        },
      ),
      bottomNavigationBar: _MetadataBar(
        photo: photo,
        onRotate: _rotate,
        onDelete: _delete,
      ),
    );
  }

  Widget _zoomable(Photo p) {
    final file = File(p.path);
    final widget = Image.file(
      file,
      fit: BoxFit.contain,
      errorBuilder: (_, _, err) => Center(
        child: Text(
          'No se pudo cargar la imagen\n$err',
          style: const TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      ),
    );
    return InteractiveViewer(
      maxScale: 8,
      child: Transform.rotate(
        angle: _rotation * 3.141592653589793 / 180,
        child: widget,
      ),
    );
  }
}

class _MetadataBar extends StatelessWidget {
  const _MetadataBar({
    required this.photo,
    required this.onRotate,
    required this.onDelete,
  });

  final Photo photo;
  final VoidCallback onRotate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (photo.sizeBytes.toDouble() / 1048576).toStringAsFixed(2);
    final date = photo.takenAt == null
        ? 'Sin fecha'
        : DateFormat('dd MMM yyyy HH:mm').format(
            DateTime.tryParse(photo.takenAt!) ?? DateTime.now(),
          );
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${photo.width}x${photo.height}  •  $sizeMb MB  •  $date',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.rotate_90_degrees_ccw_outlined,
                    color: Colors.white70),
                tooltip: 'Rotar 90°',
                onPressed: onRotate,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white70),
                tooltip: 'Eliminar',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}