import 'package:flutter/material.dart';

import '../design/nexora_tokens.dart';
import '../src/rust/api.dart';

enum NPhotoSection {
  photos('Photos', Icons.photo_library_outlined),
  recentlyAdded('Recently Added', Icons.schedule_outlined),
  albums('Albums', Icons.collections_bookmark_outlined),
  favorites('Favorites', Icons.favorite_border_rounded),
  videos('Videos', Icons.movie_outlined),
  screenshots('Screenshots', Icons.crop_original_outlined),
  downloads('Downloads', Icons.download_outlined),
  trash('Trash', Icons.delete_outline_rounded),
  secureFolder('Secure Folder', Icons.lock_outline_rounded),
  settings('Settings', Icons.settings_outlined);

  const NPhotoSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

class NPhotosSidebar extends StatefulWidget {
  const NPhotosSidebar({
    super.key,
    required this.sections,
    required this.current,
    required this.onSectionSelected,
    required this.albums,
    this.onAlbumTap,
    this.width = 240,
  });

  final List<NPhotoSection> sections;
  final NPhotoSection current;
  final ValueChanged<NPhotoSection> onSectionSelected;
  final List<Album> albums;
  final ValueChanged<Album>? onAlbumTap;
  final double width;

  @override
  State<NPhotosSidebar> createState() => _NPhotosSidebarState();
}

class _NPhotosSidebarState extends State<NPhotosSidebar> {
  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);

    final librarySections = <NPhotoSection>[
      NPhotoSection.photos,
      NPhotoSection.albums,
      NPhotoSection.favorites,
      NPhotoSection.recentlyAdded,
    ];
    final photosSections = <NPhotoSection>[
      NPhotoSection.videos,
      NPhotoSection.screenshots,
      NPhotoSection.downloads,
    ];
    final systemSections = <NPhotoSection>[
      NPhotoSection.trash,
      NPhotoSection.secureFolder,
      NPhotoSection.settings,
    ];

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          right: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NPhotosBrand(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: NXSpace.s12),
              children: [
                _SectionLabel('LIBRARY'),
                for (final s in librarySections)
                  _SidebarItem(
                    icon: s.icon,
                    label: s.title,
                    selected: widget.current == s,
                    onTap: () => widget.onSectionSelected(s),
                  ),
                const SizedBox(height: NXSpace.s16),
                _SectionLabel('NPHOTOS'),
                for (final s in photosSections)
                  _SidebarItem(
                    icon: s.icon,
                    label: s.title,
                    selected: widget.current == s,
                    onTap: () => widget.onSectionSelected(s),
                  ),
                if (widget.albums.isNotEmpty) ...[
                  const SizedBox(height: NXSpace.s16),
                  _SectionLabel('ALBUMS'),
                  for (final album in widget.albums)
                    _AlbumSidebarItem(
                      album: album,
                      selected: false,
                      onTap: () => widget.onAlbumTap?.call(album),
                    ),
                ],
                const SizedBox(height: NXSpace.s16),
                _SectionLabel('SYSTEM'),
                for (final s in systemSections)
                  _SidebarItem(
                    icon: s.icon,
                    label: s.title,
                    selected: widget.current == s,
                    onTap: () => widget.onSectionSelected(s),
                  ),
              ],
            ),
          ),
          const _SidebarFooter(),
        ],
      ),
    );
  }

  }

class _NPhotosBrand extends StatelessWidget {
  const _NPhotosBrand();

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NXSpace.s20,
        NXSpace.s24,
        NXSpace.s20,
        NXSpace.s12,
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [NXColors.primary, NXColors.primaryHover],
              ),
              borderRadius: BorderRadius.circular(NXRadius.radius10),
            ),
            child: const Icon(Icons.photo_camera_back_rounded, size: 17, color: Colors.white),
          ),
          const SizedBox(width: NXSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXORA',
                style: NXText.muted(context).copyWith(
                  color: palette.textMuted,
                  fontSize: 10,
                  letterSpacing: 2.6,
                ),
              ),
              Text(
                'NPhotos',
                style: NXText.display(context).copyWith(letterSpacing: -0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NXSpace.s20,
        NXSpace.s8,
        NXSpace.s20,
        NXSpace.s6,
      ),
      child: Text(
        label,
        style: NXText.muted(context).copyWith(
          color: palette.textMuted,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
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

    final item = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: NXSpace.s10),
          height: 36,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(NXRadius.radius8),
          ),
          child: Row(
            children: [
              // Acento rojo sutil
              AnimatedContainer(
                duration: NXTransition.base,
                curve: NXTransition.easeOut,
                width: widget.selected ? 3 : 0,
                height: 16,
                decoration: BoxDecoration(
                  color: NXColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: NXSpace.s12),
              Icon(
                widget.icon,
                size: 17,
                color: widget.selected ? NXColors.primary : palette.textSecondary,
              ),
              const SizedBox(width: NXSpace.s10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NXText.albumName(context).copyWith(
                    color: widget.selected
                        ? palette.textPrimary
                        : palette.textSecondary,
                    fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: NXSpace.s2),
      child: item,
    );
  }
}

class _AlbumSidebarItem extends StatefulWidget {
  const _AlbumSidebarItem({
    required this.album,
    required this.selected,
    required this.onTap,
  });

  final Album album;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AlbumSidebarItem> createState() => _AlbumSidebarItemState();
}

class _AlbumSidebarItemState extends State<_AlbumSidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: NXTransition.base,
          curve: NXTransition.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: NXSpace.s10),
          padding: const EdgeInsets.symmetric(horizontal: NXSpace.s12),
          height: 36,
          decoration: BoxDecoration(
            color: _hovered ? palette.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(NXRadius.radius8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.folder_outlined,
                size: 16,
                color: NXColors.primary,
              ),
              const SizedBox(width: NXSpace.s10),
              Expanded(
                child: Text(
                  widget.album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NXText.albumName(context).copyWith(
                    color: palette.textSecondary,
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

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final palette = NexoraPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(NXSpace.s20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_outlined, size: 16, color: palette.textMuted),
          const SizedBox(width: NXSpace.s8),
          Text(
            'Local library',
            style: NXText.muted(context).copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}