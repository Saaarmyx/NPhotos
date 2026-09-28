import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../controllers/gallery_controller.dart';
import '../controllers/selection_controller.dart';
import '../models/photo.dart';
import '../services/local_store.dart';
import '../screens/gallery/gallery_screen.dart';
import '../screens/albums/albums_screen.dart';
import '../screens/collections/collections_screen.dart';
import '../screens/settings/nphotos_permissions.dart';
import '../screens/settings/nphotos_settings_screen.dart';
import '../utils/photo_viewer.dart';
import '../widgets/album_actions_sheet.dart';
import '../widgets/selection_action_bar.dart';
import '../models/collection.dart';

class NPhotosApp extends StatelessWidget {
  final LocalStore? store;

  const NPhotosApp({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    return NAppShell(title: 'NPhotos', home: NPhotosHome(store: store));
  }
}

// Destinos principales: bottom bar (móvil) y base del sidebar (desktop).
// Favoritos vive solo en Álbumes (pin / fila del sistema), no navega.
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
    icon: Icons.collections_bookmark_outlined,
    activeIcon: Icons.collections_bookmark,
    label: 'Colecciones',
    // Solo bottom bar móvil: en desktop se aplana su contenido.
    showOnDesktop: false,
  ),
];

// Sidebar desktop: toma los iconos de la bottom bar (filtra por
// showOnDesktop) + el contenido de Colecciones aplanado
// (Lugares, Añadidos recientes). Sin entrada padre "Colecciones".
List<NNavigationDestination> get _sidebarItems => [
  ..._navItems.where((d) => d.showOnDesktop),
  ...visibleCollectionKinds.map(
    (kind) => NNavigationDestination(icon: kind.icon, label: kind.label),
  ),
];

class NPhotosHome extends StatefulWidget {
  final LocalStore? store;

  const NPhotosHome({super.key, this.store});

  @override
  State<NPhotosHome> createState() => _NPhotosHomeState();
}

