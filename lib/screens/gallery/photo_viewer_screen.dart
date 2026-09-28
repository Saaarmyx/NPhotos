import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/gallery_controller.dart';
import '../../models/photo.dart';
import '../../widgets/trash_grid.dart' show confirmDestructive;

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

String _formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} ${units[unit]}';
}

class PhotoViewerScreen extends StatefulWidget {
  final GalleryController controller;
  final int initialIndex;

  /// Lista a hojear. Por defecto la galería completa; la galería filtrada
  /// (búsqueda, álbum cámara) pasa [GalleryController.visiblePhotos].
  final List<Photo>? photosOverride;

  const PhotoViewerScreen({
    super.key,
    required this.controller,
    required this.initialIndex,
    this.photosOverride,
  });

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  /// Giros de visualización por foto (solo sesión, no se persiste).
  final Map<String, int> _rotations = {};

  /// Chrome (topbar + bottombar) visible o escondido.
  bool _chromeVisible = true;
  Timer? _chromeTimer;
  static const _kChromeTimeout = Duration(seconds: 5);

  /// La página actual está ampliada: bloquea el PageView para que el
  /// pinch no salte de foto salvo gesto milimétrico.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _restartChromeTimer();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(_kChromeTimeout, () {
      if (!mounted) return;
      setState(() => _chromeVisible = false);
    });
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    if (_chromeVisible) _restartChromeTimer();
  }

  /// Actividad que no debe mostrar el chrome pero sí reiniciar
  /// la cuenta atrás para esconderlo (pinch, zoom, drag).
  void _pokeChromeTimer() {
    if (_chromeVisible) _restartChromeTimer();
  }

  void _onZoomChanged(bool zoomed) {
    if (_zoomed == zoomed) return;
    setState(() => _zoomed = zoomed);
    _pokeChromeTimer();
  }

  void _onZoomOutDismiss() {
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final photos = widget.photosOverride ?? widget.controller.photos;

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

        final safeIndex = _currentIndex.clamp(0, photos.length - 1);
        final currentPhoto = photos[safeIndex];

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                // Ampliada: el swipe queda bloqueado, el pinch es solo zoom.
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: photos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _zoomed = false;
                    _chromeVisible = true;
                  });
                  _restartChromeTimer();
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
                          onTap: _toggleChrome,
                        ),
                      ),
                    );
                  }
                  return NZoomableImage(
                    key: ValueKey('${photo.id}_$turns'),
                    path: photo.path,
                    // El ajuste que "llena la pantalla" lo decide el kit
                    // con las dimensiones reales de la foto.
                    fit: nFillFit(
                      MediaQuery.sizeOf(context),
                      imageWidth: photo.width ?? 0,
                      imageHeight: photo.height ?? 0,
                      quarterTurns: turns,
                    ),
                    quarterTurns: turns,
                    onZoomChanged: _onZoomChanged,
                    onDismiss: _onZoomOutDismiss,
                    onTap: _toggleChrome,
                  );
                },
              ),
              // Chrome superpuesto: se esconde a los 5 s o con un toque.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: AppAppearance.performanceMode.value ==
                          NPerformanceMode.high
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: NViewerTopBar(
                      title: _formatViewerDate(currentPhoto.dateModified),
                      subtitle: [
                        _formatViewerTime(currentPhoto.dateModified),
                        if (currentPhoto.locationLabel != null)
                          currentPhoto.locationLabel!,
                      ].join(' · '),
                      onClose: () => Navigator.of(context).maybePop(),
                      onInfo: () => _showDetails(currentPhoto),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _chromeVisible ? 1 : 0,
                  duration: AppAppearance.performanceMode.value ==
                          NPerformanceMode.high
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: NSpacing.spaceMd,
                          right: NSpacing.spaceMd,
                          bottom: NSpacing.spaceMd,
                        ),
                        child: NViewerBottomBar(
                          onShare: () => _sharePhoto(currentPhoto),
                          onDelete: () async {
                            final confirmed = await confirmDestructive(
                              context,
                              title: 'Mover a la papelera',
                              message:
                                  '“${currentPhoto.title}” se moverá a la papelera. Podrás restaurarla desde Álbumes.',
                            );
                            if (!confirmed || !context.mounted) return;
                            await widget.controller.moveToTrash(
                              currentPhoto.id,
                            );
                            if (!context.mounted) return;
                            Navigator.of(context).pop();
                          },
                          isFavorite: currentPhoto.isFavorite,
                          onFavoriteToggle: () => widget.controller
                              .toggleFavorite(currentPhoto.id),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(Photo photo) {
    _chromeTimer?.cancel();
    final mp = photo.megapixels;
    showNSheet(
      context,
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(NSpacing.spaceMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Detalles',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Fecha',
                  value:
                      '${_formatViewerDate(photo.dateModified)} · ${_formatViewerTime(photo.dateModified)}',
                ),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Ubicación',
                  value: photo.locationLabel ?? 'Sin ubicación',
                ),
                if (photo.isVideo)
                  _DetailRow(
                    icon: Icons.play_circle_outline,
                    label: 'Duración',
                    value: photo.formattedDuration ?? 'Vídeo',
                  ),
                _DetailRow(
                  icon: Icons.photo_size_select_actual_outlined,
                  label: 'Tamaño',
                  value: _formatBytes(photo.sizeInBytes),
                ),
                if (photo.width != null && photo.height != null)
                  _DetailRow(
                    icon: Icons.aspect_ratio_outlined,
                    label: 'Dimensiones',
                    value:
                        '${photo.width} × ${photo.height}${mp != null ? ' · ${mp.toStringAsFixed(1)} MP' : ''}',
                  ),
                if (photo.isMotionPhoto)
                  const _DetailRow(
                    icon: Icons.motion_photos_on_outlined,
                    label: 'Tipo',
                    value: 'Foto animada',
                  ),
                if (photo.isSelfie)
                  const _DetailRow(
                    icon: Icons.face_outlined,
                    label: 'Tipo',
                    value: 'Selfie',
                  ),
                const SizedBox(height: NSpacing.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _rotations[photo.id] =
                                ((_rotations[photo.id] ?? 0) + 3) % 4;
                          });
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.rotate_left,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Girar',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: NSpacing.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            widget.controller.toggleFavorite(photo.id),
                        icon: Icon(
                          photo.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: photo.isFavorite ? Colors.red : Colors.white,
                        ),
                        label: Text(
                          photo.isFavorite ? 'Favorita' : 'Favorito',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).then((_) {
      if (!mounted) return;
      setState(() => _chromeVisible = true);
      _restartChromeTimer();
    });
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Página de vídeo del visor: reproduce con `media_kit` (Android + Linux).
///
/// Solo el vídeo visible ([active]) suena; al salir de página se pausa.
class _VideoPage extends StatefulWidget {
  final String path;
  final bool active;
  final VoidCallback? onTap;

  const _VideoPage({super.key, required this.path, required this.active, this.onTap});

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
        child: NLoader(size: 44, color: Colors.white),
      );
    }
    return GestureDetector(
      onTap: () {
        if (_player.state.playing) {
          _player.pause();
        } else {
          _player.play();
        }
        widget.onTap?.call();
      },
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
