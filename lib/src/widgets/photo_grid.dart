import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core.dart';
import '../pages/photo_view_page.dart';
import '../rust/api.dart';

enum PhotoGroupBy { none, year, month }

class ThumbnailGrid extends StatelessWidget {
  const ThumbnailGrid({
    super.key,
    required this.photos,
    this.columns = 4,
    this.groupBy = PhotoGroupBy.none,
    this.onChanged,
    this.showFavoriteBadge = true,
    this.onRemoveRequest,
  });

  final List<Photo> photos;
  final int columns;
  final PhotoGroupBy groupBy;
  final VoidCallback? onChanged;
  final bool showFavoriteBadge;
  final Future<void> Function(Photo photo)? onRemoveRequest;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const Center(child: Text('No hay fotos aún'));
    }
    if (groupBy == PhotoGroupBy.none) {
      return _buildGrid(context, photos);
    }
    return _buildGrouped();
  }

  Map<String, List<Photo>> _groups() {
    final map = <String, List<Photo>>{};
    for (final photo in photos) {
      final key = switch (groupBy) {
        PhotoGroupBy.year => DateTime.tryParse(photo.takenAt ?? '')?.year.toString(),
        PhotoGroupBy.month => DateTime.tryParse(photo.takenAt ?? '')
            ?.toIso8601String()
            .substring(0, 7),
        PhotoGroupBy.none => null,
      } ?? 'sin_fecha';
      map.putIfAbsent(key, () => []).add(photo);
    }
    // orden descendente (más reciente primero); 'sin_fecha' al final
    final sorted = map.keys
        .where((k) => k != 'sin_fecha')
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (map.containsKey('sin_fecha')) sorted.add('sin_fecha');
    return {for (final k in sorted) k: map[k]!};
  }

  Widget _buildGrouped() {
    final groups = _groups();
    final keys = groups.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final groupPhotos = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              child: Text(
                key == 'sin_fecha'
                    ? 'Sin fecha'
                    : (groupBy == PhotoGroupBy.year
                        ? key
                        : DateFormat('MMMM yyyy').format(
                            DateTime.tryParse('$key-02')!,
                          )),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            _buildGrid(context, groupPhotos),
            if (i == keys.length - 1) const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, Photo photo, int tilePx) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoViewPage(
              photos: photos,
              initialIndex: photos.indexOf(photo),
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
  }

  Widget _buildGrid(BuildContext context, List<Photo> gridPhotos) {
    final width = MediaQuery.sizeOf(context).width;
    final spacing = 8.0;
    final tileLogical = (width - 8.0 - spacing * (columns - 1)) / columns - 4;
    final tilePx =
        (tileLogical * MediaQuery.devicePixelRatioOf(context)).round().clamp(96, 900);
    return GridView.builder(
      shrinkWrap: groupBy != PhotoGroupBy.none,
      physics: groupBy != PhotoGroupBy.none
          ? const NeverScrollableScrollPhysics()
          : null,
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: gridPhotos.length,
      itemBuilder: (context, index) => _tile(context, gridPhotos[index], tilePx),
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
      'secure': 'Mover a carpeta segura',
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
                  switch (e.key) {
                    'fav' => Icons.favorite,
                    'album' => Icons.photo_library,
                    'secure' => Icons.lock_outline,
                    _ => Icons.delete_outline,
                  },
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
    } else if (action == 'secure') {
      await controller.moveToSecure(photo);
      onChanged?.call();
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