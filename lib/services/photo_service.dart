import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/photo.dart';
import 'media_probe.dart';

class PhotoService {
  static const Set<String> imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
  };

  static const Set<String> videoExtensions = {
    '.mp4',
    '.mov',
    '.m4v',
    '.3gp',
    '.mkv',
    '.webm',
    '.avi',
  };

  /// Todos los formatos que la app descubre del disco (fotos + vídeos).
  static const Set<String> supportedExtensions = {
    ...imageExtensions,
    ...videoExtensions,
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

  /// Raíces existentes, listas para observar con [Directory.watch].
  /// Es la misma fuente que usa [loadPhotos]: lo que se detecte aquí es
  /// lo que aparecerá en la galería tras recargar.
  Future<List<Directory>> existingRoots() async {
    final List<Directory> dirs;
    if (roots != null) {
      dirs = roots!;
    } else if (Platform.isAndroid) {
      dirs = _androidDirs();
    } else if (Platform.isLinux) {
      dirs = _ubuntuDirs();
    } else {
      return [];
    }
    final existing = <Directory>[];
    for (final dir in dirs) {
      try {
        if (await dir.exists()) existing.add(dir);
      } catch (_) {
        continue;
      }
    }
    return existing;
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
            isVideo: (row['isVideo'] as bool?) ?? false,
            width: row['width'] as int?,
            height: row['height'] as int?,
            latitude: (row['lat'] as num?)?.toDouble(),
            longitude: (row['lng'] as num?)?.toDouble(),
            locationLabel: _locationLabel(
              (row['lat'] as num?)?.toDouble(),
              (row['lng'] as num?)?.toDouble(),
            ),
            isMotionPhoto: _isMotionPhoto(row['path'] as String),
            isSelfie: _isSelfie(row['path'] as String),
            // duration se resuelve bajo demanda en el visor (media_kit).
          ),
        )
        .toList();

    photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return photos;
  }

  /// Etiqueta geográfica legible a partir de coordenadas EXIF.
  /// Sin red (sin geocodificación inversa): coordenadas con 4 decimales
  /// (~11 m). Null = el visor oculta la ubicación.
  static String? _locationLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Heurística Motion Photo por nombre (MVIMG, motion, live).
  static bool _isMotionPhoto(String filePath) {
    final name = p.basename(filePath).toUpperCase();
    return name.contains('MVIMG') ||
        name.contains('MOTION') ||
        name.contains('LIVE');
  }

  /// Heurística selfie por nombre/carpeta (frontal, selfie).
  static bool _isSelfie(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.contains('selfie') ||
        lower.contains('front') ||
        lower.contains('img_f');
  }

  /// Barrido asíncrono pensado para correr en background vía `compute`.
  /// Solo devuelve tipos primitivos porque cruza el límite del isolate.
  ///
  /// Dos fases: (1) caminata síncrona rápida con `stat` y (2) sonda de
  /// cabecera (dimensiones + GPS EXIF) en lotes concurrentes. Un fallo
  /// por archivo nunca rompe el barrido: esa foto queda sin metadatos.
  static Future<List<Map<String, Object>>> _scanPaths(
    List<String> dirPaths,
  ) async {
    final found = <_FoundFile>[];
    for (final dirPath in dirPaths) {
      try {
        final entities = Directory(
          dirPath,
        ).listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (!_isValidMediaFile(entity)) continue;
          final file = entity as File;

          FileStat stat;
          try {
            stat = file.statSync();
          } catch (_) {
            continue;
          }
          // Ignorar archivos vacíos / corruptos de 0 bytes
          if (stat.size == 0) continue;

          found.add(
            _FoundFile(
              path: file.path,
              created: stat.changed.millisecondsSinceEpoch,
              modified: stat.modified.millisecondsSinceEpoch,
              size: stat.size,
              isVideo: videoExtensions.contains(
                p.extension(file.path).toLowerCase(),
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error leyendo directorio ($dirPath): $e');
      }
    }

    final rows = <Map<String, Object>>[];
    // Lotes concurrentes: I/O en paralelo sin saturar descriptores.
    for (var i = 0; i < found.length; i += 24) {
      final batch = found.sublist(
        i,
        i + 24 > found.length ? found.length : i + 24,
      );
      final probed = await Future.wait(batch.map(_probeFound));
      rows.addAll(probed);
    }
    return rows;
  }

  /// Materializa la fila de un archivo + su sonda (si es imagen).
  static Future<Map<String, Object>> _probeFound(_FoundFile file) async {
    final row = <String, Object>{
      'path': file.path,
      'created': file.created,
      'modified': file.modified,
      'size': file.size,
      'isVideo': file.isVideo,
    };
    if (file.isVideo) return row;
    try {
      final probe = await probeImageFile(file.path);
      if (probe == null) return row;
      if (probe.width != null) row['width'] = probe.width!;
      if (probe.height != null) row['height'] = probe.height!;
      if (probe.latitude != null) row['lat'] = probe.latitude!;
      if (probe.longitude != null) row['lng'] = probe.longitude!;
    } catch (_) {
      // Sonda best-effort: la foto entra igual, sin metadatos.
    }
    return row;
  }

  /// Helper para validar si un archivo es una foto/vídeo válido y NO oculto.
  static bool _isValidMediaFile(FileSystemEntity entity) {
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

    // 4. Validar extensión permitida (fotos + vídeos)
    final ext = p.extension(entity.path).toLowerCase();
    if (!supportedExtensions.contains(ext)) return false;

    return true;
  }
}

/// Archivo candidato hallado en la caminata (fase 1 del escaneo).
class _FoundFile {
  final String path;
  final int created;
  final int modified;
  final int size;
  final bool isVideo;

  const _FoundFile({
    required this.path,
    required this.created,
    required this.modified,
    required this.size,
    required this.isVideo,
  });
}
