// lib/services/private_vault.dart
//
// Carpeta privada v1: mueve archivos fuera de las raíces escaneadas
// (DCIM/Pictures/Download) a un directorio propio de la app, así dejan
// de aparecer en galería, álbumes y colecciones.
//
// v1 sin bloqueo: aún no pide autenticación (ver README de la colección).
// El siguiente paso es gatear la pantalla con `local_auth`.
import 'dart:io';

import 'package:path/path.dart' as p;

/// Mueve archivos hacia/desde el directorio privado.
class PrivateVault {
  final Directory dir;

  PrivateVault(this.dir);

  Future<void> ensureReady() async {
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Archivos dentro de la bóveda (solo nombres directos, sin subcarpetas).
  Future<List<File>> files() async {
    await ensureReady();
    final out = <File>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && !p.basename(entity.path).startsWith('.')) {
          out.add(entity);
        }
      }
    } catch (_) {
      // Bóveda ilegible: se reporta vacía, nunca rompe la carga.
    }
    return out;
  }

  /// Mueve [source] a la bóveda con nombre único. Retorna la ruta destino.
  Future<String> moveIn(File source) async {
    await ensureReady();
    var name = p.basename(source.path);
    var dest = File(p.join(dir.path, name));
    var n = 1;
    while (await dest.exists()) {
      n++;
      final stem = p.basenameWithoutExtension(name);
      dest = File(p.join(dir.path, '$stem ($n)${p.extension(name)}'));
    }
    return _moveFile(source, dest);
  }

  /// Saca un archivo de la bóveda hacia [targetDir].
  Future<String> moveOut(String vaultPath, Directory targetDir) async {
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    var dest = File(p.join(targetDir.path, p.basename(vaultPath)));
    var n = 1;
    while (await dest.exists()) {
      n++;
      final stem = p.basenameWithoutExtension(vaultPath);
      dest = File(
        p.join(targetDir.path, '$stem ($n)${p.extension(vaultPath)}'),
      );
    }
    return _moveFile(File(vaultPath), dest);
  }

  /// rename si el FS lo permite; si no, copia + borra.
  static Future<String> _moveFile(File source, File dest) async {
    try {
      await source.rename(dest.path);
      return dest.path;
    } catch (_) {
      await source.copy(dest.path);
      try {
        await source.delete();
      } catch (_) {
        // El original sobrevivió: se conserva la copia como respaldo.
      }
      return dest.path;
    }
  }
}
