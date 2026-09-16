import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'rust/api.dart';
import 'rust/frb_generated.dart';

/// Modo de tema de la app (claro/oscuro/sistema), compartido entre páginas.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.dark);

/// Consulta global de búsqueda gestionada desde la barra superior.
final ValueNotifier<String> globalSearchQuery = ValueNotifier('');

/// Palabras típicas de capturas de pantalla (EN/ES).
const screenshotsKeywords = [
  'screenshot',
  'captura',
  'screen',
  'screencap',
  'pantalla',
  'capture',
];

/// Filtro reutilizable por nombre (búsqueda global).
List<Photo> filterPhotosByName(List<Photo> photos, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return photos;
  return photos.where((p) => p.name.toLowerCase().contains(q)).toList();
}

/// Capturas de pantalla: por nombre típico.
List<Photo> screenshotsOf(List<Photo> photos) {
  final regex = RegExp(screenshotsKeywords.join('|'), caseSensitive: false);
  return photos.where((p) => regex.hasMatch(p.name)).toList();
}

/// Fotos dentro de la carpeta Downloads.
bool downloadedOf(Photo p) {
  final path = p.path.toLowerCase();
  return path.contains('/downloads/') || path.contains('\\downloads\\');
}

class StoreController extends ChangeNotifier {
  StoreController._(this.store);

  static StoreController? _instance;
  final PhotoStore store;

  final Map<String, Uint8List> _thumbCache = {};

  List<Photo> photos = [];
  List<String> favorites = [];
  List<String> hiddenPaths = [];
  List<Album> albums = [];
  List<VideoFile> videos = [];
  List<MovedEntry> trashItems = [];
  List<MovedEntry> secureItems = [];
  bool pinSet = false;
  bool loading = false;
  bool videosLoading = false;
  String? errorText;

  static Future<StoreController> instance() async {
    if (_instance != null) return _instance!;
    await RustLib.init();
    final dir = await getApplicationSupportDirectory();
    final store = await PhotoStore.newInstance(configDir: dir.path);
    final controller = StoreController._(store);
    _instance = controller;
    await controller.refreshAlbums();
    await controller.refreshFavorites();
    await controller.refreshHidden();
    await controller.refreshPinState();
    await controller.refreshTrash();
    return controller;
  }

