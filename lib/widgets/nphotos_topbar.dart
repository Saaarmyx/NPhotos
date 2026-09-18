import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import 'nphotos_group_selector.dart';
import 'nphotos_sidebar.dart';
import '../src/widgets/photo_grid.dart';

/// Cabecera NEXORA como elementos flotantes (sin barra continua):
/// - Izquierda: círculos flotantes compactos — alternar sidebar, buscar, configuración.
/// - Centro: píldora flotante con el selector de agrupación (año/mes).
/// - Derecha (opcional): acciones contextuales de la sección, también en círculos flotantes.
///
/// IMPORTANTE: este widget ya no tiene una altura fija de contenedor (antes 56px).
/// Al usar Stack + Positioned, necesita que el padre le dé un área con altura
/// acotada (por ejemplo, dentro de un SizedBox o como capa superior de otro Stack
/// que cubra el área de contenido).
class NPhotosTopBar extends StatefulWidget {
  const NPhotosTopBar({
    super.key,
    required this.section,
    this.title,
    this.subtitle,
    this.enableSearch = true,
    this.onQueryChanged,
    this.actions,
    this.groupMode,
    this.onGroupModeChanged,
    this.onToggleSidebar,
    this.onOpenSettings,
    this.searchFocusNode,
    this.topPadding = NXSpace.s16,
    this.sidePadding = NXSpace.s16,
  });

  final NPhotoSection section;
  final String? title;
  final String? subtitle;
  final bool enableSearch;
  final ValueChanged<String>? onQueryChanged;
  final List<Widget>? actions;
  final PhotoGroupMode? groupMode;
  final ValueChanged<PhotoGroupMode>? onGroupModeChanged;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onOpenSettings;
  final FocusNode? searchFocusNode;
  final double topPadding;
  final double sidePadding;

  @override
  State<NPhotosTopBar> createState() => _NPhotosTopBarState();
}

class _NPhotosTopBarState extends State<NPhotosTopBar> {
  bool _searchOpen = false;

  @override
  Widget build(BuildContext context) {
    final hasHeaderText = widget.title != null || widget.subtitle != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Izquierda: cluster flotante ──
        Positioned(
          top: widget.topPadding,
          left: widget.sidePadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onToggleSidebar != null)
                _FloatingCircleButton(
                  icon: Icons.menu_rounded,
                  tooltip: 'Alternar barra lateral',
                  onPressed: widget.onToggleSidebar!,
                ),
              if (widget.enableSearch) ...[
                const SizedBox(width: NXSpace.s8),
                _searchOpen
                    ? _FloatingSearchField(
                        onQueryChanged: widget.onQueryChanged,
                        focusNode: widget.searchFocusNode,
                        onClose: () => setState(() => _searchOpen = false),
                      )
                    : _FloatingCircleButton(
                        icon: Icons.search_rounded,
                        tooltip: 'Buscar',
                        onPressed: () => setState(() => _searchOpen = true),
                      ),
              ],
              const SizedBox(width: NXSpace.s8),
              _FloatingCircleButton(
                icon: Icons.settings_outlined,
                tooltip: 'Configuración',
                onPressed: widget.onOpenSettings ?? () {},
                enabled: widget.onOpenSettings != null,
              ),
            ],
          ),
        ),

        // ── Centro: título + selector de agrupación (año/mes) ──
        if (hasHeaderText ||
            (widget.groupMode != null && widget.onGroupModeChanged != null))
          Positioned(
            top: widget.topPadding,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasHeaderText)
                    Padding(
                      padding: const EdgeInsets.only(bottom: NXSpace.s8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  if (widget.groupMode != null &&
                      widget.onGroupModeChanged != null)
                    _FloatingPill(
                      child: NPhotosGroupSelector(
                        value: widget.groupMode!,
                        onChanged: widget.onGroupModeChanged!,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // ── Derecha (opcional): acciones contextuales de la sección ──
        if (widget.actions != null && widget.actions!.isNotEmpty)
          Positioned(
            top: widget.topPadding,
            right: widget.sidePadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in widget.actions!) ...[
                  _FloatingWrap(child: action),
                  const SizedBox(width: NXSpace.s8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Círculo flotante compacto (36x36 por defecto) con sombra y hover.
class _FloatingCircleButton extends StatefulWidget {
  const _FloatingCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_FloatingCircleButton> createState() => _FloatingCircleButtonState();
}

class _FloatingCircleButtonState extends State<_FloatingCircleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.enabled ? widget.onPressed : null,
            child: AnimatedContainer(
              duration: NXTransition.fast,
              curve: NXTransition.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _hovered ? 0.18 : 0.12,
                    ),
                    blurRadius: _hovered ? 10 : 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                size: 17,
                color: widget.enabled
                    ? (_hovered ? palette.textPrimary : palette.textSecondary)
                    : palette.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora flotante que envuelve el selector de agrupación (año/mes).
class _FloatingPill extends StatelessWidget {
  const _FloatingPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: NXSpace.s12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

/// Campo de búsqueda flotante que reemplaza temporalmente el círculo de búsqueda.
class _FloatingSearchField extends StatelessWidget {
  const _FloatingSearchField({
    required this.onQueryChanged,
    required this.onClose,
    this.focusNode,
  });

  final ValueChanged<String>? onQueryChanged;
  final VoidCallback onClose;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      height: 36,
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: NXSpace.s12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 16, color: palette.textSecondary),
          const SizedBox(width: NXSpace.s8),
          Expanded(
            child: TextField(
              focusNode: focusNode,
              autofocus: true,
              onChanged: onQueryChanged,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Buscar…',
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Envuelve una acción de sección arbitraria para mantener consistencia visual
/// con los demás botones flotantes.
class _FloatingWrap extends StatelessWidget {
  const _FloatingWrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Material(
      color: palette.surface,
      shape: const CircleBorder(),
      elevation: 0,
      child: Padding(padding: const EdgeInsets.all(6), child: child),
    );
  }
}