class _NPhotosHomeState extends State<NPhotosHome>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;

  // Instance del controlador único para toda la app
  late final GalleryController _galleryController;

  /// Selección múltiple compartida: al activarse, la bottom bar se
  /// reemplaza por la barra de acciones.
  final SelectionController _selection = SelectionController();

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
    // Bienvenida solo el primer arranque.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboarding());
  }

  Future<void> _maybeOnboarding() async {
    final store = widget.store;
    if (!mounted || store == null || store.onboardingDone()) return;
    await startNOnboarding(
      context,
      defaultAccent: NColors.photosAccent,
      defaultAccentName: 'NPhotos',
      onCompleted: () => store.saveOnboarding(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _galleryController.dispose();
    _selection.dispose();
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
    pushNPage(context, const NPhotosSettingsScreen());
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

  static const _menuHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  PopupMenuItem<String> _menuHeader(String text) => PopupMenuItem<String>(
    enabled: false,
    child: Text(text, style: _menuHeaderStyle),
  );

  /// Separador invisible: solo espacio entre secciones (sin raya).
  PopupMenuItem<String> gap() => const PopupMenuItem<String>(
    enabled: false,
    height: 10,
    child: SizedBox.shrink(),
  );

  /// Fila de opción: label + switch a la derecha.
  ///
  /// El tap en el switch lo consume su propio reconocedor (el menú SIGUE
  /// abierto) y el tap en el resto de la fila llega a [onToggle] (cierra).
  /// Exactamente uno dispara (sin valor el onSelected no corre). El
  /// contenido escucha al controlador: el switch se redibuja en vivo.
  PopupMenuItem<String> _switchItem({
    required String label,
    required bool Function() isSelected,
    required VoidCallback onToggle,
  }) {
    return PopupMenuItem<String>(
      onTap: onToggle,
      child: AnimatedBuilder(
        animation: _galleryController,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: NTypography.fontFamilyBase,
                  fontWeight: NTypography.weightSemibold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: isSelected(),
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }

  /// Popup de la topbar móvil (⋮) según la screen activa.
  /// Las opciones multivalor son filas [icono + label + switch]: el tap
  /// en el switch lo consume su propio reconocedor y el tap en la fila
  /// llega a [onToggle]; exactamente uno dispara (sin valor el
  /// onSelected no corre). El switch se redibuja en vivo.
  /// La lupa solo se cablea en galería; el engranaje de ajustes solo
  /// en colecciones (el kit lo pinta debajo del botón popup).
  List<PopupMenuEntry<String>> _galleryPopupItems() {
    final c = _galleryController;
    return [
      _menuHeader('ORDENAR'),
      _switchItem(
        label: 'Por día de captura',
        isSelected: () => c.sort == GallerySort.captureDay,
        onToggle: () => c.setSort(GallerySort.captureDay),
      ),
      _switchItem(
        label: 'Por día de agregación',
        isSelected: () => c.sort == GallerySort.addedDay,
        onToggle: () => c.setSort(GallerySort.addedDay),
      ),
      gap(),
      _menuHeader('MODO DE VISTA'),
      _switchItem(
        label: 'Por fecha',
        isSelected: () => c.viewMode == GalleryViewMode.byDate,
        onToggle: () => c.setViewMode(GalleryViewMode.byDate),
      ),
      _switchItem(
        label: 'Compacto',
        isSelected: () => c.viewMode == GalleryViewMode.compact,
        onToggle: () => c.setViewMode(GalleryViewMode.compact),
      ),
      gap(),
      _menuHeader('FILTRO'),
      _switchItem(
        label: 'Todos los items',
        isSelected: () => c.filter == GalleryFilter.all,
        onToggle: () => c.setFilter(GalleryFilter.all),
      ),
      _switchItem(
        label: 'Álbum cámara',
        isSelected: () => c.filter == GalleryFilter.camera,
        onToggle: () => c.setFilter(GalleryFilter.camera),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _albumsPopupItems() {
    final c = _galleryController;
    return [
      _menuHeader('OCULTAR'),
      _switchItem(
        label: 'Pines',
        isSelected: () => c.hidePins,
        onToggle: c.toggleHidePins,
      ),
      _switchItem(
        label: 'Álbumes',
        isSelected: () => c.hideAlbums,
        onToggle: c.toggleHideAlbums,
      ),
      _switchItem(
        label: 'Sistema',
        isSelected: () => c.hideSystem,
        onToggle: c.toggleHideSystem,
      ),
      _switchItem(
        label: 'Portadas',
        isSelected: () => c.hideCovers,
        onToggle: c.toggleHideCovers,
      ),
      gap(),
      _menuHeader('MODO DE VISTA'),
      _switchItem(
        label: 'Lista',
        isSelected: () => c.albumsViewMode == AlbumsViewMode.list,
        onToggle: () => c.setAlbumsViewMode(AlbumsViewMode.list),
      ),
      _switchItem(
        label: 'Cuadrícula',
        isSelected: () => c.albumsViewMode == AlbumsViewMode.grid,
        onToggle: () => c.setAlbumsViewMode(AlbumsViewMode.grid),
      ),
    ];
  }

  List<PopupMenuEntry<String>> _collectionsPopupItems() {
    final c = _galleryController;
    return [
      _menuHeader('MODO DE VISTA'),
      _switchItem(
        label: 'Compacto',
        isSelected: () => c.collectionsViewMode == CollectionsViewMode.compact,
        onToggle: () => c.setCollectionsViewMode(CollectionsViewMode.compact),
      ),
      _switchItem(
        label: 'Por grupo',
        isSelected: () =>
            c.collectionsViewMode == CollectionsViewMode.grouped,
        onToggle: () =>
            c.setCollectionsViewMode(CollectionsViewMode.grouped),
      ),
      gap(),
      _menuHeader('ORDEN'),
      _switchItem(
        label: 'A → Z',
        isSelected: () => c.collectionsSort == CollectionsSort.az,
        onToggle: () => c.setCollectionsSort(CollectionsSort.az),
      ),
      _switchItem(
        label: 'Z → A',
        isSelected: () => c.collectionsSort == CollectionsSort.za,
        onToggle: () => c.setCollectionsSort(CollectionsSort.za),
      ),
    ];
  }

  /// Iconos a la derecha de la topbar por screen.
  /// Álbumes: "seleccionar" entra en modo selección múltiple.
  List<Widget>? _selectionActionsFor(int tabIndex) {
    if (tabIndex != 1) return null; // solo Álbumes
    final albums = _galleryController.unpinnedAlbums;
    if (albums.isEmpty) return null;
    return [
      IconButton(
        icon: const Icon(Icons.checklist_rounded),
        tooltip: 'Seleccionar álbumes',
        onPressed: () => _selectAllAlbums(),
      ),
    ];
  }

  void _selectAllAlbums() {
    _selection.selectAll(
      _galleryController.unpinnedAlbums.map((a) => a.path),
    );
  }

  List<Photo> _selectedPhotos() {
    final ids = _selection.ids;
    return _galleryController.photos
        .where((p) => ids.contains(p.id))
        .toList();
  }

  Future<void> _shareSelection() async {
    if (_selection.kind == SelectionKind.albums) {
      await _shareAlbums();
      return;
    }
    final photos = _selectedPhotos();
    if (photos.isEmpty) return;
    _selection.clear();
    await sharePhotos(context, photos);
  }

  /// Comparte un álbum entero: se envían sus fotos.
  Future<void> _shareAlbums() async {
    final albums = _selectedAlbums();
    if (albums.isEmpty) return;
    final photos = [for (final a in albums) ...a.photos];
    if (photos.isEmpty) return;
    _selection.clear();
    await sharePhotos(context, photos);
  }

  List<Album> _selectedAlbums() => _galleryController.albums
      .where((a) => _selection.ids.contains(a.path))
      .toList();

  Future<void> _favoriteSelection() async {
    if (_selection.kind == SelectionKind.albums) return;
    final ids = _selection.ids.toList();
    if (ids.isEmpty) return;
    await _galleryController.toggleFavoritesBatch(ids);
    _selection.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Favoritos actualizados')));
  }

  Future<void> _deleteSelection() async {
    if (_selection.kind == SelectionKind.albums) {
      await _deleteSelectedAlbums();
      return;
    }
    final count = _selection.count;
    final confirmed = await showNConfirmDialog(
      context,
      title: 'Eliminar',
      message: 'Mover $count '
          '${count == 1 ? 'elemento' : 'elementos'} a la papelera?',
      confirmLabel: 'OK',
    );
    if (!confirmed || !mounted) return;
    final ids = _selection.ids.toList();
    await _galleryController.moveToTrashBatch(ids);
    _selection.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$count en la papelera')),
      );
  }

  Future<void> _deleteSelectedAlbums() async {
    final albums = _selectedAlbums();
    if (albums.isEmpty) return;
    final confirmed = await showNConfirmDialog(
      context,
      title: 'Eliminar',
      message: 'Se borrarán ${albums.length} '
          '${albums.length == 1 ? 'álbum' : 'álbumes'} y todas sus fotos. '
          'No se puede deshacer.',
      confirmLabel: 'OK',
    );
    if (!confirmed || !mounted) return;
    for (final album in albums) {
      await _galleryController.deleteAlbum(album.path);
    }
    _selection.clear();
  }

  /// "Más acciones" sobre los álbumes seleccionados: aplica la misma
  /// hoja (nombre, carátula, ocultar) al primer álbum del lote.
  void _moreAlbumActions() {
    final albums = _selectedAlbums();
    if (albums.isEmpty) return;
    showAlbumActionsSheet(
      context,
      controller: _galleryController,
      title: albums.length == 1
          ? albums.first.name
          : '${albums.length} álbumes',
      isPinned: false,
      isHidden: albums.every((a) => a.hidden),
      isSystem: false,
    ).then((action) async {
      if (action == null || !mounted) return;
      for (final album in albums) {
        switch (action) {
          case AlbumAction.togglePin:
            await _galleryController.togglePin('album:${album.path}');
          case AlbumAction.rename:
          case AlbumAction.changeCover:
            // Operan sobre un único álbum: no aplica en lote.
            break;
          case AlbumAction.hide:
            await _galleryController.setAlbumHidden(album.path, true);
          case AlbumAction.unhide:
            await _galleryController.setAlbumHidden(album.path, false);
          case AlbumAction.delete:
            break; // el borrado en lote va por la papelera/confirmación.
        }
      }
      if (mounted) _selection.clear();
    });
  }

  List<PopupMenuEntry<String>> _popupItemsFor(int tabIndex) {
    return switch (tabIndex) {
      1 => _albumsPopupItems(),
      2 => _collectionsPopupItems(),
      _ => _galleryPopupItems(),
    };
  }

  /// Sección base del kit con navegación interna del panel (no `push`).
  /// Sale de [NSettingsScreen.buildNexoraBaseSection]: si el kit añade un
  /// item, el panel desktop lo hereda sin copiar nada.
  NSettingsSection _desktopBaseSection() {
    return NSettingsScreen.buildNexoraBaseSection(
      onAccountTap: () => _openPanelPage('account'),
      onPerformanceTap: () => _openPanelPage('performance'),
      onPersonalizationTap: () => _openPanelPage('personalization'),
      onAboutTap: () => _openPanelPage('about'),
    );
  }

  List<NSettingsSection> _desktopSettingsSections() {
    // Release 26.09.28: solo la base del kit. Sin secciones propias
    // (eran botones muertos; ver nphotos_settings_screen.dart).
    return [_desktopBaseSection()];
  }

  Widget _buildTrailingPanel(BuildContext context) {
    switch (_currentPanel) {
      case 'account':
        return NSidePanel(
          title: 'Cuenta',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NAccountContent(profileData: nPhotosProfileData),
        );
      case 'performance':
        return NSidePanel(
          title: 'Rendimiento',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: const NPerformanceContent(),
        );
      case 'personalization':
        return NSidePanel(
          title: 'Personalización',
          onBack: _backPanel,
          onClose: _toggleSettingsDesktop,
          child: NPersonalizationContent(
            onNavigateToAccent: () => _openPanelPage('accent'),
            experimentalLayout: true,
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
            onRevokePermissionsTap: () =>
                confirmRevokeAllPermissions(context),
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
          child: const NPhotosPermissionsContent(),
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
      GalleryScreen(
        controller: _galleryController,
        selection: _selection,
      ),
      AlbumsScreen(
        controller: _galleryController,
        selection: _selection,
      ),
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

    // La topbar móvil cambia por screen: lupa solo en galería,
    // popup con funciones propias y ajustes solo en colecciones.
    final tabIndex = clampIndex(_selectedIndex, _navItems.length);
    final isGallery = tabIndex == 0;
    final isCollections = tabIndex == 2;

    return ResponsiveLayout(
      mobileLayout: AnimatedBuilder(
        animation: Listenable.merge([_galleryController, _selection]),
        builder: (context, _) {
          // Con selección activa la bottom bar se sustituye por las
          // acciones en lote (compartir, favoritos, eliminar).
          if (_selection.isActive) {
            return Scaffold(
              extendBody: true,
              appBar: NSecondaryTopBar(
                title:
                    '${_selection.count} '
                    '${_selection.count == 1 ? 'seleccionado' : 'seleccionados'}',
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancelar selección',
                    onPressed: _selection.clear,
                  ),
                ],
              ),
              body: IndexedStack(
                index: clampIndex(_selectedIndex, mobileScreens.length),
                children: mobileScreens,
              ),
              bottomNavigationBar: SelectionActionBar(
                selection: _selection,
                onClear: _selection.clear,
                onShare: _shareSelection,
                onToggleFavorite: _favoriteSelection,
                onDelete: _deleteSelection,
                onMore: _selection.kind == SelectionKind.albums
                    ? _moreAlbumActions
                    : null,
              ),
            );
          }
          return NMobileLayout(
          title: 'NPhotos',
          // pages (no body): el drag sobre la BottomBar desplaza las
          // pantallas en vivo con snap. Keep-alive para no reiniciar
          // cada destino al volver a él.
          pages: [
            for (final screen in mobileScreens) _KeepAlivePage(child: screen),
          ],
          currentIndex: tabIndex,
          onNavigationIndexChanged: (i) => setState(() => _selectedIndex = i),
          navigationItems: _navItems,
          onRefresh: _galleryController.refresh,
          onSettingsPressed: isCollections ? _openSettingsMobile : null,
          onSearchChanged: isGallery ? _galleryController.setSearchQuery : null,
          onSearchClosed: isGallery
              ? () => _galleryController.setSearchQuery('')
              : null,
          searchHint: 'Buscar fotos',
          extraPopupMenuItems: _popupItemsFor(tabIndex),
          // Se SUMA a las acciones del kit: no reemplaza el popup ⋮.
          extraActions: _selectionActionsFor(tabIndex),
        );
        },
      ),
      desktopLayout: AnimatedBuilder(
        animation: _galleryController,
        builder: (context, _) => NDesktopLayout(
          body: IndexedStack(
            index: clampIndex(_selectedIndex, desktopScreens.length),
            children: desktopScreens,
          ),
          selectedIndex: clampIndex(_selectedIndex, _sidebarItems.length),
          onDestinationSelected: (i) => setState(() => _selectedIndex = i),
          sidebarItems: _sidebarItems,
          topBarCenter: _DesktopViewControls(controller: _galleryController),
          onSearchChanged: _galleryController.setSearchQuery,
          onSearchClosed: () => _galleryController.setSearchQuery(''),
          searchHint: 'Buscar fotos',
          onSettingsPressed: _toggleSettingsDesktop,
          showSettingsAction: !_settingsOpen,
          trailingPanel: _settingsOpen ? _buildTrailingPanel(context) : null,
        ),
      ),
    );
  }
}

/// Envuelve una página móvil para que el `PageView` del drag no la
/// destruya al salir de pantalla (conserva scroll, columnas y estado).
class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// Controles de vista/orden/filtro centrados en el topbar desktop.
///
/// Equivale a las opciones del popup móvil, renderizadas en el centro.
class _DesktopViewControls extends StatelessWidget {
  final GalleryController controller;

  const _DesktopViewControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.textTheme.bodySmall?.color;

    Widget button({
      required IconData icon,
      required String tooltip,
      required bool active,
      required VoidCallback onPressed,
    }) {
      return IconButton(
        icon: Icon(icon, size: 20, color: active ? accent : muted),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    final byDate = controller.viewMode == GalleryViewMode.byDate;
    final byCapture = controller.sort == GallerySort.captureDay;
    final allItems = controller.filter == GalleryFilter.all;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            icon: byDate ? Icons.calendar_month : Icons.grid_view,
            tooltip: byDate ? 'Vista: por fecha' : 'Vista: compacta',
            active: true,
            onPressed: () => controller.setViewMode(
              byDate ? GalleryViewMode.compact : GalleryViewMode.byDate,
            ),
          ),
          button(
            icon: Icons.swap_vert,
            tooltip: byCapture
                ? 'Orden: día de captura'
                : 'Orden: día de agregación',
            active: !byCapture,
            onPressed: () => controller.setSort(
              byCapture ? GallerySort.addedDay : GallerySort.captureDay,
            ),
          ),
          button(
            icon: allItems ? Icons.filter_alt_outlined : Icons.filter_alt,
            tooltip: allItems ? 'Filtro: todos' : 'Filtro: cámara',
            active: !allItems,
            onPressed: () => controller.setFilter(
              allItems ? GalleryFilter.camera : GalleryFilter.all,
            ),
          ),
        ],
      ),
    );
  }
}
