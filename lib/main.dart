import 'package:flutter/material.dart';

import 'src/core.dart';
import 'src/pages/albums_page.dart';
import 'src/pages/captures_page.dart';
import 'src/pages/favorites_page.dart';
import 'src/pages/gallery_page.dart';
import 'src/pages/secure_folder_page.dart';
import 'src/pages/settings_page.dart';
import 'src/pages/trash_page.dart';
import 'src/pages/videos_page.dart';

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

  static const _destinations = [
    _RailDest(icon: Icons.photo_library_outlined, label: 'Galería'),
    _RailDest(icon: Icons.favorite_outline, label: 'Favoritos'),
    _RailDest(icon: Icons.collections_outlined, label: 'Álbumes'),
    _RailDest(icon: Icons.delete_outline, label: 'Papelera'),
    _RailDest(icon: Icons.videocam_outlined, label: 'Videos'),
    _RailDest(icon: Icons.crop_landscape_outlined, label: 'Capturas'),
    _RailDest(icon: Icons.lock_outline, label: 'Carpeta segura'),
    _RailDest(icon: Icons.settings_outlined, label: 'Config'),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Nexora Photos',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: mode,
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
            return _MainShell(
              index: _index,
              onChanged: (i) => setState(() => _index = i),
            );
          },
        ),
      ),
    );
  }
}

class _RailDest {
  const _RailDest({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _MainShell extends StatelessWidget {
  const _MainShell({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const pages = [
      GalleryPage(),
      FavoritesPage(),
      AlbumsPage(),
      TrashPage(),
      VideosPage(),
      CapturesPage(),
      SecureFolderPage(),
      SettingsPage(),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: onChanged,
            extended: true,
            labelType: NavigationRailLabelType.none,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: const [
                  SizedBox(width: 16),
                  Icon(Icons.burst_mode, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text('Nexora',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            destinations: [
              for (final d in _NexoraPhotosAppState._destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: IndexedStack(index: index, children: pages)),
        ],
      ),
    );
  }
}