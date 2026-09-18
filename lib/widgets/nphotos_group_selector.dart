import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import '../src/widgets/photo_grid.dart' show PhotoGroupMode;

/// Selector de agrupación NEXORA: segement control Compacto / Año / Mes.
class NPhotosGroupSelector extends StatelessWidget {
  const NPhotosGroupSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PhotoGroupMode value;
  final ValueChanged<PhotoGroupMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final options = <(PhotoGroupMode, IconData, String)>[
      (PhotoGroupMode.compact, Icons.dashboard_outlined, 'Compacto'),
      (PhotoGroupMode.year, Icons.calendar_view_week_outlined, 'Año'),
      (PhotoGroupMode.month, Icons.calendar_view_month_outlined, 'Mes'),
    ];

    return AnimatedContainer(
      duration: NXTransition.base,
      curve: NXTransition.easeOut,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(NXRadius.radius10),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            _Segment(
              icon: options[i].$2,
              label: options[i].$3,
              selected: value == options[i].$1,
              isFirst: i == 0,
              isLast: i == options.length - 1,
              onTap: () => onChanged(options[i].$1),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: NXSpace.s12,
            vertical: NXSpace.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.active : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? NXRadius.radius10 : 0),
              bottomLeft: Radius.circular(isFirst ? NXRadius.radius10 : 0),
              topRight: Radius.circular(isLast ? NXRadius.radius10 : 0),
              bottomRight: Radius.circular(isLast ? NXRadius.radius10 : 0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? NXColors.primary : palette.textMuted,
              ),
              const SizedBox(width: NXSpace.s6),
              Text(
                label,
                style: NXText.albumName(context).copyWith(
                  color: selected ? palette.textPrimary : palette.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}