import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';

/// Placeholder suave en degradado cuando no hay miniatura disponible.
/// [variant] determina la combinación de colores (determinista por índice).
class NexoraPlaceholder extends StatelessWidget {
  const NexoraPlaceholder({
    super.key,
    this.icon = Icons.image_outlined,
    this.variant = 0,
    this.borderRadius = NXRadius.radius14,
  });

  final IconData icon;
  final int variant;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final gradient =
        NXColors.coverGradients[variant % NXColors.coverGradients.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.placeholderA, palette.placeholderB],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(NXRadius.radius14),
          ),
          child: Icon(
            icon,
            size: 20,
            color: gradient.last.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

/// Portada en degradado NEXORA para tarjetas de álbum / mocks.
class NexoraCover extends StatelessWidget {
  const NexoraCover({
    super.key,
    required this.variant,
    this.icon = Icons.image_outlined,
    this.radius = NXRadius.radius14,
  });

  final int variant;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors =
        NXColors.coverGradients[variant % NXColors.coverGradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 34,
          color: Colors.white.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
