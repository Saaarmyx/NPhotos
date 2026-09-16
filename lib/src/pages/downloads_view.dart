import 'package:flutter/material.dart';

import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../widgets/photo_grid.dart';

/// Vista "Downloads": fotos dentro de la carpeta Downloads.
class DownloadsView extends StatefulWidget {
  const DownloadsView({super.key});

  @override
  State<DownloadsView> createState() => _DownloadsViewState();
}

class _DownloadsViewState extends State<DownloadsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = await StoreController.instance();
      if (controller.photos.isEmpty && !controller.loading) {
        await controller.scanAll();
        if (mounted) setState(() {});
      }
    });
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
            icon: Icons.download_outlined,
            title: 'No photos in your archive',
            subtitle: 'Scan your library first to find downloads.',
          );
        }
        final downloads = controller.photos.where(downloadedOf).toList();
        if (downloads.isEmpty) {
          return NPhotosEmptyState(
            icon: Icons.download_outlined,
            title: 'No downloads folder yet',
            subtitle: 'Photos you download on this device will appear here.',
          );
        }
        return ValueListenableBuilder<String>(
          valueListenable: globalSearchQuery,
          builder: (context, query, _) {
            final visible = filterPhotosByName(downloads, query);
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
