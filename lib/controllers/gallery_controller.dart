// lib/controllers/gallery_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/photo.dart';
import '../services/local_store.dart';
import '../services/photo_service.dart';
import '../services/private_vault.dart';

enum GalleryState { initial, permissionDenied, loading, loaded, error }

/// Orden de la galería desde el popup de la topbar.
enum GallerySort { captureDay, addedDay }

/// Modo de vista desde el popup de la topbar.
enum GalleryViewMode { byDate, compact }

/// Filtro de la galería desde el popup de la topbar.
enum GalleryFilter { all, camera }

/// Vista de Álbumes desde su popup: cuadrícula clásica o lista de filas.
enum AlbumsViewMode { grid, list }

/// Vista de Colecciones desde su popup: grilla plana o agrupada por mes.
enum CollectionsViewMode { compact, grouped }

/// Orden alfabético de Colecciones desde su popup.
enum CollectionsSort { az, za }

/// Modelo sencillo para representar un Álbum
class Album {
  final String name;
  final String path;
  final List<Photo> photos;

  /// Ruta de la carátula elegida por el usuario (null = la primera foto).
  final String? customCover;

  /// true si el usuario renombró el álbum.
  final bool renamed;

  /// true si el álbum está oculto en Álbumes.
  final bool hidden;

  Album({
    required this.name,
    required this.path,
    required this.photos,
    this.customCover,
    this.renamed = false,
    this.hidden = false,
  });

  /// Carátula efectiva: la elegida o, si no, la primera foto.
  Photo get coverPhoto {
    if (customCover != null) {
      final match = photos.where((p) => p.path == customCover);
      if (match.isNotEmpty) return match.first;
    }
    return photos.first;
  }
}

/// Foto en la papelera con su fecha de eliminación.
class TrashedPhoto {
  final Photo photo;
  final DateTime trashedAt;

  const TrashedPhoto({required this.photo, required this.trashedAt});
}

/// Pin de la pantalla Álbumes (máx 4).
///
/// [id] es `album:<dirPath>` para carpetas reales o `__videos__`,
/// `__trash__`, `__favorites__` para listas sintéticas.
class AlbumPin {
  final String id;
  final String title;
  final IconData icon;
  final Photo? cover;
  final int count;
  final Color tint;

  const AlbumPin({
    required this.id,
    required this.title,
    required this.icon,
    this.cover,
    required this.count,
    required this.tint,
  });

  bool get isAlbum => id.startsWith('album:');
  String get albumPath => id.substring('album:'.length);
}

class GalleryController extends ChangeNotifier {
  final PhotoService _photoService;
  LocalStore? _store;

  /// Directorio de la carpeta privada. Solo para tests; en producción
  /// se resuelve vía `path_provider` (soporte de la app).
  final Directory? privateDirOverride;

  GalleryController({PhotoService? photoService, this._store, this.privateDirOverride})
    : _photoService = photoService ?? PhotoService();

  GalleryState _state = GalleryState.initial;
  GalleryState get state => _state;

  List<Photo> _photos = [];
  List<Photo> get photos => _photos;

  List<TrashedPhoto> _trash = [];
  List<TrashedPhoto> get trash => List.unmodifiable(_trash);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Preferencias de la topbar (popup ⋮): orden, vista y filtro + búsqueda.
  GallerySort _sort = GallerySort.captureDay;
  GallerySort get sort => _sort;

  GalleryViewMode _viewMode = GalleryViewMode.byDate;
  GalleryViewMode get viewMode => _viewMode;

  GalleryFilter _filter = GalleryFilter.all;
  GalleryFilter get filter => _filter;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSort(GallerySort value) {
    if (_sort == value) return;
    _sort = value;
    notifyListeners();
  }

  void setViewMode(GalleryViewMode value) {
    if (_viewMode == value) return;
    _viewMode = value;
    notifyListeners();
  }

  void setFilter(GalleryFilter value) {
    if (_filter == value) return;
    _filter = value;
    _invalidateCaches();
    notifyListeners();
  }

  void setSearchQuery(String value) {
    final q = value.trim().toLowerCase();
    if (_searchQuery == q) return;
    _searchQuery = q;
    notifyListeners();
  }

  // Preferencias de Álbumes (popup propio): vista + secciones ocultas.
  AlbumsViewMode _albumsViewMode = AlbumsViewMode.grid;
  AlbumsViewMode get albumsViewMode => _albumsViewMode;

  bool _hidePins = false;
  bool get hidePins => _hidePins;

  bool _hideAlbums = false;
  bool get hideAlbums => _hideAlbums;

  /// Listas del sistema (Favoritos, Vídeos, Papelera no pineadas):
  /// otra categoría, ocultable por separado.
  bool _hideSystem = false;
  bool get hideSystem => _hideSystem;

  bool _hideCovers = false;
  bool get hideCovers => _hideCovers;

  void setAlbumsViewMode(AlbumsViewMode value) {
    if (_albumsViewMode == value) return;
    _albumsViewMode = value;
    notifyListeners();
  }

  void toggleHidePins() {
    _hidePins = !_hidePins;
    notifyListeners();
  }

  void toggleHideAlbums() {
    _hideAlbums = !_hideAlbums;
    notifyListeners();
  }

  void toggleHideSystem() {
    _hideSystem = !_hideSystem;
    notifyListeners();
  }

