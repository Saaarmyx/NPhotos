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

// Sidebar desktop: principales + el contenido de Colecciones aplanado
// (Lugares, Añadidos recientes). Sin entrada padre "Colecciones": esa
// vive solo en la bottom bar móvil.
List<NNavigationDestination> get _sidebarItems => [
  ..._navItems.sublist(0, 3),
  ...visibleCollectionKinds.map(
    (kind) => NNavigationDestination(icon: kind.icon, label: kind.label),
  ),
];

class NPhotosHome extends StatefulWidget {
  const NPhotosHome({super.key});

  @override
  State<NPhotosHome> createState() => _NPhotosHomeState();
}

class _NPhotosHomeState extends State<NPhotosHome>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Instance del controlador único para toda la app
  late final GalleryController _galleryController;

  // Estado del panel lateral de ajustes en escritorio (patrón del kit:
  // `trailingPanel` de `NDesktopLayout`, igual que el showcase de NexoraUi).
  bool _settingsOpen = false;
  List<String> _panelStack = const ['settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _galleryController = GalleryController();
    _galleryController.fetchPhotos();
    // Recarga dinámica: archivos nuevos aparecen solos, sin recompilar.
    _galleryController.startWatching();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _galleryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del fondo (p. ej. tras tomar una foto con la cámara),
    // recarga por si el watcher no alcanzó el evento.
    if (state == AppLifecycleState.resumed) {
      _galleryController.refresh();
    }
  }

  void _openSettingsMobile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NPhotosSettingsScreen()),
    );
  }

  void _toggleSettingsDesktop() {
    setState(() {
      _settingsOpen = !_settingsOpen;
      if (_settingsOpen) _panelStack = const ['settings'];
    });
  }

  void _openPanelPage(String page) {
    setState(() => _panelStack = [..._panelStack, page]);
  }

  void _backPanel() {
    if (_panelStack.length > 1) {
      setState(() => _panelStack = _panelStack.sublist(0, _panelStack.length - 1));
    }
  }

  String get _currentPanel => _panelStack.last;

  /// Sección base del kit con navegación interna del panel (no `push`).
  /// Sale de [NSettingsScreen.buildNexoraBaseSection]: si el kit añade un
  /// item, el panel desktop lo hereda sin copiar nada.
  NSettingsSection _desktopBaseSection() {
    return NSettingsScreen.buildNexoraBaseSection(
      onAccountTap: () => _openPanelPage('account'),
      onPersonalizationTap: () => _openPanelPage('personalization'),
      onAboutTap: () => _openPanelPage('about'),
    );
  }

  List<NSettingsSection> _desktopSettingsSections() {
    // Release 26.09.28: solo la base del kit. Sin secciones propias
    // (eran botones muertos; ver nphotos_settings_screen.dart).
    return [_desktopBaseSection()];
  }

  Widget _buildTrailingPanel() {
    switch (_currentPanel) {
      case 'account':
        return NSidePanel(
          title: 'Cuenta',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NAccountContent(profileData: nPhotosProfileData),
        );
      case 'personalization':
        return NSidePanel(
          title: 'Personalización',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: NPersonalizationContent(
            onNavigateToAccent: () => _openPanelPage('accent'),
          ),
        );
      case 'accent':
        return NSidePanel(
          title: 'Color de acento',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NAccentColorsContent(),
        );
      case 'about':
        return NSidePanel(
          title: 'Sobre la app',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: NAboutContent(
            appInfo: nPhotosAppInfo,
            onChangeLanguageTap: () => _openPanelPage('language'),
            onPermissionsTap: () => _openPanelPage('permissions'),
            onReportBugTap: () => _openPanelPage('report'),
          ),
        );
      case 'language':
        return NSidePanel(
          title: 'Idioma',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NLanguageContent(),
        );
      case 'permissions':
        return NSidePanel(
          title: 'Gestión de permisos',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NPermissionsContent(),
        );
      case 'report':
        return NSidePanel(
          title: 'Reportar un error',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: NReportBugContent(onSubmitted: _backPanel),
        );
      case 'settings':
      default:
        return NSettingsSidePanel(
          profileData: nPhotosProfileData,
          onClose: _toggleSettingsDesktop,
          sections: _desktopSettingsSections(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pantallas base (desktop + móvil) inyectando el controller.
    final baseScreens = [
      GalleryScreen(controller: _galleryController),
      AlbumsScreen(controller: _galleryController),
      FavoritesScreen(controller: _galleryController),
    ];

    // Móvil añade Colecciones (solo bottom bar, no existe en desktop).
    final mobileScreens = [
      ...baseScreens,
      CollectionsScreen(controller: _galleryController),
    ];

    // Desktop: base + el contenido de Colecciones aplanado, en el mismo
    // orden que [_sidebarItems] para que el índice coincida.
    final desktopScreens = [
      ...baseScreens,
      ...visibleCollectionKinds.map(
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
          index: clampIndex(_selectedIndex, mobileScreens.length),
          children: mobileScreens,
        ),
        currentIndex: clampIndex(_selectedIndex, _navItems.length),
        onNavigationIndexChanged: (i) => setState(() => _selectedIndex = i),
        navigationItems: _navItems,
        onSettingsPressed: _openSettingsMobile,
      ),
      desktopLayout: NDesktopLayout(
        body: IndexedStack(
          index: clampIndex(_selectedIndex, desktopScreens.length),
          children: desktopScreens,
        ),
        selectedIndex: clampIndex(_selectedIndex, _sidebarItems.length),
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        sidebarItems: _sidebarItems,
        onSettingsPressed: _toggleSettingsDesktop,
        showSettingsAction: !_settingsOpen,
        trailingPanel: _settingsOpen ? _buildTrailingPanel() : null,
      ),
    );
  }
}
