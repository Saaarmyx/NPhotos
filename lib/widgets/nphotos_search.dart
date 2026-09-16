import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';

/// Campo de búsqueda NEXORA: icono + placeholder + hover/focus +
/// détalle de atajo visual. Emite cambios de consulta vía [onQueryChanged].
class NPhotosSearch extends StatefulWidget {
  const NPhotosSearch({
    super.key,
    required this.onQueryChanged,
    this.hintText = 'Search…',
    this.controller,
    this.initialQuery,
    this.autofocus = false,
    this.width = 300,
  });

  final ValueChanged<String> onQueryChanged;
  final String hintText;
  final TextEditingController? controller;
  final String? initialQuery;
  final bool autofocus;
  final double width;

  @override
  State<NPhotosSearch> createState() => _NPhotosSearchState();
}

class _NPhotosSearchState extends State<NPhotosSearch> {
  late final TextEditingController _controller =
      widget.controller ??
      (widget.initialQuery != null
          ? TextEditingController(text: widget.initialQuery)
          : TextEditingController());
  bool _focused = false;
  bool _hovered = false;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) => widget.onQueryChanged(value);

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final hasQuery = _controller.text.isNotEmpty;

    final field = SizedBox(
      width: widget.width,
      height: 38,
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: NXTransition.base,
            curve: NXTransition.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: NXSpace.s12),
            decoration: BoxDecoration(
              color: _focused ? palette.surface : palette.background,
              borderRadius: BorderRadius.circular(NXRadius.radius10),
              border: Border.all(
                color: _focused
                    ? NXColors.primary.withValues(alpha: 0.7)
                    : _hovered
                    ? palette.textMuted.withValues(alpha: 0.5)
                    : palette.border,
              ),
              boxShadow: _focused
                  ? [
                      BoxShadow(
                        color: NXColors.primary.withValues(alpha: 0.10),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedOpacity(
                  duration: NXTransition.fast,
                  opacity: _focused ? 1 : 0.55,
                  child: Icon(
                    Icons.search_rounded,
                    size: 17,
                    color: _focused ? NXColors.primary : palette.textBody,
                  ),
                ),
                const SizedBox(width: NXSpace.s8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.autofocus,
                    onChanged: _onChanged,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                    cursorColor: NXColors.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
                if (hasQuery)
                  _ClearButton(
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  )
                else
                  _ShortcutBadge(label: '⌘K'),
              ],
            ),
          ),
        ),
      ),
    );

    return field;
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NXSpace.s6,
        vertical: NXSpace.s2,
      ),
      decoration: BoxDecoration(
        color: palette.hover,
        borderRadius: BorderRadius.circular(NXRadius.radius6),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          height: 1,
        ),
      ),
    );
  }
}
