import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

/// Tile único para mostrar una foto local.
///
/// Centraliza el `ClipRRect + Image.file` que antes estaba duplicado en
/// galería, favoritos y álbumes, junto con su `errorBuilder`. Usa colores
/// del tema para que los cambios en `nexora_ui` propaguen.
class PhotoTile extends StatelessWidget {
  final String path;
  final double borderRadius;
  final int cacheWidth;
  final BoxFit fit;
  final double? width;

  const PhotoTile({
    super.key,
    required this.path,
    this.borderRadius = NSpacing.radiusSm,
    this.cacheWidth = 250,
    this.fit = BoxFit.cover,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(path),
        width: width,
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: context.nSurfaceTranslucentColor,
            child: Icon(
              Icons.broken_image_outlined,
              color: context.nMutedTextColor,
              size: 28,
            ),
          );
        },
      ),
    );
  }
}
