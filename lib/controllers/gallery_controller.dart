// lib/controllers/gallery_controller.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/photo.dart';
import '../services/local_store.dart';
import '../services/photo_service.dart';

enum GalleryState { initial, permissionDenied, loading, loaded, error }

/// Modelo sencillo para representar un Álbum
class Album {
  final String name;
  final String path;
  final List<Photo> photos;

  Album({required this.name, required this.path, required this.photos});

  Photo get coverPhoto => photos.first;
}

/// Foto en la papelera con su fecha de eliminación.
class TrashedPhoto {
  final Photo photo;
  final DateTime trashedAt;

  const TrashedPhoto({required this.photo, required this.trashedAt});
}

class GalleryController extends ChangeNotifier {
  final PhotoService _photoService;
  LocalStore? _store;

  GalleryController({PhotoService? photoService, this._store})
    : _photoService = photoService ?? PhotoService();

  GalleryState _state = GalleryState.initial;
  GalleryState get state => _state;

  List<Photo> _photos = [];
  List<Photo> get photos => _photos;

  List<TrashedPhoto> _trash = [];
  List<TrashedPhoto> get trash => List.unmodifiable(_trash);

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

  void _invalidateCaches() {
    _cachedFavorites = null;
    _cachedAlbums = null;
    _cachedVideos = null;
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
      final folderName = p.basename(entry.key);
      return Album(name: folderName, path: entry.key, photos: entry.value);
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

  /// Rutas de carpetas ya pineadas (cámara/capturas) para excluirlas de la
  /// parrilla general de álbumes y no duplicarlas.
  Set<String> get pinnedAlbumPaths => {
    if (cameraAlbum != null) cameraAlbum!.path,
    if (screenshotsAlbum != null) screenshotsAlbum!.path,
  };

  /// Álbumes sin los pineados (lo que va debajo en la pantalla).
  List<Album> get unpinnedAlbums =>
      albums.where((a) => !pinnedAlbumPaths.contains(a.path)).toList();

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

  Future<void> fetchPhotos() async {
    // Anti-solape: el watcher, el pull-to-refresh y el resume pueden
    // pedir recargas a la vez; solo un escaneo corre al mismo tiempo.
    if (_fetching) return;
    _fetching = true;
    _state = GalleryState.loading;
    _errorMessage = null;
    notifyListeners();

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

      _photos = [];
      _trash = [];
      for (final photo in loaded) {
        final withFavorite = favoriteIds.contains(photo.id)
            ? photo.copyWith(isFavorite: true)
            : photo;
        final trashed = trashedAt[photo.id];
        if (trashed != null) {
          _trash.add(TrashedPhoto(photo: withFavorite, trashedAt: trashed));
        } else {
          _photos.add(withFavorite);
        }
      }

      await _pruneStaleRecords(loaded.map((p) => p.id).toSet());
      _invalidateCaches();
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
      if (!_disposed) fetchPhotos();
    });
  }

  /// Recarga inmediata (pull-to-refresh, botón, resume).
  Future<void> refresh() => fetchPhotos();

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

  /// Elimina registros de favoritos/papelera de archivos que ya no existen.
  Future<void> _pruneStaleRecords(Set<String> knownIds) async {
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
  }

  Future<void> _persistFavorites() async {
    final store = _store;
    if (store == null) return;
    await store.saveFavoriteIds({
      for (final photo in _photos)
        if (photo.isFavorite) photo.id,
      for (final trashed in _trash)
        if (trashed.photo.isFavorite) trashed.photo.id,
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

  Future<bool> _requestAndroidPermissions() async {
    if (await Permission.photos.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }
}
