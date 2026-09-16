import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import '../src/core.dart';
import '../src/rust/api.dart';
import 'nexora_placeholder.dart';

/// Tarjeta de álbum NEXORA: portada grande con overlay de nombre y cuenta.
class NPhotosAlbumCard extends StatefulWidget {
  const NPhotosAlbumCard({
    super.key,
    required this.album,
    this.variant = 0,
    this.onTap,
    this.onRename,
    this.onDelete,
  });

  final Album album;
  final int variant;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  State<NPhotosAlbumCard> createState() => _NPhotosAlbumCardState();
}

class _NPhotosAlbumCardState extends State<NPhotosAlbumCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final count = widget.album.photoPaths.length;
    final cover = widget.album.photoPaths.isEmpty
        ? null
        : widget.album.photoPaths.first;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.02 : 1.0,
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          child: AnimatedContainer(
            duration: NXTransition.base,
            curve: NXTransition.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NXRadius.radius16),
              boxShadow: _hovered ? NXShadow.neutral(Theme.of(context)) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NXRadius.radius16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AlbumCover(photoPath: cover, variant: widget.variant),
                    // Overlay inferior con nombre y cuenta
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          NXSpace.s16,
                          NXSpace.s28,
                          NXSpace.s16,
                          NXSpace.s14,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xB3000000)],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.album.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: NXText.albumName(context).copyWith(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: NXSpace.s4),
                                  Text(
                                    '${widget.album.photoPaths.length} ${count == 1 ? 'photo' : 'photos'}',
                                    style: NXText.muted(context).copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_hovered)
                              _AlbumMenu(
                                onRename: widget.onRename,
                                onDelete: widget.onDelete,
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
      ),
    );
  }
}

class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.photoPath, required this.variant});

  final String? photoPath;
  final int variant;

  @override
  Widget build(BuildContext context) {
    if (photoPath == null) {
      return NexoraCover(
        variant: variant,
        icon: Icons.photo_library_outlined,
        radius: NXRadius.radius16,
      );
    }
    return FutureBuilder<Uint8List?>(
      future: StoreController.instance().then(
        (c) => c.thumbnail(photoPath!, size: 512),
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
        }
        if (snapshot.hasError) {
          return NexoraCover(variant: variant, radius: NXRadius.radius16);
        }
        return NexoraPlaceholder(
          variant: variant,
          borderRadius: NXRadius.radius16,
        );
      },
    );
  }
}

class _AlbumMenu extends StatelessWidget {
  const _AlbumMenu({this.onRename, this.onDelete});

  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Acciones del álbum',
      color: NexoraPalette.of(context).elevated,
      surfaceTintColor: Colors.transparent,
      icon: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
      onSelected: (value) {
        if (value == 'rename') onRename?.call();
        if (value == 'delete') onDelete?.call();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Renombrar')),
        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
      ],
    );
  }
}
