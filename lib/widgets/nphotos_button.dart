import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';

/// Botón NEXORA. Variantes: `primary`, `secondary`, `ghost`.
enum NPhotosButtonVariant { primary, secondary, ghost }

class NPhotosButton extends StatefulWidget {
  const NPhotosButton.primary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = false,
  }) : variant = NPhotosButtonVariant.primary;

  const NPhotosButton.secondary({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = false,
  }) : variant = NPhotosButtonVariant.secondary;

  const NPhotosButton.ghost({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = false,
  }) : variant = NPhotosButtonVariant.ghost;

  final NPhotosButtonVariant variant;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  State<NPhotosButton> createState() => _NPhotosButtonState();
}

class _NPhotosButtonState extends State<NPhotosButton> {
  bool _hovered = false;

  Color _background(BuildContext context) {
    final palette = NexoraPalette.of(context);
    switch (widget.variant) {
      case NPhotosButtonVariant.primary:
        if (_hovered && widget.onPressed != null) return NXColors.primaryHover;
        return NXColors.primary;
      case NPhotosButtonVariant.secondary:
        return palette.elevated;
      case NPhotosButtonVariant.ghost:
        return _hovered ? palette.hover : Colors.transparent;
    }
  }

  Color _foreground(BuildContext context) {
    final palette = NexoraPalette.of(context);
    switch (widget.variant) {
      case NPhotosButtonVariant.primary:
        return Colors.white;
      case NPhotosButtonVariant.secondary:
      case NPhotosButtonVariant.ghost:
        return palette.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final hasBorder = widget.variant == NPhotosButtonVariant.secondary;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered && enabled ? 1.01 : 1.0,
        duration: NXTransition.fast,
        curve: NXTransition.easeOut,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            color: _background(context),
            borderRadius: BorderRadius.circular(NXRadius.radius10),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(NXRadius.radius10),
              hoverColor: Colors.transparent,
              child: AnimatedContainer(
                duration: NXTransition.fast,
                curve: NXTransition.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: NXSpace.s16,
                  vertical: NXSpace.s10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(NXRadius.radius10),
                  border: hasBorder
                      ? Border.all(color: NexoraPalette.of(context).border)
                      : null,
                ),
                child: Row(
                  mainAxisSize: widget.expanded
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon case final icon?) ...[
                      Icon(icon, size: 17, color: _foreground(context)),
                      const SizedBox(width: NXSpace.s8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: _foreground(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de icono NEXORA (36px, radio 10, fondo hover/active sutil).
class NPhotosIconButton extends StatefulWidget {
  const NPhotosIconButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.size = 36,
    this.active = false,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool active;

  @override
  State<NPhotosIconButton> createState() => _NPhotosIconButtonState();
}

class _NPhotosIconButtonState extends State<NPhotosIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final enabled = widget.onPressed != null;
    final background = widget.active
        ? NXColors.red20
        : _hovered
            ? palette.hover
            : Colors.transparent;
    final foreground = widget.active
        ? NXColors.primary
        : palette.textPrimary;

    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: NXTransition.base,
        curve: NXTransition.easeOut,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(NXRadius.radius10),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(NXRadius.radius10),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(NXRadius.radius10),
            hoverColor: Colors.transparent,
            child: AnimatedOpacity(
              duration: NXTransition.fast,
              opacity: enabled ? 1 : 0.35,
              child: Icon(
                widget.icon,
                size: 18,
                color: _hovered && !widget.active
                    ? palette.textPrimary
                    : foreground,
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}