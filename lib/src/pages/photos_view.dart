import 'package:flutter/material.dart';

import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../widgets/photo_grid.dart';

class PhotosView extends StatefulWidget {
  const PhotosView({
    super.key,
    required this.groupMode,
    required this.onGroupModeChanged,
  });

  final PhotoGroupMode groupMode;
  final ValueChanged<PhotoGroupMode> onGroupModeChanged;

  @override
  State<PhotosView> createState() => _PhotosViewState();
}

class _PhotosViewState extends State<PhotosView> {
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

  @override
  Widget build(BuildContext context) {
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
            onAction: controller.scanAll,
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
            onAction: controller.scanAll,
          );
        }

        return ValueListenableBuilder<String>(
          valueListenable: globalSearchQuery,
          builder: (context, query, _) {
            final visible = filterPhotosByName(controller.photos, query);
            if (visible.isEmpty && query.trim().isNotEmpty) {
              return NPhotosEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Nothing matches "$query". Try a different name.',
              );
            }
            return ThumbnailGrid(
              photos: visible,
              groupMode: widget.groupMode,
              onChanged: () {
                if (mounted) setState(() {});
              },
            );
          },
        );
      },
    );
  }
}