  void toggleHideCovers() {
    _hideCovers = !_hideCovers;
    notifyListeners();
  }

  // Preferencias de Colecciones (popup propio): vista + orden A-Z.
  CollectionsViewMode _collectionsViewMode = CollectionsViewMode.compact;
  CollectionsViewMode get collectionsViewMode => _collectionsViewMode;

  CollectionsSort _collectionsSort = CollectionsSort.az;
  CollectionsSort get collectionsSort => _collectionsSort;

  void setCollectionsViewMode(CollectionsViewMode value) {
    if (_collectionsViewMode == value) return;
    _collectionsViewMode = value;
    notifyListeners();
  }

  void setCollectionsSort(CollectionsSort value) {
    if (_collectionsSort == value) return;
    _collectionsSort = value;
    notifyListeners();
  }

  /// Ordena una lista por título según [collectionsSort] (A→Z o Z→A).
  List<Photo> applyNameSort(List<Photo> photos) {
    final list = List<Photo>.of(photos);
    list.sort((a, b) {
      final cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return _collectionsSort == CollectionsSort.az ? cmp : -cmp;
    });
    return list;
  }

  DateTime _sortKey(Photo p) =>
      _sort == GallerySort.captureDay ? p.dateCreated : p.dateModified;

  /// Clave de día (año/mes/día) sobre la fecha de orden activa.
  DateTime dayKeyOf(Photo p) {
    final d = _sortKey(p);
    return DateTime(d.year, d.month, d.day);
  }

  /// Fotos visibles agrupadas por día (orden desc). Para modo "Por fecha".
  Map<DateTime, List<Photo>> get visibleGroups {
    final groups = <DateTime, List<Photo>>{};
    for (final p in visiblePhotos) {
      groups.putIfAbsent(dayKeyOf(p), () => []).add(p);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: groups[k]!};
  }

