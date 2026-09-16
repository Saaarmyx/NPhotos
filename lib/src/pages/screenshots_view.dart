import 'package:flutter/material.dart';

import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../widgets/photo_grid.dart';

/// Vista "Screenshots": capturas detectadas por nombres habituales.
class ScreenshotsView extends StatefulWidget {
  const ScreenshotsView({super.key});

  @override
  State<ScreenshotsView> createState() => _ScreenshotsViewState();
}

class _ScreenshotsViewState extends State<ScreenshotsView> {
  Future<void> _autoLoad() async {
    final controller = await StoreController.instance();
    if (controller.photos.isEmpty && !controller.loading) {
      await controller.scanAll();
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLoad());
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
        if (controller.photos.isEmpty) {
          return NPhotosEmptyState(
            icon: Icons.crop_original_outlined,
            title: 'No photos in your archive',
            subtitle: 'Scan your library first to find screenshots.',
          );
        }
        final screenshots = screenshotsOf(controller.photos);
        if (screenshots.isEmpty) {
          return NPhotosEmptyState(
            icon: Icons.crop_original_outlined,
            title: 'No screenshots found',
            subtitle:
                'Looked for files named like screenshot, captura, screen '
                'or pantalla. Your captures will appear here.',
          );
        }
        return ValueListenableBuilder<String>(
          valueListenable: globalSearchQuery,
          builder: (context, query, _) {
            final visible = filterPhotosByName(screenshots, query);
            if (visible.isEmpty && query.trim().isNotEmpty) {
              return NPhotosEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No results',
                subtitle: 'Nothing matches "$query".',
              );
            }
            return ThumbnailGrid(
              photos: visible,
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
