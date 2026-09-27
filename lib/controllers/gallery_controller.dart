// lib/controllers/gallery_controller.dart
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

  // Derivados cacheados: se recalculan solo cuando cambian los datos.
  List<Photo>? _cachedFavorites;
  List<Album>? _cachedAlbums;

  void _invalidateCaches() {
    _cachedFavorites = null;
    _cachedAlbums = null;
  }

  /// Retorna las fotos marcadas como favoritas
  List<Photo> get favoritePhotos =>
      _cachedFavorites ??= _photos.where((p) => p.isFavorite).toList();

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

  Future<void> fetchPhotos() async {
    _state = GalleryState.loading;
    _errorMessage = null;
    notifyListeners();

    if (Platform.isAndroid) {
      final hasPermission = await _requestAndroidPermissions();
      if (!hasPermission) {
        _state = GalleryState.permissionDenied;
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
      notifyListeners();
    }
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
