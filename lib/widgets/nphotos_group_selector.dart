import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import '../src/widgets/photo_grid.dart' show PhotoGroupBy;

/// Selector de agrupación (Grid / Year / Month) para la vista Photos.
class NPhotosGroupSelector extends StatelessWidget {
  const NPhotosGroupSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PhotoGroupBy value;
  final ValueChanged<PhotoGroupBy> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final options = <(PhotoGroupBy, IconData, String)>[
      (PhotoGroupBy.none, Icons.grid_view_rounded, 'Grid'),
      (PhotoGroupBy.year, Icons.calendar_view_week_outlined, 'Year'),
      (PhotoGroupBy.month, Icons.calendar_view_month_outlined, 'Month'),
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(NXRadius.radius10),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, icon, label) in options)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onChanged(mode),
                  child: AnimatedContainer(
                    duration: NXTransition.base,
                    curve: NXTransition.easeOut,
                    padding: const EdgeInsets.symmetric(
                      horizontal: NXSpace.s10,
                      vertical: NXSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: value == mode
                          ? palette.active
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: palette.textSecondary),
                        const SizedBox(width: NXSpace.s6),
                        Text(
                          label,
                          style: NXText.albumName(context)
                              .copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
