import 'package:flutter/material.dart';

import '../../design/nexora_tokens.dart';
import '../../widgets/nphotos_empty_state.dart';
import '../../widgets/section_header.dart';
import '../core.dart';
import '../rust/api.dart';
import '../widgets/photo_grid.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<List<Photo>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _fetch();
    if (mounted) setState(() {});
  }

  Future<List<Photo>> _fetch() async {
    final controller = await StoreController.instance();
    await controller.refreshFavorites();
    return controller.photosForPaths(controller.favorites);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: NXSpace.s20),
          child: FutureBuilder<List<Photo>>(
            future: _future,
            builder: (context, snapshot) => SectionHeader(
              title: 'Favorites',
              subtitle:
                  '${snapshot.data?.length ?? 0} ${(snapshot.data?.length ?? 0) == 1 ? 'photo' : 'photos'} you loved',
              padding: const EdgeInsets.fromLTRB(
                NXSpace.s24,
                0,
                NXSpace.s24,
                NXSpace.s16,
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Photo>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final photos = snapshot.data!;
              if (photos.isEmpty) {
                return NPhotosEmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorites yet',
                  subtitle:
                      'Tap the heart on any photo to keep it here.',
                );
              }
              return ValueListenableBuilder<String>(
                valueListenable: globalSearchQuery,
                builder: (context, query, _) {
                  final q = query.trim().toLowerCase();
                  final visible = q.isEmpty
                      ? photos
                      : photos.where((p) => p.name.toLowerCase().contains(q)).toList();
                  return ThumbnailGrid(
                    photos: visible,
                    onChanged: _load,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}