import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/photo_card.dart';
import '../core.dart';
import '../pages/photo_view_page.dart';
import '../rust/api.dart';

enum PhotoGroupBy { none, year, month }

/// Grid adaptativo premium NEXORA de miniaturas de fotos.
class ThumbnailGrid extends StatelessWidget {
  const ThumbnailGrid({
    super.key,
    required this.photos,
    this.groupBy = PhotoGroupBy.none,
    this.onChanged,
    this.showFavoriteBadge = true,
    this.onRemoveRequest,
    this.padding = const EdgeInsets.fromLTRB(
      NXSpace.s24,
      NXSpace.s4,
      NXSpace.s24,
      NXSpace.s32,
    ),
    this.maxCrossAxisExtent = 250,
  });

  final List<Photo> photos;
  final PhotoGroupBy groupBy;
  final VoidCallback? onChanged;
  final bool showFavoriteBadge;
  final Future<void> Function(Photo photo)? onRemoveRequest;
  final EdgeInsetsGeometry padding;
  final double maxCrossAxisExtent;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const NPhotosGridEmpty();
    }
    if (groupBy == PhotoGroupBy.none) {
      return _grid(context, photos);
    }
    return _buildGrouped();
  }

  Map<String, List<Photo>> _groups() {
    final map = <String, List<Photo>>{};
    for (final photo in photos) {
      final key =
          switch (groupBy) {
            PhotoGroupBy.year => DateTime.tryParse(
              photo.takenAt ?? '',
            )?.year.toString(),
            PhotoGroupBy.month => DateTime.tryParse(
              photo.takenAt ?? '',
            )?.toIso8601String().substring(0, 7),
            PhotoGroupBy.none => null,
          } ??
          'sin_fecha';
      map.putIfAbsent(key, () => []).add(photo);
    }
    // orden descendente (más reciente primero); 'sin_fecha' al final
    final sorted = map.keys.where((k) => k != 'sin_fecha').toList()
      ..sort((a, b) => b.compareTo(a));
    if (map.containsKey('sin_fecha')) sorted.add('sin_fecha');
    return {for (final k in sorted) k: map[k]!};
  }

  Widget _buildGrouped() {
    final groups = _groups();
    final keys = groups.keys.toList();
    return ListView.builder(
      padding: padding,
      itemCount: keys.length,
      itemBuilder: (context, i) {
        final key = keys[i];
        final groupPhotos = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                NXSpace.s4,
                NXSpace.s12,
                NXSpace.s4,
                NXSpace.s10,
              ),
              child: Text(
                key == 'sin_fecha'
                    ? 'Sin fecha'
                    : (groupBy == PhotoGroupBy.year
                          ? key
                          : DateFormat('MMMM yyyy')
                                .format(DateTime.tryParse('$key-02')!)),
                style: NXText.cardTitle(context)
                    .copyWith(color: NexoraPalette.of(context).textSecondary),
              ),
            ),
            _grid(context, groupPhotos),
            if (i == keys.length - 1) const SizedBox(height: NXSpace.s8),
          ],
        );
      },
    );
  }

  Widget _grid(BuildContext context, List<Photo> gridPhotos) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final tilePx = (120 * devicePixelRatio).round().clamp(128, 900);

    return GridView.builder(
      shrinkWrap: groupBy != PhotoGroupBy.none,
      physics: groupBy != PhotoGroupBy.none
          ? const NeverScrollableScrollPhysics()
          : null,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxCrossAxisExtent,
        crossAxisSpacing: NXSpace.s14,
        mainAxisSpacing: NXSpace.s14,
      ),
      itemCount: gridPhotos.length,
      itemBuilder: (context, index) {
        final photo = gridPhotos[index];
        return NPhotosPhotoCard(
          photo: photo,
          tilePx: tilePx,
          showFavorite: showFavoriteBadge,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PhotoViewPage(
                  photos: gridPhotos,
                  initialIndex: gridPhotos.indexOf(photo),
                  onChanged: onChanged,
                ),
              ),
            );
          },
          onLongPress: () => _showMenu(context, photo),
          onFavorite: () => _toggleFavorite(photo),
          onRemove: onRemoveRequest == null
              ? null
              : () async {
                  await onRemoveRequest!(photo);
                  onChanged?.call();
                },
          onMore: () => _showMenu(context, photo),
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
      'secure': 'Mover a carpeta segura',
      'hide': 'Ocultar foto',
    };
    if (onRemoveRequest != null) {
      options['remove'] = 'Quitar del álbum';
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NexoraPalette.of(context).elevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NXRadius.radius16),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            for (final e in options.entries)
              ListTile(
                leading: Icon(switch (e.key) {
                  'fav' => Icons.favorite_border_rounded,
                  'album' => Icons.photo_library_outlined,
                  'secure' => Icons.lock_outline_rounded,
                  'hide' => Icons.visibility_off_outlined,
                  _ => Icons.playlist_remove_rounded,
                }, size: 20),
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
    } else if (action == 'hide') {
      await controller.setHidden(photo, isHidden: true);
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
        backgroundColor: NexoraPalette.of(context).elevated,
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

  static Future<String?> _askAlbumName(
    BuildContext context, {
    String? initial,
  }) => showDialog<String>(
    context: context,
    builder: (context) => _NameDialog(title: 'Nuevo álbum', initial: initial),
  );
}

class NPhotosGridEmpty extends StatelessWidget {
  const NPhotosGridEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No hay fotos aún',
        style: NXText.metadata(context)
            .copyWith(color: NexoraPalette.of(context).textBody),
      ),
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
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

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
