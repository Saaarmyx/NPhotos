import 'package:flutter/material.dart';

import 'src/core.dart';
import 'src/pages/albums_page.dart';
import 'src/pages/favorites_page.dart';
import 'src/pages/gallery_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NexoraPhotosApp());
}

class NexoraPhotosApp extends StatefulWidget {
  const NexoraPhotosApp({super.key});

  @override
  State<NexoraPhotosApp> createState() => _NexoraPhotosAppState();
}

class _NexoraPhotosAppState extends State<NexoraPhotosApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const pages = [GalleryPage(), FavoritesPage(), AlbumsPage()];
    return MaterialApp(
      title: 'Nexora Photos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: FutureBuilder<StoreController>(
        future: StoreController.instance(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text('Error inicializando Rust: ${snapshot.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return Scaffold(
            body: IndexedStack(index: _index, children: pages),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library),
                  label: 'Galería',
                ),
                NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Favoritos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.collections_outlined),
                  selectedIcon: Icon(Icons.collections),
                  label: 'Álbumes',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}