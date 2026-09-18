import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';

/// Encabezado de sección: título a la izquierda, acciones a la derecha.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding:
          padding ??
          const EdgeInsets.only(
            left: NXSpace.s24,
            right: NXSpace.s24,
            bottom: NXSpace.s20,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            Padding(
              padding: const EdgeInsets.only(right: NXSpace.s12),
              child: leading!,
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: NXText.sectionTitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: NXSpace.s4),
                  Text(
                    subtitle!,
                    style: NXText.metadata(context)
                        .copyWith(color: palette.textBody),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
