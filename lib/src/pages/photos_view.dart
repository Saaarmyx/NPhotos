import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_button.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

class PhotosView extends StatefulWidget {
  const PhotosView({super.key});

  @override
  State<PhotosView> createState() => _PhotosViewState();
}

class _PhotosViewState extends State<PhotosView>
    with AutomaticKeepAliveClientMixin {
  PhotoGroupBy _groupBy = PhotoGroupBy.none;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
  }

  Future<void> _autoLoad() async {
    final controller = await StoreController.instance();
    if (controller.photos.isEmpty && !controller.loading) {
      await controller.scanAll();
      if (mounted) setState(() {});
    }
  }

  Future<void> _reload() async {
    final controller = await StoreController.instance();
    await controller.scanAll();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NXSpace.s20),
          child: FutureBuilder<StoreController>(
            future: StoreController.instance(),
            builder: (context, snapshot) {
              final controller = snapshot.data;
              final count = controller?.photos.length ?? 0;
              return SectionHeader(
                title: 'Photos',
                subtitle:
                    '$count ${count == 1 ? 'photo' : 'photos'} in your archive',
                padding: const EdgeInsets.fromLTRB(
                  NXSpace.s24,
                  0,
                  NXSpace.s24,
                  NXSpace.s16,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GroupSelector(
                      value: _groupBy,
                      onChanged: (v) => setState(() => _groupBy = v),
                    ),
                    SizedBox(width: NXSpace.s8),
                    NPhotosIconButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Rescan library',
                      onPressed: _reload,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(child: _Content(groupBy: _groupBy, onChanged: _reload)),
      ],
    );
  }
}

class _Content extends StatefulWidget {
  const _Content({required this.groupBy, required this.onChanged});

  final PhotoGroupBy groupBy;
  final VoidCallback onChanged;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<StoreController>(
      future: StoreController.instance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final controller = snapshot.data!;

        if (controller.loading) {
          return const NPhotosLoadingState(label: 'Scanning your library…');
        }
        if (controller.errorText != null) {
          return NPhotosEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Library unavailable',
            subtitle: controller.errorText,
            actionLabel: 'Retry',
            onAction: widget.onChanged,
          );
        }
        if (controller.photos.isEmpty) {
          return NPhotosEmptyState(
            icon: Icons.photo_library_outlined,
            title: 'Your archive is empty',
            subtitle:
                'NPhotos will search your personal folder for photos '
                '(.jpg, .png, .heic…) and keep them organized here.',
            actionLabel: 'Scan now',
            onAction: widget.onChanged,
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: globalSearchQuery,
          builder: (context, query, _) {
            final visible = _filter(controller.photos, query);
            if (visible.isEmpty && query.trim().isNotEmpty) {
              return NPhotosEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Nothing matches “$query”. Try a different name.',
              );
            }
            return ThumbnailGrid(
              photos: visible,
              groupBy: widget.groupBy,
              onChanged: () {
                if (mounted) setState(() {});
              },
            );
          },
        );
      },
    );
  }

  List<Photo> _filter(List<Photo> photos, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return photos;
    return photos.where((p) => p.name.toLowerCase().contains(q)).toList();
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({required this.value, required this.onChanged});

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
                      color: value == mode ? palette.active : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 15, color: palette.textSecondary),
                        const SizedBox(width: NXSpace.s6),
                        Text(
                          label,
                          style: NXText.albumName(context).copyWith(
                            color: palette.textSecondary,
                          ),
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