import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/photo.dart';

class PhotoService {
  static const Set<String> supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
  };

  /// Directorios raíz a escanear. Si es `null` se usan los de la plataforma.
  /// Existe para tests y futuras fuentes personalizadas.
  final List<Directory>? roots;

  PhotoService({this.roots});

  Future<List<Photo>> loadPhotos() async {
    if (roots != null) {
      return _loadFromDirectories(roots!, label: 'Custom');
    }
    if (Platform.isAndroid) {
      return _loadFromDirectories(_androidDirs(), label: 'Android');
    } else if (Platform.isLinux) {
      return _loadFromDirectories(_ubuntuDirs(), label: 'Ubuntu');
    }
    return [];
  }

  List<Directory> _ubuntuDirs() {
    final home = Platform.environment['HOME'];
    if (home == null) return [];
    return [
      Directory(p.join(home, 'Pictures')),
      Directory(p.join(home, 'Downloads')),
      Directory(p.join(home, 'Imágenes')),
    ];
  }

  List<Directory> _androidDirs() {
    const String basePath = '/storage/emulated/0';
    return [
      Directory(p.join(basePath, 'DCIM')),
      Directory(p.join(basePath, 'Pictures')),
      Directory(p.join(basePath, 'Download')),
    ];
  }

  /// Recorre [dirs] y construye la lista de fotos ordenada por modificación.
  ///
  /// El barrido del disco corre en un isolate ([compute]) para no bloquear
  /// el hilo de UI con bibliotecas grandes; aquí solo se materializan
  /// los [Photo] a partir de filas simples (transferibles entre isolates).
  Future<List<Photo>> _loadFromDirectories(
    List<Directory> dirs, {
    required String label,
  }) async {
    final existing = <String>[];
    for (final dir in dirs) {
      if (await dir.exists()) existing.add(dir.path);
    }
    if (existing.isEmpty) return [];

    List<Map<String, Object>> rows;
    try {
      rows = await compute(_scanPaths, existing);
    } catch (e) {
      debugPrint('Error escaneando directorios $label: $e');
      return [];
    }

    final photos = rows
        .map(
          (row) => Photo(
            id: row['path'] as String,
            path: row['path'] as String,
            title: p.basename(row['path'] as String),
            dateCreated: DateTime.fromMillisecondsSinceEpoch(
              row['created'] as int,
            ),
            dateModified: DateTime.fromMillisecondsSinceEpoch(
              row['modified'] as int,
            ),
            sizeInBytes: row['size'] as int,
          ),
        )
        .toList();

    photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return photos;
  }

  /// Barrido síncrono pensado para correr en background. Solo devuelve
  /// tipos primitivos porque cruza el límite del isolate.
  static List<Map<String, Object>> _scanPaths(List<String> dirPaths) {
    final rows = <Map<String, Object>>[];
    for (final dirPath in dirPaths) {
      try {
        final entities = Directory(
          dirPath,
        ).listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (!_isValidImageFile(entity)) continue;
          final file = entity as File;

          FileStat stat;
          try {
            stat = file.statSync();
          } catch (_) {
            continue;
          }
          // Ignorar archivos vacíos / corruptos de 0 bytes
          if (stat.size == 0) continue;

          rows.add({
            'path': file.path,
            'created': stat.changed.millisecondsSinceEpoch,
            'modified': stat.modified.millisecondsSinceEpoch,
            'size': stat.size,
          });
        }
      } catch (e) {
        debugPrint('Error leyendo directorio ($dirPath): $e');
      }
    }
    return rows;
  }

  /// Helper para validar si un archivo es una imagen válida y NO oculta
  static bool _isValidImageFile(FileSystemEntity entity) {
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
}
