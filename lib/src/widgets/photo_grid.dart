import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core.dart';
import '../pages/photo_view_page.dart';
import '../rust/api.dart';

class ThumbnailGrid extends StatelessWidget {
  const ThumbnailGrid({
    super.key,
    required this.photos,
    this.onChanged,
    this.showFavoriteBadge = true,
    this.onRemoveRequest,
  });

  final List<Photo> photos;
  final VoidCallback? onChanged;
  final bool showFavoriteBadge;
  final Future<void> Function(Photo photo)? onRemoveRequest;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(child: Text('No hay fotos aún'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoViewPage(
                  photos: photos,
                  initialIndex: index,
                  onChanged: onChanged,
                ),
              ),
            );
          },
          onLongPress: () => _showMenu(context, photo),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: _Thumb(photo: photo),
              ),
              if (showFavoriteBadge && photo.isFavorite)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.favorite, color: Colors.red, size: 18),
                ),
              Positioned(
                left: 4,
                bottom: 4,
                child: GestureDetector(
                  onTap: () => _toggleFavorite(photo),
                  child: Icon(
                    photo.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: photo.isFavorite ? Colors.red : Colors.white,
                    shadows: const [Shadow(blurRadius: 4, color: Colors.black45)],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(Photo photo) async {
    final controller = await StoreController.instance();
    await controller.toggleFavorite(photo);
    onChanged?.call();
  }

  Future<void> _showMenu(BuildContext context, Photo photo) async {
    final controller = await StoreController.instance();
    if (!context.mounted) return;
    final options = <String, String>{
      'fav': photo.isFavorite ? 'Quitar de favoritos' : 'Marcar como favorita',
      'album': 'Añadir a álbum',
    };
    if (onRemoveRequest != null) {
      options['remove'] = 'Quitar del álbum';
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final e in options.entries)
              ListTile(
                leading: Icon(
                  e.key == 'fav'
                      ? Icons.favorite
                      : e.key == 'album'
                          ? Icons.photo_library
                          : Icons.delete_outline,
                ),
                title: Text(e.value),
                onTap: () => Navigator.pop(context, e.key),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'fav') {
      await controller.toggleFavorite(photo);
      onChanged?.call();
    } else if (action == 'album') {
      await _addToAlbum(context, controller, photo);
    } else if (action == 'remove') {
      await onRemoveRequest?.call(photo);
      onChanged?.call();
    }
  }

  Future<void> _addToAlbum(
    BuildContext context,
    StoreController controller,
    Photo photo,
  ) async {
    if (controller.albums.isEmpty) {
      final name = await _askAlbumName(context);
      if (name == null) return;
      await controller.createAlbum(name);
    }
    if (!context.mounted) return;
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
      await controller.addToAlbum(album.id, [photo.path]);
      onChanged?.call();
    }
  }

  static Future<String?> _askAlbumName(BuildContext context, {String? initial}) =>
      showDialog<String>(
        context: context,
        builder: (context) => _NameDialog(title: 'Nuevo álbum', initial: initial),
      );
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.photo});

  final Photo photo;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List?> _load() async {
    final controller = await StoreController.instance();
    return controller.thumbnail(widget.photo.path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        }
        if (snapshot.hasError) {
          return const ColoredBox(color: Color(0xFFEEEEEE));
        }
        return const ColoredBox(color: Color(0xFFE8E8E8));
      },
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

Future<String?> askAlbumName(BuildContext context, {String? initial}) =>
    ThumbnailGrid._askAlbumName(context, initial: initial);