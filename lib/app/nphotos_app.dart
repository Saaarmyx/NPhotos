import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/albums/albums_screen.dart';
import '../screens/favorites/favorites_screen.dart';

class NPhotosApp extends StatelessWidget {
  const NPhotosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: AppAppearance.accentColor,
      builder: (context, _, child) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppAppearance.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'NPhotos',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          home: const NPhotosHome(),
        ),
      ),
    );
  }
}

// Misma lista pensada para bottom bar (móvil) y sidebar (desktop, cuando
// retomemos esa plataforma).
const _navItems = [
  NBottomBarItem(
    icon: Icons.photo_outlined,
    activeIcon: Icons.photo,
    label: 'Fotos',
  ),
  NBottomBarItem(
    icon: Icons.photo_album_outlined,
    activeIcon: Icons.photo_album,
    label: 'Álbumes',
  ),
  NBottomBarItem(
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
    label: 'Favoritos',
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
      MaterialPageRoute(
        builder: (_) => NSettingsScreen(
          profileData: const UserProfileData(
            name: 'Nexora Labs',
            email: 'nexora@ncloud.com',
            avatarUrl: '',
            storageUsedGb: 1.2,
            storageTotalGb: 256,
          ),
          appInfo: const NAboutAppInfo(
            appName: 'NPhotos',
            version: '0.1.0',
            buildNumber: '1',
          ),
          additionalGroups: [
            NAdditionalSettingsGroup(
              title: 'Organización inteligente',
              items: [
                NSettingsOptionItem(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Seleccionar mejor foto',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.face_retouching_natural_outlined,
                  title: 'Agrupar rostros similares',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.burst_mode_outlined,
                  title: 'Agrupar fotos en ráfaga',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.calendar_today_outlined,
                  title: 'Un día como hoy',
                  onTap: () {},
                ),
              ],
            ),
            NAdditionalSettingsGroup(
              title: 'Explorar y compartir',
              items: [
                NSettingsOptionItem(
                  icon: Icons.visibility_off_outlined,
                  title: 'Ver álbumes ocultos',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.text_fields_outlined,
                  title: 'Reconocer texto en imágenes',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.transform_outlined,
                  title: 'Convertir HEIF antes de enviar',
                  onTap: () {},
                ),
                NSettingsOptionItem(
                  icon: Icons.share_outlined,
                  title: 'Compartir de forma segura',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas dinámicamente inyectando el controller
    final screens = [
      GalleryScreen(controller: _galleryController),
      AlbumsScreen(controller: _galleryController),
      FavoritesScreen(controller: _galleryController),
    ];

    final body = IndexedStack(index: _selectedIndex, children: screens);

    return NMobileLayout(
      title: 'NPhotos',
      body: body,
      currentIndex: _selectedIndex,
      onNavigationIndexChanged: (i) => setState(() => _selectedIndex = i),
      navigationItems: _navItems,
      onSettingsPressed: _openSettings,
    );
  }
}
