import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'rust/api.dart';
import 'rust/frb_generated.dart';

class StoreController extends ChangeNotifier {
  StoreController._(this.store);

  static StoreController? _instance;
  final PhotoStore store;

  final Map<String, Uint8List> _thumbCache = {};

  String? rootPath;
  List<Photo> photos = [];
  List<String> favorites = [];
  List<Album> albums = [];
  bool loading = false;
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
    return controller;
  }

  Future<void> scan(String root) async {
    loading = true;
    errorText = null;
    notifyListeners();
    try {
      photos = await store.scanDirectory(root: root);
      rootPath = root;
    } catch (e) {
      errorText = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshFavorites() async {
    favorites = await store.favoritePaths();
    notifyListeners();
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
  }

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