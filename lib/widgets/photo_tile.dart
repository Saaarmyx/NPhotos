import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

/// Tile único para mostrar una foto local.
///
/// Centraliza el `Image.file` que antes estaba duplicado en galería,
/// favoritos y álbumes, junto con su `errorBuilder`. Sin redondeo: las
/// fotos se renderizan a sangre en la parrilla. Usa colores del tema
/// para que los cambios en `nexora_ui` propaguen.
class PhotoTile extends StatelessWidget {
  final String path;
  final int cacheWidth;
  final BoxFit fit;
  final double? width;
  final bool isVideo;

  const PhotoTile({
    super.key,
    required this.path,
    this.cacheWidth = 250,
    this.fit = BoxFit.cover,
    this.width,
    this.isVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          width: width,
          fit: fit,
          cacheWidth: cacheWidth,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: context.nSurfaceTranslucentColor,
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.broken_image_outlined,
                color: context.nMutedTextColor,
                size: 28,
              ),
            );
          },
        ),
        if (isVideo)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(NSpacing.spaceXs),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
      ],
    );
  }
}
