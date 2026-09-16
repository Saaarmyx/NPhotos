import 'package:flutter/material.dart';

import 'design/nexora_theme.dart';
import 'design/nexora_tokens.dart';
import 'src/core.dart';
import 'src/pages/album_view_page.dart';
import 'src/pages/albums_page.dart';
import 'src/pages/downloads_view.dart';
import 'src/pages/favorites_page.dart';
import 'src/pages/photos_view.dart';
import 'src/pages/recently_view.dart';
import 'src/pages/screenshots_view.dart';
import 'src/pages/secure_folder_page.dart';
import 'src/pages/settings_page.dart';
import 'src/pages/trash_page.dart';
import 'src/pages/videos_page.dart';
import 'src/rust/api.dart';
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

/// Estructura conceptual NEXORA: Sidebar + TopBar + Content.
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

  @override
  void initState() {
    super.initState();
    _built.add(widget.section);
  }

  Widget _pageFor(NPhotoSection section) {
    switch (section) {
      case NPhotoSection.photos:
        return const PhotosView();
      case NPhotoSection.recentlyAdded:
        return const RecentlyAddedView();
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

  void _select(NPhotoSection section) {
    setState(() {
      _built.add(section);
      widget.onSectionSelected(section);
    });
  }

  Future<void> _openAlbum(Album album) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumViewPage(album: album),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sections = NPhotoSection.values;
    final isSearchEnabled = switch (widget.section) {
      NPhotoSection.photos ||
      NPhotoSection.recentlyAdded ||
      NPhotoSection.favorites ||
      NPhotoSection.screenshots ||
      NPhotoSection.downloads =>
        true,
      _ => false,
    };

    return Scaffold(
      body: Row(
        children: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => NPhotosSidebar(
              sections: sections,
              current: widget.section,
              onSectionSelected: _select,
              albums: widget.controller.albums,
              onAlbumTap: _openAlbum,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                NPhotosTopBar(
                  title: widget.section.title,
                  enableSearch: isSearchEnabled,
                  onQueryChanged: (v) => globalSearchQuery.value = v,
                  actions: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: appThemeMode,
                      builder: (context, mode, _) => NPhotosThemeToggle(
                        isDark: mode != ThemeMode.light,
                        onToggle: () => appThemeMode.value =
                            mode == ThemeMode.dark
                                ? ThemeMode.light
                                : ThemeMode.dark,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: IndexedStack(
                    index: widget.section.index,
                    children: [
                      for (final s in sections)
                        _built.contains(s) ? _pageFor(s) : const SizedBox.shrink(),
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