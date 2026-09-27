import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/albums/albums_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/collections/collections_screen.dart';
import '../screens/settings/nphotos_settings_screen.dart';
import '../models/collection.dart';

class NPhotosApp extends StatelessWidget {
  const NPhotosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const NAppShell(title: 'NPhotos', home: NPhotosHome());
  }
}

// Destinos principales: bottom bar (móvil) y base del sidebar (desktop).
const _navItems = [
  NNavigationDestination(
    icon: Icons.photo_outlined,
    activeIcon: Icons.photo,
    label: 'Fotos',
  ),
  NNavigationDestination(
    icon: Icons.photo_album_outlined,
    activeIcon: Icons.photo_album,
    label: 'Álbumes',
  ),
  NNavigationDestination(
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
    label: 'Favoritos',
  ),
  NNavigationDestination(
    icon: Icons.collections_bookmark_outlined,
    activeIcon: Icons.collections_bookmark,
    label: 'Colecciones',
  ),
];

// Sidebar desktop: principales + las opciones de colecciones.
List<NNavigationDestination> get _sidebarItems => [
  ..._navItems,
  ...CollectionKind.values.map(
    (kind) => NNavigationDestination(icon: kind.icon, label: kind.label),
  ),
];

class NPhotosHome extends StatefulWidget {
  const NPhotosHome({super.key});

  @override
  State<NPhotosHome> createState() => _NPhotosHomeState();
}

class _NPhotosHomeState extends State<NPhotosHome> {
  int _selectedIndex = 0;

  // Instance del controlador único para toda la app
  late final GalleryController _galleryController;

  @override
  void initState() {
    super.initState();
    _galleryController = GalleryController();
    _galleryController.fetchPhotos();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NPhotosSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantallas principales (móvil) inyectando el controller.
    final mainScreens = [
      GalleryScreen(controller: _galleryController),
      AlbumsScreen(controller: _galleryController),
      FavoritesScreen(controller: _galleryController),
      CollectionsScreen(controller: _galleryController),
    ];

    // Desktop: principales + un detalle por cada colección.
    final desktopScreens = [
      ...mainScreens,
      ...CollectionKind.values.map(
        (kind) =>
            CollectionDetailScreen(controller: _galleryController, kind: kind),
      ),
    ];

    int clampIndex(int index, int length) =>
        length == 0 ? 0 : index.clamp(0, length - 1);

    return ResponsiveLayout(
      mobileLayout: NMobileLayout(
        title: 'NPhotos',
        body: IndexedStack(
          index: clampIndex(_selectedIndex, mainScreens.length),
          children: mainScreens,
        ),
        currentIndex: clampIndex(_selectedIndex, _navItems.length),
        onNavigationIndexChanged: (i) => setState(() => _selectedIndex = i),
        navigationItems: _navItems,
        onSettingsPressed: _openSettings,
      ),
      desktopLayout: NDesktopLayout(
        body: IndexedStack(
          index: clampIndex(_selectedIndex, desktopScreens.length),
          children: desktopScreens,
        ),
        selectedIndex: clampIndex(_selectedIndex, _sidebarItems.length),
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        sidebarItems: _sidebarItems,
        onSettingsPressed: _openSettings,
      ),
    );
  }
}
