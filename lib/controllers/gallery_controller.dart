// lib/controllers/gallery_controller.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/photo.dart';
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

class GalleryController extends ChangeNotifier {
  final PhotoService _photoService = PhotoService();

  GalleryState _state = GalleryState.initial;
  GalleryState get state => _state;

  List<Photo> _photos = [];
  List<Photo> get photos => _photos;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Retorna las fotos marcadas como favoritas
  List<Photo> get favoritePhotos => _photos.where((p) => p.isFavorite).toList();

  /// Retorna las fotos agrupadas por carpeta (Álbumes)
  List<Album> get albums {
    final Map<String, List<Photo>> albumMap = {};

    for (final photo in _photos) {
      final parentDir = p.dirname(photo.path);
      if (!albumMap.containsKey(parentDir)) {
        albumMap[parentDir] = [];
      }
      albumMap[parentDir]!.add(photo);
    }

    return albumMap.entries.map((entry) {
      final folderName = p.basename(entry.key);
      return Album(name: folderName, path: entry.key, photos: entry.value);
    }).toList();
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
      _photos = await _photoService.loadPhotos();
      _state = GalleryState.loaded;
    } catch (e) {
      _errorMessage = 'Error al cargar las fotos: $e';
      _state = GalleryState.error;
    } finally {
      notifyListeners();
    }
  }

  void toggleFavorite(String photoId) {
    final index = _photos.indexWhere((p) => p.id == photoId);
    if (index != -1) {
      _photos[index] = _photos[index].copyWith(
        isFavorite: !_photos[index].isFavorite,
      );
      notifyListeners();
    }
  }

  Future<bool> _requestAndroidPermissions() async {
    if (await Permission.photos.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }
}
