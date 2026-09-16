import 'package:flutter/material.dart';

import 'design/nexora_theme.dart';
import 'design/nexora_tokens.dart';
import 'src/core.dart';
import 'src/pages/albums_page.dart';
import 'src/pages/downloads_view.dart';
import 'src/pages/favorites_page.dart';
import 'src/pages/photos_view.dart';
import 'src/pages/screenshots_view.dart';
import 'src/pages/secure_folder_page.dart';
import 'src/pages/settings_page.dart';
import 'src/pages/trash_page.dart';
import 'src/pages/videos_page.dart';
import 'src/widgets/photo_grid.dart';
import 'widgets/nphotos_button.dart';
import 'widgets/nphotos_group_selector.dart';
import 'widgets/nphotos_sidebar.dart';
import 'widgets/nphotos_topbar.dart';

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
  NPhotoSection _section = NPhotoSection.photos;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'NPhotos',
        debugShowCheckedModeBanner: false,
        theme: buildNexoraTheme(Brightness.light),
        darkTheme: buildNexoraTheme(Brightness.dark),
        themeMode: mode,
        home: FutureBuilder<StoreController>(
          future: StoreController.instance(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Scaffold(
                backgroundColor: NexoraPalette.dark.background,
                body: Center(
                  child: Text(
                    'Error initializing Rust: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: NexoraPalette.dark.textSecondary),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return NPhotosShell(
              controller: snapshot.data!,
              section: _section,
              onSectionSelected: (s) => setState(() => _section = s),
            );
          },
        ),
      ),
    );
  }
}

/// Estructura NEXORA: Sidebar + TopBar (contexto único) + Content.
class NPhotosShell extends StatefulWidget {
  const NPhotosShell({
    super.key,
    required this.controller,
    required this.section,
    required this.onSectionSelected,
  });

  final StoreController controller;
  final NPhotoSection section;
  final ValueChanged<NPhotoSection> onSectionSelected;

  @override
  State<NPhotosShell> createState() => _NPhotosShellState();
}

class _NPhotosShellState extends State<NPhotosShell> {
  final Set<NPhotoSection> _built = {};
  PhotoGroupBy _groupBy = PhotoGroupBy.none;

  @override
  void initState() {
    super.initState();
    _built.add(widget.section);
    _ensureLoaded(widget.section);
  }

  Widget _pageFor(NPhotoSection section) {
    switch (section) {
      case NPhotoSection.photos:
        return PhotosView(groupBy: _groupBy, onGroupByChanged: _setGroupBy);
      case NPhotoSection.albums:
        return const AlbumsPage();
      case NPhotoSection.favorites:
        return const FavoritesPage();
      case NPhotoSection.videos:
        return const VideosPage();
      case NPhotoSection.screenshots:
        return const ScreenshotsView();
      case NPhotoSection.downloads:
        return const DownloadsView();
      case NPhotoSection.trash:
        return const TrashPage();
      case NPhotoSection.secureFolder:
        return const SecureFolderPage();
      case NPhotoSection.settings:
        return const SettingsPage();
    }
  }

  void _setGroupBy(PhotoGroupBy groupBy) => setState(() => _groupBy = groupBy);

  /// Carga perezosa de datos que no están en el arranque.
  void _ensureLoaded(NPhotoSection section) {
    switch (section) {
      case NPhotoSection.videos:
        if (widget.controller.videos.isEmpty &&
            !widget.controller.videosLoading) {
          widget.controller.refreshVideos();
        }
      case NPhotoSection.trash:
        if (widget.controller.trashItems.isEmpty) {
          widget.controller.refreshTrash();
        }
      case NPhotoSection.secureFolder:
        widget.controller.refreshPinState();
        widget.controller.refreshSecure();
      default:
        break;
    }
  }

  void _select(NPhotoSection section) {
    setState(() {
      _built.add(section);
      widget.onSectionSelected(section);
    });
    _ensureLoaded(section);
  }

  String? _subtitleFor(StoreController controller) {
    final c = controller;
    switch (widget.section) {
      case NPhotoSection.photos:
        final n = c.photos.length;
        return '$n ${n == 1 ? 'photo' : 'photos'}';
      case NPhotoSection.albums:
        final n = c.albums.length;
        return '$n ${n == 1 ? 'album' : 'albums'}';
      case NPhotoSection.favorites:
        final n = c.photos.where((p) => p.isFavorite).length;
        return '$n ${n == 1 ? 'favorite' : 'favorites'}';
      case NPhotoSection.videos:
        final n = c.videos.length;
        return '$n ${n == 1 ? 'clip' : 'clips'}';
      case NPhotoSection.screenshots:
        final n = screenshotsOf(c.photos).length;
        return '$n ${n == 1 ? 'capture' : 'captures'}';
      case NPhotoSection.downloads:
        final n = c.photos.where(downloadedOf).length;
        return '$n ${n == 1 ? 'file' : 'files'} in Downloads';
      case NPhotoSection.trash:
        if (c.trashItems.isEmpty) return 'Empty';
        final n = c.trashItems.length;
        return '$n ${n == 1 ? 'item' : 'items'}';
      case NPhotoSection.secureFolder:
        return c.pinSet ? 'Protected with a PIN' : 'Protect photos with a PIN';
      case NPhotoSection.settings:
        return null;
    }
  }

  bool _searchEnabled() {
    switch (widget.section) {
      case NPhotoSection.photos:
      case NPhotoSection.favorites:
      case NPhotoSection.screenshots:
      case NPhotoSection.downloads:
        return true;
      default:
        return false;
    }
  }

  List<Widget> _actionsFor(StoreController c) {
    switch (widget.section) {
      case NPhotoSection.photos:
        return [
          NPhotosGroupSelector(value: _groupBy, onChanged: _setGroupBy),
          const SizedBox(width: NXSpace.s8),
          NPhotosIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Rescan library',
            onPressed: c.scanAll,
          ),
        ];
      case NPhotoSection.albums:
        return [
          NPhotosIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New album',
            onPressed: _createAlbum,
          ),
        ];
      case NPhotoSection.videos:
        return [
          NPhotosIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Rescan videos',
            onPressed: c.refreshVideos,
          ),
        ];
      case NPhotoSection.trash:
        if (c.trashItems.isEmpty) return const [];
        return [
          NPhotosIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Empty Trash',
            onPressed: _confirmEmptyTrash,
          ),
        ];
      default:
        return const [];
    }
  }

  Future<void> _createAlbum() async {
    final name = await askAlbumNameFromAlbums(context, initial: '');
    if (name == null || name.isEmpty) return;
    await widget.controller.createAlbum(name);
  }

  Future<void> _confirmEmptyTrash() async {
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash'),
        content: Text(
          '${widget.controller.trashItems.length} items will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NXColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = NPhotoSection.values;
    return Scaffold(
      body: Row(
        children: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => NPhotosSidebar(
              current: widget.section,
              onSectionSelected: _select,
              photoCount: widget.controller.photos.length,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) => NPhotosTopBar(
                    title: widget.section.title,
                    subtitle: _subtitleFor(widget.controller),
                    enableSearch: _searchEnabled(),
                    onQueryChanged: (v) => globalSearchQuery.value = v,
                    actions: _actionsFor(widget.controller),
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: widget.section.index,
                    children: [
                      for (final s in sections)
                        _built.contains(s)
                            ? _pageFor(s)
                            : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
