import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';

enum NPhotoSection {
  photos('Galería', Icons.photo_library_outlined),
  albums('Álbumes', Icons.collections_bookmark_outlined),
  favorites('Favoritos', Icons.favorite_border_rounded),
  videos('Videos', Icons.movie_outlined),
  screenshots('Capturas', Icons.crop_original_outlined),
  downloads('Descargas', Icons.download_outlined),
  trash('Papelera', Icons.delete_outline_rounded),
  secureFolder('Carpeta segura', Icons.lock_outline_rounded),
  settings('Configuración', Icons.settings_outlined);

  const NPhotoSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

/// Sidebar NEXORA con dos estados: expandido (icono + nombre) o rail
/// colapsado (~64 px, solo iconos). El rojo es acento del estado activo.
class NPhotosSidebar extends StatelessWidget {
  const NPhotosSidebar({
    super.key,
    required this.current,
    required this.onSectionSelected,
    this.photoCount = 0,
    this.expanded = true,
  });

  final NPhotoSection current;
  final ValueChanged<NPhotoSection> onSectionSelected;
  final int photoCount;
  final bool expanded;

  static const double railWidth = 64;
  static const double expandedWidth = 248;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);

    final albumsGroup = <NPhotoSection>[
      NPhotoSection.photos,
      NPhotoSection.albums,
      NPhotoSection.favorites,
      NPhotoSection.trash,
    ];
    final sectionsGroup = <NPhotoSection>[
      NPhotoSection.videos,
      NPhotoSection.secureFolder,
      NPhotoSection.downloads,
      NPhotoSection.screenshots,
    ];
    final systemGroup = <NPhotoSection>[
      NPhotoSection.settings,
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: NXSpace.s10),
          _NPhotosBrand(expanded: expanded),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: NXSpace.s6),
              children: [
                _SectionLabel('ÁLBUMES', expanded),
                for (final s in albumsGroup)
                  _SidebarItem(
                    section: s,
                    selected: current == s,
                    expanded: expanded,
                    onTap: () => onSectionSelected(s),
                  ),
                _SectionDivider(),
                _SectionLabel('SECCIONES', expanded),
                for (final s in sectionsGroup)
                  _SidebarItem(
                    section: s,
                    selected: current == s,
                    expanded: expanded,
                    onTap: () => onSectionSelected(s),
                  ),
                _SectionDivider(),
                _SectionLabel('SISTEMA', expanded),
                for (final s in systemGroup)
                  _SidebarItem(
                    section: s,
                    selected: current == s,
                    expanded: expanded,
                    onTap: () => onSectionSelected(s),
                  ),
              ],
            ),
          ),
          _SidebarFooter(photoCount: photoCount, expanded: expanded),
        ],
      ),
    );
  }
}

class _NPhotosBrand extends StatelessWidget {
  const _NPhotosBrand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NXSpace.s14,
        NXSpace.s8,
        NXSpace.s14,
        NXSpace.s12,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NXColors.primary, NXColors.primaryHover],
              ),
              borderRadius: BorderRadius.circular(NXRadius.radius12),
            ),
            child: const Icon(
              Icons.photo_camera_back_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: NXTransition.base,
              switchInCurve: NXTransition.easeOut,
              switchOutCurve: NXTransition.easeOut,
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: expanded
                  ? Padding(
                      key: const ValueKey('brand-text'),
                      padding: const EdgeInsets.only(left: NXSpace.s12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NEXORA',
                            style: NXText.muted(context).copyWith(
                              color: palette.textMuted,
                              fontSize: 10,
                              letterSpacing: 2.4,
                            ),
                          ),
                          Text(
                            'NPhotos',
                            style: NXText.display(context)
                                .copyWith(letterSpacing: -0.4, fontSize: 20),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('brand-none')),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.expanded);

  final String label;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        expanded ? NXSpace.s20 : 0,
        NXSpace.s10,
        0,
        NXSpace.s8,
      ),
      child: AnimatedOpacity(
        duration: NXTransition.base,
        curve: NXTransition.easeOut,
        opacity: expanded ? 1 : 0,
        child: Text(
          label,
          textAlign: expanded ? TextAlign.start : TextAlign.center,
          style: NXText.muted(context).copyWith(
            color: palette.textMuted,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NXSpace.s6),
      child: Divider(
        height: 1,
        thickness: 1,
        indent: NXSpace.s12,
        endIndent: NXSpace.s12,
        color: palette.border,
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.section,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final NPhotoSection section;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    final background = widget.selected
        ? palette.active
        : _hovered
        ? palette.hover
        : Colors.transparent;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? NXSpace.s8 : NXSpace.s10,
        vertical: NXSpace.s2,
      ),
      child: Tooltip(
        message: widget.expanded ? '' : widget.section.title,
        waitDuration: const Duration(milliseconds: 450),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: NXTransition.base,
              curve: NXTransition.easeOut,
              height: 38,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(NXRadius.radius8),
              ),
              child: Row(
                children: [
                  const SizedBox(width: NXSpace.s6),
                  SizedBox(
                    width: 3,
                    height: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: widget.selected
                            ? NXColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  AnimatedContainer(
                    duration: NXTransition.base,
                    curve: NXTransition.easeOut,
                    width: widget.expanded ? 30 : 22,
                    alignment: widget.expanded
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: Icon(
                      widget.section.icon,
                      size: 17,
                      color: widget.selected
                          ? NXColors.primary
                          : palette.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: NXTransition.base,
                        switchInCurve: NXTransition.easeOut,
                        switchOutCurve: NXTransition.easeOut,
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: widget.expanded
                            ? Padding(
                                key: const ValueKey('label'),
                                padding: const EdgeInsets.only(
                                  left: NXSpace.s12,
                                ),
                                child: Text(
                                  widget.section.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: NXText.albumName(context).copyWith(
                                    color: widget.selected
                                        ? palette.textPrimary
                                        : palette.textSecondary,
                                    fontWeight: widget.selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(key: ValueKey('none')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.photoCount, required this.expanded});

  final int photoCount;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      height: 56,
      padding: EdgeInsets.symmetric(horizontal: expanded ? NXSpace.s20 : 0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      child: expanded
          ? Row(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 15,
                  color: palette.textMuted,
                ),
                const SizedBox(width: NXSpace.s8),
                Text(
                  '$photoCount ${photoCount == 1 ? 'foto' : 'fotos'} · local',
                  style: NXText.muted(context).copyWith(color: palette.textMuted),
                ),
              ],
            )
          : Icon(
              Icons.photo_library_outlined,
              size: 16,
              color: palette.textMuted,
            ),
    );
  }
}