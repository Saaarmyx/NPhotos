import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import 'nphotos_button.dart';

/// Estado vacío elegante usado en toda la app (librería, álbumes, favoritos…).
class NPhotosEmptyState extends StatelessWidget {
  const NPhotosEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.hover,
              borderRadius: BorderRadius.circular(NXRadius.radius24),
              border: Border.all(color: palette.border),
            ),
            child: Icon(icon, size: 40, color: palette.textSecondary),
          ),
          const SizedBox(height: NXSpace.s20),
          Text(
            title,
            style: NXText.cardTitle(context)
                .copyWith(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: NXSpace.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: NXText.metadata(context)
                    .copyWith(color: palette.textBody),
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: NXSpace.s20),
            NPhotosButton.secondary(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Estado de carga NEXORA (logo + indicador sutil).
class NPhotosLoadingState extends StatelessWidget {
  const NPhotosLoadingState({super.key, this.label = 'Loading…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: NXSpace.s20),
        Text(
          label,
          style: NXText.muted(context).copyWith(color: palette.textBody),
        ),
      ],
    );
  }
}
