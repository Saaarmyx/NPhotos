import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/nexora_tokens.dart';

/// Búsqueda NEXORA expandible: icono cuando está cerrada, campo cuando se
/// abre (foco o toque). Se colapsa al perder el foco sin consulta o con Escape.
class NPhotosSearch extends StatefulWidget {
  const NPhotosSearch({
    super.key,
    required this.onQueryChanged,
    this.hintText = 'Buscar fotos…',
    this.focusNode,
    this.initialQuery,
  });

  final ValueChanged<String> onQueryChanged;
  final String hintText;
  final FocusNode? focusNode;
  final String? initialQuery;

  @override
  State<NPhotosSearch> createState() => NPhotosSearchState();
}

class NPhotosSearchState extends State<NPhotosSearch> {
  late final FocusNode _focus;
  late final bool _focusOwned;
  late final TextEditingController _controller;
  bool _hovered = false;

  bool get _queryEmpty => _controller.text.isEmpty;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focusOwned = widget.focusNode == null;
    _controller = widget.initialQuery != null
        ? TextEditingController(text: widget.initialQuery)
        : TextEditingController();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    if (_focusOwned) _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  /// Expande y enfoca el campo (usado también por el atajo global).
  void expand() {
    if (!_focus.hasFocus) _focus.requestFocus();
    if (mounted) setState(() {});
  }

  /// Colapsa el campo y limpia la consulta.
  void collapse() {
    _controller.clear();
    widget.onQueryChanged('');
    _focus.unfocus();
    if (mounted) setState(() {});
  }

  void _onChanged(String value) {
    widget.onQueryChanged(value);
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      collapse();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);

    return ListenableBuilder(
      listenable: _focus,
      builder: (context, _) {
        final isOpen = _focus.hasFocus || !_queryEmpty;
        return AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          height: 38,
          width: isOpen ? 260 : 38,
          child: isOpen ? _field(context, palette) : _iconButton(context, palette),
        );
      },
    );
  }

  Widget _iconButton(BuildContext context, NexoraPalette palette) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: 'Buscar  (⌘K)',
        child: GestureDetector(
          onTap: expand,
          child: AnimatedContainer(
            duration: NXTransition.fast,
            curve: NXTransition.easeOut,
            decoration: BoxDecoration(
              color: _hovered ? palette.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(NXRadius.radius10),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 18,
              color: palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, NexoraPalette palette) {
    final hasQuery = !_queryEmpty;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(NXRadius.radius10),
            border: Border.all(
              color: _focus.hasFocus
                  ? NXColors.primary.withValues(alpha: 0.65)
                  : _hovered
                  ? palette.textMuted.withValues(alpha: 0.45)
                  : palette.border,
            ),
          ),
          child: Row(
            children: [
              AnimatedOpacity(
                duration: NXTransition.fast,
                opacity: _focus.hasFocus ? 1 : 0.55,
                child: Icon(
                  Icons.search_rounded,
                  size: 16,
                  color: _focus.hasFocus ? NXColors.primary : palette.textBody,
                ),
              ),
              const SizedBox(width: NXSpace.s8),
              Expanded(
                child: TextField(
                  controller: _controller,
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
                    _onChanged('');
                    _controller.clear();
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NXSpace.s4,
                    vertical: NXSpace.s2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.hover,
                    borderRadius: BorderRadius.circular(NXRadius.radius6),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.all(NXSpace.s2),
          child: Icon(
            Icons.close_rounded,
            size: 14,
            color: palette.textMuted,
          ),
        ),
      ),
    );
  }
}