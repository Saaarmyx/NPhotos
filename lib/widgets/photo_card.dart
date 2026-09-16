import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import '../src/core.dart';
import '../src/rust/api.dart';
import 'nexora_placeholder.dart';

/// Tarjeta de foto NEXORA: miniatura redondeada, hover sutil,
/// badge de favorito y acciones rápidas.
class NPhotosPhotoCard extends StatefulWidget {
  const NPhotosPhotoCard({
    super.key,
    required this.photo,
    required this.tilePx,
    this.showFavorite = true,
    this.onTap,
    this.onLongPress,
    this.onFavorite,
    this.onMore,
    this.onRemove,
  });

  final Photo photo;
  final int tilePx;
  final bool showFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavorite;
  final VoidCallback? onMore;
  final VoidCallback? onRemove;

  @override
  State<NPhotosPhotoCard> createState() => _NPhotosPhotoCardState();
}

class _NPhotosPhotoCardState extends State<NPhotosPhotoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final isFav = widget.photo.isFavorite;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          child: AnimatedContainer(
            duration: NXTransition.base,
            curve: NXTransition.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NXRadius.radius14),
              border: Border.all(
                color: _hovered
                    ? NXColors.primary.withValues(alpha: 0.35)
                    : palette.border.withValues(alpha: 0.6),
              ),
              boxShadow: _hovered ? NXShadow.neutral(Theme.of(context)) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NXRadius.radius14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _NPhotosThumb(
                    path: widget.photo.path,
                    size: widget.tilePx,
                    variant: widget.photo.path.hashCode,
                  ),
                  // Degradado sutil inferior para leer las acciones
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: NXTransition.base,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x66000000),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Badge de favorito (siempre visible si es favorita)
                  if (isFav)
                    Positioned(
                      top: NXSpace.s8,
                      right: NXSpace.s8,
                      child: const _HeartBadge(filled: true),
                    ),
                  // Acciones rápidas en hover
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: NXTransition.fast,
                    child: Positioned(
                      left: NXSpace.s6,
                      bottom: NXSpace.s6,
                      right: NXSpace.s6,
                      child: Row(
                        children: [
                          if (widget.showFavorite)
                            _QuickAction(
                              icon: isFav
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              active: isFav,
                              tooltip: isFav ? 'Quitar de favoritos' : 'Marcar como favorita',
                              onPressed: widget.onFavorite,
                            ),
                          const Spacer(),
                          if (widget.onRemove != null)
                            _QuickAction(
                              icon: Icons.playlist_remove_rounded,
                              tooltip: 'Quitar del álbum',
                              onPressed: widget.onRemove,
                            ),
                          _QuickAction(
                            icon: Icons.more_horiz_rounded,
                            tooltip: 'Más',
                            onPressed: widget.onMore,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        shape: BoxShape.circle,
      ),
      child: Icon(
        filled ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 15,
        color: filled ? NXColors.primary : Colors.white,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: NXTransition.fast,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active
                  ? NXColors.primary
                  : Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: active ? Colors.white : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura con placeholder degradado mientras carga / si falla.
class _NPhotosThumb extends StatefulWidget {
  const _NPhotosThumb({
    required this.path,
    required this.size,
    required this.variant,
  });

  final String path;
  final int size;
  final int variant;

  @override
  State<_NPhotosThumb> createState() => _NPhotosThumbState();
}

class _NPhotosThumbState extends State<_NPhotosThumb> {
  Future<Uint8List?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _NPhotosThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.size != widget.size) {
      _future = _load();
    }
  }

  Future<Uint8List?> _load() async {
    final controller = await StoreController.instance();
    return controller.thumbnail(widget.path, size: widget.size.clamp(128, 900).toInt());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          );
        }
        if (snapshot.hasError) {
          return NexoraPlaceholder(
            variant: widget.variant,
            icon: Icons.broken_image_outlined,
          );
        }
        return NexoraPlaceholder(variant: widget.variant);
      },
    );
  }
}