  /// Escanea todas las fotos del equipo (desde $HOME).
  Future<void> scanAll() async {
    loading = true;
    errorText = null;
    notifyListeners();
    try {
      photos = await store.scanSystem();
    } catch (e) {
      errorText = e.toString();
      photos = [];
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Reescanea todas las fotos (tras restaurar un archivo, por ejemplo).
  Future<void> rescan() => scanAll();

  Future<void> refreshFavorites() async {
    favorites = await store.favoritePaths();
    notifyListeners();
  }

  Future<void> refreshHidden() async {
    hiddenPaths = await store.hiddenPaths();
    notifyListeners();
  }

  Future<void> refreshVideos() async {
    videosLoading = true;
    notifyListeners();
    try {
      videos = await store.scanSystemVideos();
    } finally {
      videosLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshTrash() async {
    trashItems = await store.listTrash();
    notifyListeners();
  }

  Future<void> refreshSecure() async {
    secureItems = await store.listSecure();
    notifyListeners();
  }

  Future<void> refreshPinState() async {
    pinSet = await store.pinIsSet();
    notifyListeners();
  }

  /// Oculta una foto del álbum (persistente) o la vuelve a revelar.
  Future<void> setHidden(Photo photo, {required bool isHidden}) async {
    await store.setHidden(path: photo.path, isHidden: isHidden);
    if (isHidden) {
      final i = photos.indexWhere((p) => p.path == photo.path);
      if (i != -1) photos.removeAt(i);
    } else {
      await scanAll();
    }
    await refreshHidden();
  }

  /// Revela por ruta (usado desde la gestión de ocultas en Ajustes).
  Future<void> unhidePath(String path) async {
    final fresh = await store.getPhotos(paths: [path]);
    if (fresh.isNotEmpty) {
      await setHidden(fresh.first, isHidden: false);
    } else {
      await store.setHidden(path: path, isHidden: false);
      await refreshHidden();
    }
  }

  Future<void> refreshAlbums() async {
    albums = await store.listAlbums();
    notifyListeners();
  }

  Future<void> toggleFavorite(Photo photo) async {
    await store.setFavorite(path: photo.path, isFavorite: !photo.isFavorite);
    final i = photos.indexWhere((p) => p.path == photo.path);
    if (i != -1) {
      final fresh = await store.getPhotos(paths: [photo.path]);
      if (fresh.isNotEmpty) photos[i] = fresh.first;
    }
    await refreshFavorites();
  }

  Future<bool> isFavorite(String path) async {
    await refreshFavorites();
    return favorites.contains(path);
  }

  Future<List<Photo>> photosForPaths(List<String> paths) =>
      store.getPhotos(paths: paths);

  Future<Uint8List?> thumbnail(String path, {int size = 256}) async {
    final cached = _thumbCache[path];
    if (cached != null) return cached;
    final bytes = await store.thumbnailBytes(path: path, size: size);
    if (bytes != null) {
      _thumbCache[path] = bytes;
      if (_thumbCache.length > 512) {
        final oldest = _thumbCache.keys.first;
        _thumbCache.remove(oldest);
      }
    }
    return bytes;
  }

  Future<void> deletePhoto(String path) async {
    _thumbCache.remove(path);
    final i = photos.indexWhere((p) => p.path == path);
    if (i != -1) photos.removeAt(i);
    await store.deletePhoto(path: path);
    await refreshFavorites();
    await refreshAlbums();
    hiddenPaths.remove(path);
  }

  Future<void> moveToTrash(Photo photo) async {
    _thumbCache.remove(photo.path);
    final i = photos.indexWhere((p) => p.path == photo.path);
    if (i != -1) photos.removeAt(i);
    await store.moveToTrash(path: photo.path);
    await refreshFavorites();
    await refreshAlbums();
    await refreshTrash();
    hiddenPaths.remove(photo.path);
  }

  Future<MovedEntry> _moveToSecurePath(String path) =>
      store.moveToSecure(path: path);

  Future<void> moveToSecure(Photo photo) async {
    _thumbCache.remove(photo.path);
    final i = photos.indexWhere((p) => p.path == photo.path);
    if (i != -1) photos.removeAt(i);
    await _moveToSecurePath(photo.path);
    await refreshFavorites();
    await refreshAlbums();
    await refreshSecure();
    hiddenPaths.remove(photo.path);
  }

  Future<List<MovedEntry>> listTrash() => Future.value(trashItems);
  Future<void> restoreTrash(MovedEntry entry) async {
    await store.restoreTrash(name: entry.name);
    await refreshTrash();
    await scanAll();
  }

  Future<void> deleteTrashItem(MovedEntry entry) async {
    await store.deleteTrashItem(name: entry.name);
    await refreshTrash();
  }

  Future<void> emptyTrash() async {
    await store.emptyTrash();
    await refreshTrash();
  }

  Future<List<MovedEntry>> listSecure() => Future.value(secureItems);
  Future<void> restoreSecure(MovedEntry entry) async {
    await store.restoreSecure(name: entry.name);
    await refreshSecure();
    await scanAll();
  }

  Future<void> deleteSecureItem(MovedEntry entry) async {
    await store.deleteSecureItem(name: entry.name);
    await refreshSecure();
  }

  Future<void> setPin(String pin) async {
    await store.setPin(pin: pin);
    await refreshPinState();
  }

  Future<void> clearPin() async {
    await store.clearPin();
    await refreshPinState();
  }

  Future<bool> pinIsSet() => Future.value(pinSet);
  Future<bool> verifyPin(String pin) => store.verifyPin(pin: pin);

  Future<List<VideoFile>> scanAllVideos() => store.scanSystemVideos();

  Future<Album> createAlbum(String name) async {
    final album = await store.createAlbum(name: name);
    await refreshAlbums();
    return album;
  }

  Future<void> addToAlbum(String albumId, List<String> paths) async {
    await store.addPhotosToAlbum(albumId: albumId, photos: paths);
    await refreshAlbums();
  }

  Future<void> removeFromAlbum(String albumId, List<String> paths) async {
    await store.removePhotosFromAlbum(albumId: albumId, photos: paths);
    await refreshAlbums();
  }

  Future<Album> renameAlbum(String albumId, String newName) async {
    final album = await store.renameAlbum(albumId: albumId, newName: newName);
    await refreshAlbums();
    return album;
  }

  Future<void> deleteAlbum(String albumId) async {
    await store.deleteAlbum(albumId: albumId);
    await refreshAlbums();
  }
}
