import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../design/nexora_tokens.dart';
import '../core.dart';
import '../rust/api.dart';

/// Visor NEXORA (dark, inmersivo): UI conceptual de zoom/navegación/
/// favorito/compartir/eliminar/info. La lógica de datos se mantiene.
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
  final TransformationController _transform = TransformationController();
  late int _index;
  int _rotation = 0;
  double _zoom = 1.0;
  bool _barVisible = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    _transform.dispose();
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
                ? 'Marked as favorite'
                : 'Removed from favorites',
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
        backgroundColor: NexoraPalette.of(context).elevated,
        title: const Text('Choose an album'),
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
          const SnackBar(content: Text('Added to album')),
        );
      }
      widget.onChanged?.call();
    }
  }

  void _rotate() => setState(() => _rotation = (_rotation + 90) % 360);

  Future<void> _moveToTrash() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final path = _photo.path;
    final photo = _photo;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash'),
        content: Text('Move "${_photo.name}" to Trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NXColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.moveToTrash(photo);
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
        const SnackBar(content: Text('Moved to Trash')),
      );
    }
  }

  Future<void> _moveToSecure() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final path = _photo.path;
    final photo = _photo;
    await controller.moveToSecure(photo);
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
        const SnackBar(content: Text('Moved to Secure Folder')),
      );
    }
  }

  Future<void> _hidePhoto() async {
    final controller = await StoreController.instance();
    if (!mounted) return;
    final path = _photo.path;
    final photo = _photo;
    await controller.setHidden(photo, isHidden: true);
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
        const SnackBar(content: Text('Photo hidden from library')),
      );
    }
  }

  void _resetTransform() {
    _transform.value = Matrix4.identity();
  }

  void _next() {
    if (_index < widget.photos.length - 1) {
      setState(() {
        _index++;
        _rotation = 0;
        _zoom = 1;
      });
      _resetTransform();
      _controller.nextPage(
        duration: NXTransition.slow,
        curve: NXTransition.accent,
      );
    }
  }

  void _previous() {
    if (_index > 0) {
      setState(() {
        _index--;
        _rotation = 0;
        _zoom = 1;
      });
      _resetTransform();
      _controller.previousPage(
        duration: NXTransition.slow,
        curve: NXTransition.accent,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() {
              _index = i;
              _rotation = 0;
              _zoom = 1;
              _resetTransform();
            }),
            itemBuilder: (context, index) {
              final p = widget.photos[index];
              return Center(
                child: _zoomable(p),
              );
            },
          ),
          // Barra superior
          AnimatedSlide(
            duration: NXTransition.base,
            curve: NXTransition.easeOut,
            offset: _barVisible ? Offset.zero : const Offset(0, -1),
            child: _ViewerTopBar(
              photo: photo,
              index: _index + 1,
              total: widget.photos.length,
              onClose: () => Navigator.of(context).pop(),
              onFavorite: _toggleFavorite,
              onInfo: () => _showInfo(context, photo),
            ),
          ),
          // Controles de navegación laterales
          if (_barVisible)
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  duration: NXTransition.base,
                  opacity: _barVisible ? 1 : 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _NavButton(
                        icon: Icons.chevron_left_rounded,
                        onPressed: _index > 0 ? _previous : null,
                      ),
                      _NavButton(
                        icon: Icons.chevron_right_rounded,
                        onPressed: _index < widget.photos.length - 1 ? _next : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Barra inferior de acciones (concepto de UI)
          AnimatedSlide(
            duration: NXTransition.base,
            curve: NXTransition.easeOut,
            offset: _barVisible ? Offset.zero : const Offset(0, 1),
            child: _ViewerBottomBar(
              photo: photo,
              onRotate: _rotate,
              onAddToAlbum: _addToAlbum,
              onSecure: _moveToSecure,
              onHide: _hidePhoto,
              onTrash: _moveToTrash,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoomable(Photo p) {
    final file = File(p.path);
    final image = Image.file(
      file,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, err) => Center(
        child: Text(
          'No se pudo cargar la imagen\n$err',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        ),
      ),
    );
    return GestureDetector(
      onTap: () => setState(() => _barVisible = !_barVisible),
      onDoubleTap: () => setState(() {
        _zoom = _zoom == 1 ? 2.0 : 1.0;
        _resetTransform();
      }),
      child: InteractiveViewer(
        maxScale: 8,
        transformationController: _transform,
        child: Transform.rotate(
          angle: _rotation * 3.141592653589793 / 180,
          child: image,
        ),
      ),
    );
  }

  void _showInfo(BuildContext context, Photo photo) {
    final sizeMb = (photo.sizeBytes.toDouble() / 1048576).toStringAsFixed(2);
    final date = photo.takenAt == null
        ? 'Unknown'
        : DateFormat('dd MMM yyyy HH:mm').format(
            DateTime.tryParse(photo.takenAt!) ?? DateTime.now(),
          );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NexoraPalette.of(context).elevated,
        title: const Text('Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(label: 'Name', value: photo.name),
            _InfoRow(label: 'Size', value: '$sizeMb MB'),
            _InfoRow(label: 'Dimensions', value: '${photo.width} × ${photo.height}'),
            _InfoRow(label: 'Taken', value: date),
            _InfoRow(label: 'Path', value: photo.path),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    required this.photo,
    required this.index,
    required this.total,
    required this.onClose,
    required this.onFavorite,
    required this.onInfo,
  });

  final Photo photo;
  final int index;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onFavorite;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(NXSpace.s16, NXSpace.s12, NXSpace.s16, NXSpace.s12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6050507), Color(0x00050507)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              _ViewerIcon(
                icon: Icons.close_rounded,
                tooltip: 'Close',
                onPressed: onClose,
              ),
              const SizedBox(width: NXSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NXText.albumName(context).copyWith(color: Colors.white),
                    ),
                    Text(
                      '$index of $total',
                      style: NXText.muted(context)
                          .copyWith(color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              _ViewerIcon(
                icon: photo.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                tooltip: photo.isFavorite ? 'Remove from favorites' : 'Favorite',
                onPressed: onFavorite,
                highlighted: photo.isFavorite,
              ),
              const SizedBox(width: NXSpace.s6),
              _ViewerIcon(
                icon: Icons.info_outline_rounded,
                tooltip: 'Info',
                onPressed: onInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerBottomBar extends StatelessWidget {
  const _ViewerBottomBar({
    required this.photo,
    required this.onRotate,
    required this.onAddToAlbum,
    required this.onSecure,
    required this.onHide,
    required this.onTrash,
  });

  final Photo photo;
  final VoidCallback onRotate;
  final VoidCallback onAddToAlbum;
  final VoidCallback onSecure;
  final VoidCallback onHide;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    final sizeMb = (photo.sizeBytes.toDouble() / 1048576).toStringAsFixed(2);
    final date = photo.takenAt == null
        ? 'Sin fecha'
        : DateFormat('dd MMM yyyy HH:mm').format(
            DateTime.tryParse(photo.takenAt!) ?? DateTime.now(),
          );
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xE6050507), Color(0x00050507)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(NXSpace.s24, NXSpace.s28, NXSpace.s24, NXSpace.s24),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${photo.width}×${photo.height}  •  $sizeMb MB  •  $date',
                style: NXText.muted(context)
                    .copyWith(color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(width: NXSpace.s20),
              const SizedBox(width: 1, height: 24),
              const SizedBox(width: NXSpace.s20),
              _ViewerIcon(
                icon: Icons.rotate_90_degrees_ccw_outlined,
                tooltip: 'Rotate 90°',
                onPressed: onRotate,
              ),
              _ViewerIcon(
                icon: Icons.library_add_outlined,
                tooltip: 'Add to album',
                onPressed: onAddToAlbum,
              ),
              _ViewerIcon(
                icon: Icons.lock_outline_rounded,
                tooltip: 'Move to Secure Folder',
                onPressed: onSecure,
              ),
              _ViewerIcon(
                icon: Icons.visibility_off_outlined,
                tooltip: 'Hide from library',
                onPressed: onHide,
              ),
              _ViewerIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Move to Trash',
                onPressed: onTrash,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerIcon extends StatelessWidget {
  const _ViewerIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.highlighted = false,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? NXColors.primary
        : highlighted
            ? NXColors.primary
            : Colors.white.withValues(alpha: 0.9);
    final child = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
    return child;
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: IconButton(
          icon: Icon(icon, size: 22, color: Colors.white),
          onPressed: onPressed,
          hoverColor: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NXSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: NXText.muted(context).copyWith(color: palette.textMuted),
            ),
          ),
          Expanded(
            child: Text(value, style: NXText.metadata(context).copyWith(color: palette.textSecondary)),
          ),
        ],
      ),
    );
  }
}