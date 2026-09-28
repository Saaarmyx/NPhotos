import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';

/// Nombres de mes en español para la cabecera del visor.
const _kMonthsEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// 'Septiembre 11, 2026'.
String _formatViewerDate(DateTime date) =>
    '${_kMonthsEs[date.month - 1]} ${date.day}, ${date.year}';

/// '21:38'.
String _formatViewerTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

class PhotoViewerScreen extends StatefulWidget {
  final GalleryController controller;
  final int initialIndex;

  const PhotoViewerScreen({
    super.key,
    required this.controller,
    required this.initialIndex,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  /// Giros de visualización por foto (solo sesión, no se persiste).
  final Map<String, int> _rotations = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final photos = widget.controller.photos;

        if (photos.isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: NEmptyState(
              icon: Icons.broken_image_outlined,
              title: 'No hay imagen disponible',
              foregroundColor: Colors.white,
            ),
          );
        }

        // La lista puede recargarse con menos elementos mientras se mira una
        // foto: se recorta el índice para el chrome (fecha y acciones).
        final safeIndex = _currentIndex.clamp(0, photos.length - 1);
        final currentPhoto = photos[safeIndex];

        return NPhotoViewer(
          title: _formatViewerDate(currentPhoto.dateModified),
          subtitle: _formatViewerTime(currentPhoto.dateModified),
          onRotate: () => setState(() {
            _rotations[currentPhoto.id] =
                ((_rotations[currentPhoto.id] ?? 0) + 1) % 4;
          }),
          onShare: () => _sharePhoto(currentPhoto),
          // Sin onEdit en release: se omite el botón (el kit oculta
          // acciones con callback nulo) hasta tener edición real.
          onDelete: () {
            widget.controller.moveToTrash(currentPhoto.id);
            Navigator.of(context).pop();
          },
          isFavorite: currentPhoto.isFavorite,
          onFavoriteToggle: () =>
              widget.controller.toggleFavorite(currentPhoto.id),
          child: PageView.builder(
            controller: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final photo = photos[index];
              final turns = _rotations[photo.id] ?? 0;
              if (photo.isVideo) {
                return Center(
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: _VideoPage(
                      key: ValueKey(photo.id),
                      path: photo.path,
                      active: index == _currentIndex,
                    ),
                  ),
                );
              }
              return InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: turns,
                    child: Image.file(
                      File(photo.path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _sharePhoto(Photo photo) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(photo.path)], text: photo.title),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo compartir: $e')),
      );
    }
  }
}

/// Página de vídeo del visor: reproduce con `media_kit` (Android + Linux).
///
/// Solo el vídeo visible ([active]) suena; al salir de página se pausa.
class _VideoPage extends StatefulWidget {
  final String path;
  final bool active;

  const _VideoPage({super.key, required this.path, required this.active});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late final Player _player;
  late final VideoController _videoController;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _open();
  }

  Future<void> _open() async {
    await _player.open(Media(Uri.file(widget.path).toString()));
    await _player.setPlaylistMode(PlaylistMode.single);
    if (!mounted) return;
    setState(() => _ready = true);
    if (widget.active) _player.play();
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready || widget.active == oldWidget.active) return;
    if (widget.active) {
      _player.play();
    } else {
      _player.pause();
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () =>
          _player.state.playing ? _player.pause() : _player.play(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: Video(controller: _videoController)),
          StreamBuilder<bool>(
            stream: _player.stream.playing,
            initialData: false,
            builder: (context, snapshot) {
              if (snapshot.data ?? false) {
                return const SizedBox.shrink();
              }
              return const Center(
                child: Icon(
                  Icons.play_circle_outline,
                  color: Colors.white70,
                  size: 72,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
