import 'package:flutter/material.dart';

import '../../widgets/nphotos_empty_state.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<List<Photo>> _fetch() async {
    final controller = await StoreController.instance();
    await controller.refreshFavorites();
    return controller.photosForPaths(controller.favorites);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Photo>>(
      future: _fetch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final photos = snapshot.data!;
        if (photos.isEmpty) {
          return NPhotosEmptyState(
            icon: Icons.favorite_border_rounded,
            title: 'No favorites yet',
            subtitle: 'Tap the heart on any photo to keep it here.',
          );
        }
        return ValueListenableBuilder<String>(
          valueListenable: globalSearchQuery,
          builder: (context, query, _) {
            final visible = filterPhotosByName(photos, query);
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