  /// Fotos tras aplicar filtro (todos / cámara), búsqueda y orden.
  /// Es lo que pinta la grilla principal.
  List<Photo> get visiblePhotos {
    Iterable<Photo> list = _photos;
    if (_filter == GalleryFilter.camera) {
      final camera = cameraAlbum;
      if (camera == null) return const [];
      final ids = {for (final p in camera.photos) p.id};
      list = list.where((p) => ids.contains(p.id));
    }
    if (_searchQuery.isNotEmpty) {
      list = list.where(
        (p) =>
            p.title.toLowerCase().contains(_searchQuery) ||
            p.path.toLowerCase().contains(_searchQuery),
      );
    }
    final sorted = list.toList()
      ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));
    return sorted;
  }

  // Recarga dinámica: observación del disco + anti-solape de escaneos.
  final List<StreamSubscription<FileSystemEvent>> _watchers = [];
  Timer? _watchDebounce;
  Duration _watchDebounceDuration = const Duration(seconds: 2);
  bool _watching = false;
  bool _fetching = false;
  bool _disposed = false;

  // Derivados cacheados: se recalculan solo cuando cambian los datos.
  List<Photo>? _cachedFavorites;
  List<Album>? _cachedAlbums;
  List<Photo>? _cachedVideos;
  List<Photo>? _cachedRecentWeek;
  List<Photo>? _cachedDocuments;
  List<Photo>? _cachedHd;
  List<Photo>? _cachedPeople;
  List<Photo>? _cachedLocated;

  void _invalidateCaches() {
    _cachedFavorites = null;
    _cachedAlbums = null;
    _cachedVideos = null;
    _cachedRecentWeek = null;
    _cachedDocuments = null;
    _cachedHd = null;
    _cachedPeople = null;
    _cachedLocated = null;
  }

  /// Retorna las fotos marcadas como favoritas
  List<Photo> get favoritePhotos =>
      _cachedFavorites ??= _photos.where((p) => p.isFavorite).toList();

  /// Solo vídeos (por extensión). Vive pineado en Álbumes.
  List<Photo> get videos =>
      _cachedVideos ??= _photos.where((p) => p.isVideo).toList();

  /// Retorna las fotos agrupadas por carpeta (Álbumes)
  List<Album> get albums {
    if (_cachedAlbums != null) return _cachedAlbums!;
    final Map<String, List<Photo>> albumMap = {};

    for (final photo in _photos) {
      final parentDir = p.dirname(photo.path);
      albumMap.putIfAbsent(parentDir, () => []).add(photo);
    }

    _cachedAlbums = albumMap.entries.map((entry) {
      final prefs = _albumPrefs[entry.key] ?? const AlbumPrefs();
      return Album(
        name: prefs.name ?? p.basename(entry.key),
        path: entry.key,
        photos: entry.value,
        customCover: prefs.cover,
        renamed: prefs.name != null,
        hidden: prefs.hidden,
      );
    }).toList();
    return _cachedAlbums!;
  }

  /// Nombres de carpeta que resuelven el pineado "Cámara".
  static const cameraFolderNames = {'camera', 'cámara', 'camara', 'dcim'};

  /// Nombres de carpeta que resuelven el pineado "Capturas".
  static const screenshotsFolderNames = {
    'screenshots',
    'screenshot',
    'capturas',
    'captura',
    'captures',
    'screen shots',
  };

  /// Busca el álbum cuya carpeta coincide con [names] (insensible a
  /// mayúsculas y tildes básicas). Null si no hay fotos de esa carpeta.
  Album? findAlbumByFolderNames(Set<String> names) {
    for (final album in albums) {
      final folder = p.basename(album.path).toLowerCase();
      if (names.contains(folder)) return album;
    }
    return null;
  }

  /// Álbum pineado "Cámara" (carpeta DCIM/Camera, etc.).
  Album? get cameraAlbum => findAlbumByFolderNames(cameraFolderNames);

  /// Álbum pineado "Capturas" (carpeta Screenshots/Capturas, etc.).
  Album? get screenshotsAlbum =>
      findAlbumByFolderNames(screenshotsFolderNames);

  /// Rutas de carpetas pineadas (para excluirlas de la parrilla general
  /// de álbumes y no duplicarlas). Los pines sintéticos no aportan ruta.
  Set<String> get pinnedAlbumPaths => {
    for (final id in _pinnedIds)
      if (id.startsWith('album:')) id.substring('album:'.length),
  };

  /// Álbumes visibles y sin pinear (la parrilla de Álbumes).
  List<Album> get unpinnedAlbums => albums
      .where((a) => !a.hidden && !pinnedAlbumPaths.contains(a.path))
      .toList();

  /// Máximo de pines en la pantalla Álbumes.
  static const maxPins = 4;

  static const String videosPinId = '__videos__';
  static const String trashPinId = '__trash__';
  static const String favoritesPinId = '__favorites__';

  List<String> _pinnedIds = [];
  List<String> get pinnedIds => List.unmodifiable(_pinnedIds);

  bool isPinned(String id) => _pinnedIds.contains(id);

  /// Pines resueltos en orden, recortados a [maxPins].
  /// Los ids huérfanos (carpeta que ya no existe) se omiten aquí
  /// y se podan en la siguiente carga.
  List<AlbumPin> get pins {
    final resolved = <AlbumPin>[];
    for (final id in _pinnedIds) {
      final pin = _resolvePin(id);
      if (pin != null) resolved.add(pin);
      if (resolved.length >= maxPins) break;
    }
    return resolved;
  }

  AlbumPin? _resolvePin(String id) {
    switch (id) {
      case videosPinId:
        final vids = videos;
        return AlbumPin(
          id: id,
          title: 'Vídeos',
          icon: Icons.videocam_outlined,
          cover: vids.isEmpty ? null : vids.first,
          count: vids.length,
          tint: Colors.red,
        );
      case trashPinId:
        return AlbumPin(
          id: id,
          title: 'Papelera',
          icon: Icons.delete_outline,
          cover: _trash.isEmpty ? null : _trash.first.photo,
          count: _trash.length,
          tint: Colors.grey,
        );
      case favoritesPinId:
        final favs = favoritePhotos;
        return AlbumPin(
          id: id,
          title: 'Favoritos',
          icon: Icons.favorite_border,
          cover: favs.isEmpty ? null : favs.first,
          count: favs.length,
          tint: Colors.pink,
        );
    }
    if (id.startsWith('album:')) {
      final path = id.substring('album:'.length);
      for (final album in albums) {
        if (album.path == path) {
          final isCamera = cameraAlbum?.path == path;
          final isScreenshots = screenshotsAlbum?.path == path;
          return AlbumPin(
            id: id,
            title: isCamera
                ? 'Cámara'
                : isScreenshots
                ? 'Capturas'
                : album.name,
            icon: isCamera
                ? Icons.photo_camera_outlined
                : isScreenshots
                ? Icons.screenshot_monitor_outlined
                : Icons.photo_album_outlined,
            cover: album.photos.isEmpty ? null : album.coverPhoto,
            count: album.photos.length,
            tint: isCamera
                ? Colors.blue
                : isScreenshots
                ? Colors.purple
                : Colors.teal,
          );
        }
      }
    }
    return null;
  }

  // ─── Personalización de álbumes (nombre, carátula, visibilidad) ───

  Map<String, AlbumPrefs> _albumPrefs = {};
  AlbumPrefs prefsFor(String path) =>
      _albumPrefs[path] ?? const AlbumPrefs();

  /// Álbumes ocultos (colección "Álbumes ocultos").
  List<Album> get hiddenAlbums =>
      albums.where((a) => prefsFor(a.path).hidden).toList();

  /// Álbumes visibles: la parrilla y los pines excluyen los ocultos.
  List<Album> get visibleAlbums =>
      albums.where((a) => !prefsFor(a.path).hidden).toList();

  Future<void> _loadAlbumPrefs() async {
    final store = _store;
    if (store == null) return;
    try {
      _albumPrefs = store.albumPrefs();
    } catch (e) {
      debugPrint('No se pudieron cargar las preferencias de álbumes: $e');
      _albumPrefs = {};
    }
  }

  Future<void> _persistAlbumPrefs() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.saveAlbumPrefs(_albumPrefs);
    } catch (e) {
      debugPrint('No se pudieron guardar las preferencias de álbumes: $e');
    }
  }

  /// Renombra el álbum en disco (carpeta) y guarda el nombre.
  /// Si el sistema no permite renombrar, cae a un alias local.
  Future<bool> renameAlbum(String path, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return false;
    final album = albums.where((a) => a.path == path).firstOrNull;
    if (album == null) return false;
    if (p.basename(album.name) == name) return true;
    try {
      final dir = Directory(path);
      final parent = dir.parent.path;
      final target = Directory(p.join(parent, name));
      if (await target.exists()) return false; // ya existe: no pisa.
      await dir.rename(target.path);
    } catch (e) {
      debugPrint('No se pudo renombrar la carpeta $path: $e');
      // Alias local: la app lo refleja aunque el FS no colabore.
    }
    _albumPrefs = {
      ..._albumPrefs,
      path: prefsFor(path).copyWith(name: name),
    };
    _invalidateCaches();
    notifyListeners();
    await _persistAlbumPrefs();
    // La ruta pudo cambiar: re-escanea para reflejar el nuevo nombre.
    await fetchPhotos(silent: true);
    return true;
  }

  /// Fija una carátula del propio álbum (path de una foto suya).
  Future<void> setAlbumCover(String path, String? coverPath) async {
    _albumPrefs = {
      ..._albumPrefs,
      path: prefsFor(
        path,
      ).copyWith(cover: coverPath, clearCover: coverPath == null),
    };
    _invalidateCaches();
    notifyListeners();
    await _persistAlbumPrefs();
  }

  /// Oculta o muestra un álbum (colección Álbumes ocultos).
  Future<void> setAlbumHidden(String path, bool hidden) async {
    _albumPrefs = {
      ..._albumPrefs,
      path: prefsFor(path).copyWith(hidden: hidden),
    };
    _invalidateCaches();
    notifyListeners();
    await _persistAlbumPrefs();
  }

  /// Elimina el álbum: borra su carpeta del disco.
  /// Retorna false si no se pudo (permisos, carpeta con subcarpetas).
  Future<bool> deleteAlbum(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('No se pudo eliminar el álbum $path: $e');
      return false;
    }
    _albumPrefs = {..._albumPrefs}..remove(path);
    _pinnedIds = _pinnedIds.where((id) => id != 'album:$path').toList();
    _invalidateCaches();
    notifyListeners();
    await _persistAlbumPrefs();
    await _persistPins();
    // Re-escanea: la carpeta ya no existe en disco.
    await fetchPhotos(silent: true);
    return true;
  }

  /// Fija o quita un pin. Retorna false si ya hay [maxPins] fijados.
  Future<bool> togglePin(String id) async {
    if (_pinnedIds.contains(id)) {
      _pinnedIds = _pinnedIds.where((p) => p != id).toList();
    } else {
      if (pins.length >= maxPins) return false;
      _pinnedIds = [..._pinnedIds, id];
    }
    notifyListeners();
    await _persistPins();
    return true;
  }

  Future<void> _persistPins() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.savePinnedIds(_pinnedIds);
    } catch (e) {
      debugPrint('No se pudo guardar pines: $e');
    }
  }

  /// Siembra los defaults (cámara y capturas) la primera vez; después
  /// manda lo guardado por el usuario. Migra instalaciones con los
  /// defaults antiguos intactos (cámara, capturas, vídeos, papelera).
  Future<void> _loadPins() async {
    final store = _store;
    if (store == null) {
      _pinnedIds = _defaultPins();
      return;
    }
    try {
      if (!store.hasPins()) {
        _pinnedIds = _defaultPins();
        await store.savePinnedIds(_pinnedIds);
      } else {
        final stored = store.pinnedIds().take(maxPins).toList();
        if (_isLegacyDefaults(stored)) {
          _pinnedIds = _defaultPins();
          await store.savePinnedIds(_pinnedIds);
        } else {
          _pinnedIds = stored;
        }
      }
    } catch (e) {
      debugPrint('No se pudieron cargar pines: $e');
      _pinnedIds = _defaultPins();
    }
  }

  bool _isLegacyDefaults(List<String> stored) {
    final a = stored.toSet();
    final b = _legacyDefaultPins().toSet();
    return a.length == b.length && a.containsAll(b);
  }

  /// Primera instalación: 2 pines, Cámara y Capturas.
  ///
  /// Si las carpetas con esos nombres no existen (típico en escritorio o
  /// con DCIM plano), cae a los dos álbumes más grandes para que el
  /// usuario siempre vea 2 pines y no una pantalla vacía.
  List<String> _defaultPins() {
    final used = <String>{};
    final defaults = <String>[];

    void addFirst(Iterable<Album> candidates) {
      for (final album in candidates) {
        if (used.contains(album.path)) continue;
        used.add(album.path);
        defaults.add('album:${album.path}');
        return;
      }
    }

    if (cameraAlbum != null) {
      used.add(cameraAlbum!.path);
      defaults.add('album:${cameraAlbum!.path}');
    }
    if (screenshotsAlbum != null) {
      used.add(screenshotsAlbum!.path);
      defaults.add('album:${screenshotsAlbum!.path}');
    }
    // Fallback: los 2 álbumes con más fotos.
    if (defaults.length < 2) {
      addFirst(_albumsBySize());
    }
    if (defaults.length < 2) {
      addFirst(_albumsBySize());
    }
    return defaults.take(maxPins).toList();
  }

  /// Álbumes ordenados por cantidad de fotos (mayor primero).
  List<Album> _albumsBySize() {
    final list = List<Album>.of(albums)
      ..sort((a, b) => b.photos.length.compareTo(a.photos.length));
    return list;
  }

  /// Defaults antiguos (cámara, capturas, vídeos, papelera) para migrar
  /// instalaciones que nunca personalizaron sus pines.
  List<String> _legacyDefaultPins() {
    final defaults = <String>[];
    if (cameraAlbum != null) defaults.add('album:${cameraAlbum!.path}');
    if (screenshotsAlbum != null) {
      defaults.add('album:${screenshotsAlbum!.path}');
    }
    defaults.add(videosPinId);
    defaults.add(trashPinId);
    if (defaults.length < 2) {
      for (final album in _albumsBySize()) {
        if (defaults.contains('album:${album.path}')) continue;
        defaults.add('album:${album.path}');
        if (defaults.length >= 2) break;
      }
    }
    return defaults.take(maxPins).toList();
  }

  /// "Lugares": fotos agrupadas por carpeta de origen (sin metadatos GPS
  /// en el modelo, la carpeta es la única señal de procedencia real).
  /// Ordenadas por cantidad descendente.
  Map<String, List<Photo>> get placesGroups {
    final groups = <String, List<Photo>>{};
    for (final photo in _photos) {
      final folder = p.basename(p.dirname(photo.path));
      groups.putIfAbsent(folder, () => []).add(photo);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(entries);
  }

  /// Añadidos recientemente: ventana máxima de hoy hacia 1 semana atrás,
  /// ordenados por creación descendente.
  static const recentWindow = Duration(days: 7);

  List<Photo> get recentWeek {
    if (_cachedRecentWeek != null) return _cachedRecentWeek!;
    final cutoff = DateTime.now().subtract(recentWindow);
    final list = _photos.where((p) => !p.dateCreated.isBefore(cutoff)).toList()
      ..sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return _cachedRecentWeek = list;
  }

  /// Carpetas que resuelven la colección "Documentos".
  static const documentFolderNames = {
    'documents',
    'documentos',
    'docs',
    'document',
    'documento',
    'scans',
    'scan',
    'escaneos',
    'escaneados',
  };

  /// Documentos: fotos en carpetas de documentos/escaneos o con
  /// 'scan'/'doc' en el nombre.
  List<Photo> get documentPhotos {
    if (_cachedDocuments != null) return _cachedDocuments!;
    final list = _photos.where((photo) {
      final folder = p.basename(p.dirname(photo.path)).toLowerCase();
      if (documentFolderNames.contains(folder)) return true;
      final name = photo.title.toLowerCase();
      return name.contains('scan') || name.contains('doc_');
    }).toList()
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return _cachedDocuments = list;
  }

  /// Umbral de la colección "Alta definición": 12 MP o ancho 4000 px.
  /// (El badge HD del tile sigue exigiendo 50 MP a propósito.)
  static const double hdMinMegapixels = 12.0;
  static const int hdMinWidth = 4000;

  /// Alta definición: fotos con dimensiones conocidas sobre el umbral.
  List<Photo> get hdPhotos {
    if (_cachedHd != null) return _cachedHd!;
    final list = _photos.where((photo) {
      if (photo.isVideo) return false;
      final mp = photo.megapixels;
      if (mp != null && mp >= hdMinMegapixels) return true;
      return (photo.width ?? 0) >= hdMinWidth;
    }).toList()
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return _cachedHd = list;
  }

  /// Personas v1 (heurística honesta): selfies y cámara frontal.
  /// El subtítulo de la colección lo declara; el agrupado por rostros
  /// real (ML) queda como siguiente paso.
  List<Photo> get peoplePhotos {
    if (_cachedPeople != null) return _cachedPeople!;
    final list = _photos.where((photo) => photo.isSelfie).toList()
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return _cachedPeople = list;
  }

  /// Fotos con GPS EXIF válido.
  List<Photo> get photosWithLocation {
    if (_cachedLocated != null) return _cachedLocated!;
    final list = _photos.where((photo) => photo.hasLocation).toList()
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return _cachedLocated = list;
  }

  /// Fotos con ubicación agrupadas por celda (~1 km, 2 decimales),
  /// ordenadas por cantidad descendente. Clave legible: coordenadas.
  Map<String, List<Photo>> get locationGroups {
    final groups = <String, List<Photo>>{};
    for (final photo in photosWithLocation) {
      final key =
          '${photo.latitude!.toStringAsFixed(2)}, '
          '${photo.longitude!.toStringAsFixed(2)}';
      groups.putIfAbsent(key, () => []).add(photo);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    return Map.fromEntries(entries);
  }

  // ---- Carpeta privada ----

  List<Photo> _private = [];
  List<Photo> get privatePhotos => List.unmodifiable(_private);

  Future<Directory> _vaultDir() async {
    if (privateDirOverride != null) return privateDirOverride!;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'private'));
  }

  /// Carga la bóveda (archivos movidos fuera de las raíces escaneadas).
  Future<void> loadPrivate() async {
    try {
      final vault = PrivateVault(await _vaultDir());
      final files = await vault.files();
      final service = PhotoService(
        roots: [vault.dir],
        // La bóveda no se observa: es pequeña y se recarga tras cada
        // movimiento.
      );
      final scanned = await service.loadPhotos();
      final byPath = {for (final s in scanned) s.path: s};
      _private = [
        for (final file in files)
          byPath[file.path] ??
              Photo(
                id: file.path,
                path: file.path,
                title: p.basename(file.path),
                dateCreated: DateTime.now(),
                dateModified: DateTime.now(),
                sizeInBytes: 0,
              ),
      ]..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    } catch (e) {
      debugPrint('No se pudo cargar la carpeta privada: $e');
      _private = [];
    }
  }

  /// Mueve una foto de la galería a la carpeta privada (desaparece de
  /// galería, álbumes y colecciones). Conserva el favorito.
  Future<void> moveToPrivate(String photoId) async {
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index == -1) return;
    final photo = _photos[index];
    try {
      final vault = PrivateVault(await _vaultDir());
      final destPath = await vault.moveIn(File(photo.path));
      _photos.removeAt(index);
      final moved = photo.copyWith(id: destPath, path: destPath);
      _private = [..._private, moved]
        ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
      final store = _store;
      if (store != null) {
        final origins = store.privateOrigins();
        origins[destPath] = p.dirname(photo.path);
        await store.savePrivateOrigins(origins);
        if (photo.isFavorite) {
          final favs = store.favoriteIds()..remove(photo.id);
          favs.add(destPath);
          await store.saveFavoriteIds(favs);
        }
      }
      _invalidateCaches();
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo mover a privada ${photo.path}: $e');
    }
  }

  /// Devuelve una foto privada a su carpeta original.
  Future<void> restoreFromPrivate(String photoId) async {
    final index = _private.indexWhere((p) => p.id == photoId);
    if (index == -1) return;
    final photo = _private[index];
    try {
      final vault = PrivateVault(await _vaultDir());
      final origins = _store?.privateOrigins() ?? {};
      final originDir = origins[photo.path];
      final Directory targetDir;
      if (originDir != null) {
        targetDir = Directory(originDir);
      } else {
        final roots = await _photoService.existingRoots();
        if (roots.isEmpty) return;
        targetDir = roots.first;
      }
      final restoredPath = await vault.moveOut(photo.path, targetDir);
      _private = _private.where((p) => p.id != photoId).toList();
      final restored = photo.copyWith(id: restoredPath, path: restoredPath);
      _photos = [..._photos, restored]
        ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
      if (_store != null) {
        final next = _store!.privateOrigins()..remove(photo.path);
        await _store!.savePrivateOrigins(next);
      }
      _invalidateCaches();
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo restaurar ${photo.path}: $e');
    }
  }

  /// Fotos recién insertadas por la última actualización incremental.
  /// La UI lo usa para animar solo esas celdas (sin parpadeo global).
  Set<String> _lastInsertedIds = {};
  Set<String> get lastInsertedIds => _lastInsertedIds;

  /// Hidrata la grilla desde el snapshot local para apertura en ~0ms.
  /// No toca el estado de carga: si hay caché, pasa directo a loaded.
  Future<void> hydrateFromCache() async {
    if (_photos.isNotEmpty || _state == GalleryState.loaded) return;
    try {
      _store ??= await LocalStore.load();
    } catch (_) {
      return;
    }
    final snapshot = _store!.loadSnapshot();
    if (snapshot.isEmpty) return;
    final favoriteIds = _store!.favoriteIds();
    final trashedAt = _store!.trashedAt();
    final cached = <Photo>[];
    for (final row in snapshot) {
      final path = row['path'] as String;
      if (trashedAt.containsKey(path)) continue;
      cached.add(
        Photo(
          id: path,
          path: path,
          title: path.split(Platform.pathSeparator).last,
          dateCreated: DateTime.fromMillisecondsSinceEpoch(
            row['modified'] as int,
          ),
          dateModified: DateTime.fromMillisecondsSinceEpoch(
            row['modified'] as int,
          ),
          sizeInBytes: 0,
          isFavorite: favoriteIds.contains(path),
          isVideo: PhotoService.videoExtensions.any(
            (ext) => path.toLowerCase().endsWith(ext),
          ),
        ),
      );
    }
    if (cached.isEmpty) return;
    cached.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    _photos = cached;
    _invalidateCaches();
    _state = GalleryState.loaded;
    notifyListeners();
  }

  Future<void> fetchPhotos({bool silent = false}) async {
    // Anti-solape: el watcher, el pull-to-refresh y el resume pueden
    // pedir recargas a la vez; solo un escaneo corre al mismo tiempo.
    if (_fetching) return;
    _fetching = true;
    // Carga silenciosa: si ya hay datos, no se emite loading para evitar
    // pantallas de carga repetitivas y parpadeos.
    final bool showLoading = !silent || _photos.isEmpty;
    if (showLoading) {
      _state = GalleryState.loading;
      _errorMessage = null;
      notifyListeners();
    }

    if (Platform.isAndroid) {
      final hasPermission = await _requestAndroidPermissions();
      if (!hasPermission) {
        _state = GalleryState.permissionDenied;
        _fetching = false;
        notifyListeners();
        return;
      }
    }

    try {
      // El store es opcional en memoria si la plataforma no lo soporta
      // (p. ej. en tests sin plugin): sin persistencia la app sigue viva.
      try {
        _store ??= await LocalStore.load();
      } catch (e) {
        debugPrint('LocalStore no disponible, modo memoria: $e');
        _store = null;
      }

      final loaded = await _photoService.loadPhotos();
      final favoriteIds = _store?.favoriteIds() ?? {};
      final trashedAt = _store?.trashedAt() ?? {};

      final nextPhotos = <Photo>[];
      final nextTrash = <TrashedPhoto>[];
      for (final photo in loaded) {
        final withFavorite = favoriteIds.contains(photo.id)
            ? photo.copyWith(isFavorite: true)
            : photo;
        final trashed = trashedAt[photo.id];
        if (trashed != null) {
          nextTrash.add(TrashedPhoto(photo: withFavorite, trashedAt: trashed));
        } else {
          nextPhotos.add(withFavorite);
        }
      }

      if (silent && _photos.isNotEmpty) {
        // Actualización incremental: inserta lo nuevo al inicio sin
        // recargar ni parpadear. Solo se notifica una vez.
        _lastInsertedIds = _applyIncrementalUpdate(nextPhotos, nextTrash);
      } else {
        _photos = nextPhotos;
        _trash = nextTrash;
        _lastInsertedIds = {};
        _invalidateCaches();
      }

      await _pruneStaleRecords(
        loaded.map((p) => p.id).toSet(),
        {for (final photo in nextPhotos) p.dirname(photo.path)},
      );
      await _loadPins();
      await _loadAlbumPrefs();
      await loadPrivate();
      await _saveSnapshot(nextPhotos);
      _state = GalleryState.loaded;
    } catch (e) {
      _errorMessage = 'Error al cargar las fotos: $e';
      _state = GalleryState.error;
    } finally {
      _fetching = false;
      notifyListeners();
    }
  }

  /// Observa las carpetas de origen y recarga sola cuando aparece, se
  /// mueve o se borra un archivo. Con debounce para no escanear por cada
  /// evento en ráfagas (p. ej. descargas múltiples o ráfagas de cámara).
  /// Idempotente: llamar dos veces no duplica observadores.
  Future<void> startWatching({
    Duration debounce = const Duration(seconds: 2),
  }) async {
    if (_watching || _disposed) return;
    _watching = true;
    _watchDebounceDuration = debounce;
    try {
      final roots = await _photoService.existingRoots();
      if (_disposed) return;
      for (final dir in roots) {
        try {
          _watchers.add(
            dir.watch(recursive: true).listen(
              _onWatchEvent,
              onError: (Object e) =>
                  debugPrint('Watch error en ${dir.path}: $e'),
            ),
          );
        } catch (e) {
          debugPrint('No se pudo observar ${dir.path}: $e');
        }
      }
    } catch (e) {
      debugPrint('startWatching falló: $e');
    }
  }

  void _onWatchEvent(FileSystemEvent event) {
    if (_disposed) return;
    _watchDebounce?.cancel();
    _watchDebounce = Timer(_watchDebounceDuration, () {
      if (!_disposed) fetchPhotos(silent: true);
    });
  }

  /// Recarga inmediata (pull-to-refresh, botón, resume).
  Future<void> refresh() => fetchPhotos();

  /// Recarga silenciosa de segundo plano: nunca muestra loading si ya hay
  /// datos; inserta lo nuevo al inicio con animación sutil en la UI.
  Future<void> refreshSilent() => fetchPhotos(silent: true);

  /// Diferencia [next] contra el estado actual y lo fusiona.
  /// Retorna los ids nuevos (para animar su inserción al inicio).
  Set<String> _applyIncrementalUpdate(
    List<Photo> next,
    List<TrashedPhoto> nextTrash,
  ) {
    final currentIds = {for (final p in _photos) p.id};
    final nextIds = {for (final p in next) p.id};
    final inserted = nextIds.difference(currentIds);

    if (inserted.isEmpty && next.length == _photos.length) {
      // Sin altas ni bajas: actualiza metadatos in-place (favoritos, etc).
      final byId = {for (final p in next) p.id: p};
      var changed = false;
      for (var i = 0; i < _photos.length; i++) {
        final updated = byId[_photos[i].id];
        if (updated != null &&
            (updated.isFavorite != _photos[i].isFavorite ||
                updated.dateModified != _photos[i].dateModified)) {
          _photos[i] = updated;
          changed = true;
        }
      }
      _trash = nextTrash;
      if (changed) {
        _invalidateCaches();
        notifyListeners();
      }
      return const {};
    }

    _photos = next;
    _trash = nextTrash;
    _invalidateCaches();
    notifyListeners();
    return inserted;
  }

  Future<void> _saveSnapshot(List<Photo> photos) async {
    final store = _store;
    if (store == null) return;
    try {
      await store.saveSnapshot([
        for (final p in photos.take(500))
          {'path': p.path, 'modified': p.dateModified.millisecondsSinceEpoch},
      ]);
    } catch (e) {
      debugPrint('No se pudo guardar snapshot: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _watchDebounce?.cancel();
    for (final sub in _watchers) {
      sub.cancel();
    }
    _watchers.clear();
    super.dispose();
  }

  /// Elimina registros de favoritos/papelera/pines de archivos que ya
  /// no existen.
  Future<void> _pruneStaleRecords(
    Set<String> knownIds,
    Set<String> knownAlbumPaths,
  ) async {
    final store = _store;
    if (store == null) return;

    final favorites = store.favoriteIds();
    final prunedFavorites = favorites.intersection(knownIds);
    if (prunedFavorites.length != favorites.length) {
      await store.saveFavoriteIds(prunedFavorites);
    }

    final trashed = store.trashedAt();
    trashed.removeWhere((id, _) => !knownIds.contains(id));
    if (trashed.length != store.trashedAt().length) {
      await store.saveTrashed(trashed);
    }

    if (store.hasPins()) {
      final pins = store.pinnedIds();
      final pruned = pins
          .where(
            (id) =>
                !id.startsWith('album:') ||
                knownAlbumPaths.contains(id.substring('album:'.length)),
          )
          .take(maxPins)
          .toList();
      if (pruned.length != pins.length) {
        await store.savePinnedIds(pruned);
        _pinnedIds = pruned;
      }
    }
  }

  Future<void> _persistFavorites() async {
    final store = _store;
    if (store == null) return;
    await store.saveFavoriteIds({
      for (final photo in _photos)
        if (photo.isFavorite) photo.id,
      for (final trashed in _trash)
        if (trashed.photo.isFavorite) trashed.photo.id,
      for (final photo in _private)
        if (photo.isFavorite) photo.id,
    });
  }

  Future<void> _persistTrash() async {
    final store = _store;
    if (store == null) return;
    await store.saveTrashed({
      for (final trashed in _trash)
        trashed.photo.id: trashed.trashedAt,
    });
  }

  Future<void> toggleFavorite(String photoId) async {
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index == -1) return;
    _photos[index] = _photos[index].copyWith(
      isFavorite: !_photos[index].isFavorite,
    );
    _invalidateCaches();
    notifyListeners();
    await _persistFavorites();
  }

  /// Mueve una foto a la papelera (el archivo se conserva en disco).
  Future<void> moveToTrash(String photoId) async {
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index == -1) return;
    final photo = _photos.removeAt(index);
    _trash.add(TrashedPhoto(photo: photo, trashedAt: DateTime.now()));
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
  }

  /// Devuelve una foto de la papelera a la galería.
  Future<void> restoreFromTrash(String photoId) async {
    final index = _trash.indexWhere((t) => t.photo.id == photoId);
    if (index == -1) return;
    final trashed = _trash.removeAt(index);
    _photos.add(trashed.photo);
    _photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
  }

  /// Elimina definitivamente: borra el archivo (best-effort) y el registro.
  Future<void> deletePermanently(String photoId) async {
    final index = _trash.indexWhere((t) => t.photo.id == photoId);
    if (index == -1) return;
    final trashed = _trash.removeAt(index);
    try {
      await File(trashed.photo.path).delete();
    } catch (e) {
      debugPrint('No se pudo borrar ${trashed.photo.path}: $e');
    }
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
  }

  /// Vacía la papelera por completo (best-effort por archivo).
  Future<void> emptyTrash() async {
    final paths = _trash.map((t) => t.photo.path).toList();
    _trash.clear();
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (e) {
        debugPrint('No se pudo borrar $path: $e');
      }
    }
  }

  // ─── Acciones en lote (selección múltiple) ───

  /// Favoritos: si alguno del lote no es favorito, los marca todos.
  /// Si todos ya son favoritos, los quita.
  Future<void> toggleFavoritesBatch(Iterable<String> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final set = list.toSet();
    final allFavorite =
        _photos.where((p) => set.contains(p.id)).every((p) => p.isFavorite);
    for (var i = 0; i < _photos.length; i++) {
      if (!set.contains(_photos[i].id)) continue;
      _photos[i] = _photos[i].copyWith(isFavorite: !allFavorite);
    }
    _invalidateCaches();
    notifyListeners();
    await _persistFavorites();
  }

  /// Manda varios elementos a la papelera de una vez.
  Future<void> moveToTrashBatch(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    final now = DateTime.now();
    final moved = _photos.where((p) => set.contains(p.id)).toList();
    if (moved.isEmpty) return;
    _photos = _photos.where((p) => !set.contains(p.id)).toList();
    _trash = [..._trash, for (final p in moved) TrashedPhoto(photo: p, trashedAt: now)];
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
  }

  /// Elimina de verdad varios archivos (usado por la papelera).
  Future<void> deletePermanentlyBatch(Iterable<String> ids) async {
    final set = ids.toSet();
    if (set.isEmpty) return;
    final removed = _trash.where((t) => set.contains(t.photo.id)).toList();
    if (removed.isEmpty) return;
    _trash = _trash.where((t) => !set.contains(t.photo.id)).toList();
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
    for (final trashed in removed) {
      try {
        await File(trashed.photo.path).delete();
      } catch (e) {
        debugPrint('No se pudo borrar ${trashed.photo.path}: $e');
      }
    }
  }

  /// Restaura varios elementos de la papelera.
  Future<void> restoreFromTrashBatch(Iterable<String> ids) async {
    final set = ids.toSet();
    final restored = _trash.where((t) => set.contains(t.photo.id)).toList();
    if (restored.isEmpty) return;
    _trash = _trash.where((t) => !set.contains(t.photo.id)).toList();
    _photos = [..._photos, for (final t in restored) t.photo]
      ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
    _invalidateCaches();
    notifyListeners();
    await _persistTrash();
  }

  Future<bool> _requestAndroidPermissions() async {
    if (await Permission.photos.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }
}
