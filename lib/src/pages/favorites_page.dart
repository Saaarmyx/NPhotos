import 'package:flutter/material.dart';

import '../core.dart';
import '../widgets/photo_grid.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Future<List>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _fetch();
  }

  Future<List> _fetch() async {
    final controller = await StoreController.instance();
    await controller.refreshFavorites();
    return controller.photosForPaths(controller.favorites);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: FutureBuilder<List>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final photos = snapshot.data!;
          if (photos.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aún no has marcado favoritas'),
                ],
              ),
            );
          }
          return ThumbnailGrid(
            photos: photos.cast(),
            onChanged: _load,
          );
        },
      ),
    );
  }
}