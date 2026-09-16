import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import 'nphotos_button.dart';
import 'nphotos_search.dart';

/// Barra superior NEXORA: título de sección a la izq., búsqueda centrada
/// y acciones globales a la derecha.
class NPhotosTopBar extends StatelessWidget {
  const NPhotosTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.enableSearch = true,
    this.searchQuery,
    this.onQueryChanged,
    this.actions,
    this.height = 56,
  });

  final String title;
  final String? subtitle;
  final bool enableSearch;
  final String? searchQuery;
  final ValueChanged<String>? onQueryChanged;
  final List<Widget>? actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: NXSpace.s24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NXText.sectionTitle(context),
                ),
                if (subtitle case final s?)
                  Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NXText.muted(context).copyWith(color: palette.textBody),
                  ),
              ],
            ),
          ),
          if (enableSearch) ...[
            NPhotosSearch(
              onQueryChanged: (value) => onQueryChanged?.call(value),
              initialQuery: searchQuery,
              width: 320,
            ),
            const SizedBox(width: NXSpace.s16),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...?actions,
                const SizedBox(width: NXSpace.s8),
              ],
            ),
          ),
          const SizedBox(width: NXSpace.s16),
        ],
      ),
    );
  }
}

/// Acción global de alternar tema (claro/oscuro).
class NPhotosThemeToggle extends StatelessWidget {
  const NPhotosThemeToggle({
    super.key,
    required this.isDark,
    required this.onToggle,
  });

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return NPhotosIconButton(
      icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      tooltip: isDark ? 'Cambiar a tema claro' : 'Cambiar a tema oscuro',
      onPressed: onToggle,
    );
  }
}