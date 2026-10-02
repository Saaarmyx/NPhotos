// lib/services/native_media_index.dart
//
// Hidratación instantánea (<50ms) desde el índice persistente redb de NexoraCore.
// Igual que NFiles usa NativeFileIndex, NPhotos usa esto para arrancar
// con la grilla poblada ANTES del primer frame.
//
// # Protocolo
//
// 1. Al arrancar: `open()` + `hydrate()` → `List<Photo>` con un `memcpy`
//    desde redb, sin tocar el disco. La grilla pinta al instante.
// 2. En segundo plano: el controlador hace `fetchPhotos()` que re-escanea
//    y actualiza el índice con `persist()`.
// 3. `changedRoots()` filtra por `mtime` de carpeta: solo esas se re-escannean.
//
// Sin motor nativo todo degrada a `[]`/`false` y el controlador cae a su
// snapshot de `SharedPreferences`: el índice es una optimización, no un
// requisito.
import 'dart:io';

import 'package:NexoraCore/NexoraCore.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/photo.dart';

/// Nombre del `.redb` en el support dir de la app.
/// **Mismo archivo que NFiles**: así el índice es compartido entre apps.
const String kNexoraSharedIndexName = 'nexora_index.redb';

/// Índice nativo de medios para NPhotos.
class NativeMediaIndex {
  final NativeIndexStore _store;
  final Future<Directory> Function()? _supportDirForTest;

  NativeMediaIndex({
    NativeIndexStore? store,
    Future<Directory> Function()? supportDirForTest,
  })  : _store = store ?? NativeIndexStore(),
        // ignore: prefer_initializing_formals
        _supportDirForTest = supportDirForTest;

  /// `true` si el motor nativo está disponible y soporta índice.
  bool get isAvailable => _store.isAvailable;

  /// Abre el `.redb` compartido. `false` sin motor: el llamante usa el snapshot viejo.
  Future<bool> open() async {
    if (!_store.isAvailable) return false;
    try {
      final override = _supportDirForTest;
      final dir = override != null
          ? await override()
          : await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, kNexoraSharedIndexName);
      return _store.open(dbPath);
    } catch (_) {
      return false;
    }
  }

  /// Hidrata desde la BD local. Rápido por diseño: un `memcpy` desde redb,
  /// sin `stat` por archivo. Devuelve solo fotos/vídeos (no carpetas).
  List<Photo> hydrate({Set<String>? favoriteIds}) {
    if (!_store.isAvailable) return const [];
    final entries = _store.load();
    if (entries.isEmpty) return const [];

    final favs = favoriteIds ?? const <String>{};
    final out = <Photo>[];

    for (final e in entries) {
      // Solo archivos (no directorios) y solo imágenes/vídeos
      if (e.type != EntryType.file) continue;
      if (e.kind != FileKind.image && e.kind != FileKind.video) continue;
      if (e.isHidden) continue; // saltar ocultos

      out.add(Photo(
        id: e.path,
        path: e.path,
        title: e.name,
        dateCreated: e.created ?? e.modified,
        dateModified: e.modified,
        sizeInBytes: e.size < 0 ? 0 : e.size,
        isFavorite: favs.contains(e.path),
        isVideo: e.kind == FileKind.video,
      ));
    }

    // Orden: más recientes primero (como la galería)
    out.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return out;
  }

  /// Raíces cuyo `mtime` cambió (o nuevas): SOLO esas se re-escannean.
  ///
  /// Recibe directorios existentes (ya filtrados por `existingRoots`).
  /// Sin índice devuelve todas (escaneo completo como antes).
  List<String> changedRoots(List<Directory> existing) {
    final paths = [for (final d in existing) d.path];
    return _store.changedDirs(paths);
  }

  /// Persiste filas de medios + `mtime` de las raíces escaneadas.
  /// Devuelve cuántas filas guardó.
  int persist(List<Photo> photos, List<Directory> roots) {
    if (!_store.isAvailable || photos.isEmpty) return 0;

    final entries = <FileEntry>[
      for (final f in photos)
        FileEntry(
          path: f.path,
          name: f.title,
          type: EntryType.file,
          size: f.sizeInBytes,
          modified: f.dateModified,
          created: f.dateCreated,
          kind: f.isVideo ? FileKind.video : FileKind.image,
          isHidden: false,
        ),
    ];

    final n = _store.putAll(entries);
    _store.touchDirs([for (final r in roots) r.path]);
    return n;
  }

  /// Número de filas en el índice.
  int? count() => _store.count();
}