import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/photo.dart';

class PhotoService {
  final List<String> supportedExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
  ];

  Future<List<Photo>> loadPhotos() async {
    if (Platform.isAndroid) {
      return await _loadAndroidPhotos();
    } else if (Platform.isLinux) {
      return await _loadUbuntuPhotos();
    }
    return [];
  }

  /// Helper para validar si un archivo es una imagen válida y NO oculta
  bool _isValidImageFile(FileSystemEntity entity) {
    if (entity is! File) return false;

    // 1. Obtener el nombre del archivo
    final filename = p.basename(entity.path);

    // 2. Descartar si el archivo es oculto (empieza por '.')
    if (filename.startsWith('.')) return false;

    // 3. Descartar si está dentro de una carpeta oculta (ej. .cache, .trash, .thumbnails)
    final parts = p.split(entity.path);
    if (parts.any(
      (part) => part.startsWith('.') && part != '.' && part != '..',
    )) {
      return false;
    }

    // 4. Validar extensión permitida
    final ext = p.extension(entity.path).toLowerCase();
    if (!supportedExtensions.contains(ext)) return false;

    return true;
  }

  // ==========================================
  // LÓGICA UBUNTU
  // ==========================================
  Future<List<Photo>> _loadUbuntuPhotos() async {
    final List<Photo> photos = [];
    final home = Platform.environment['HOME'];
    if (home == null) return [];

    final List<Directory> targetDirs = [
      Directory(p.join(home, 'Pictures')),
      Directory(p.join(home, 'Downloads')),
      Directory(p.join(home, 'Imágenes')),
    ];

    for (final dir in targetDirs) {
      if (!await dir.exists()) continue;

      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (_isValidImageFile(entity)) {
            final file = entity as File;
            if (!file.existsSync()) continue;

            final stat = await file.stat();
            // Ignorar archivos vacíos / corruptos de 0 bytes
            if (stat.size == 0) continue;

            photos.add(
              Photo(
                id: file.path,
                path: file.path,
                title: p.basename(file.path),
                dateCreated: stat.changed,
                dateModified: stat.modified,
                sizeInBytes: stat.size,
              ),
            );
          }
        }
      } catch (e) {
        print('Error leyendo directorio Ubuntu (${dir.path}): $e');
      }
    }

    photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return photos;
  }

  // ==========================================
  // LÓGICA ANDROID
  // ==========================================
  Future<List<Photo>> _loadAndroidPhotos() async {
    final List<Photo> photos = [];
    const String basePath = '/storage/emulated/0';

    final List<Directory> androidDirs = [
      Directory(p.join(basePath, 'DCIM')),
      Directory(p.join(basePath, 'Pictures')),
      Directory(p.join(basePath, 'Download')),
    ];

    for (final dir in androidDirs) {
      if (!await dir.exists()) continue;

      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (_isValidImageFile(entity)) {
            final file = entity as File;
            if (!file.existsSync()) continue;

            final stat = await file.stat();
            // Ignorar archivos vacíos / corruptos de 0 bytes
            if (stat.size == 0) continue;

            photos.add(
              Photo(
                id: file.path,
                path: file.path,
                title: p.basename(file.path),
                dateCreated: stat.changed,
                dateModified: stat.modified,
                sizeInBytes: stat.size,
              ),
            );
          }
        }
      } catch (e) {
        print('Error en directorio Android (${dir.path}): $e');
      }
    }

    photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return photos;
  }
}
