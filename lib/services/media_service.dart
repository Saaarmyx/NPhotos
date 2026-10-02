// lib/services/media_service.dart
//
// Puente de medios para la galería: usa la API asíncrona de
// `NexoraCore` (motor nativo en Rust) y cae a la sonda de Dart cuando
// la `.so` no está.
//
// # Por qué un servicio y no llamar a NexoraCore desde el controlador
//
// El controlador pinta; esto decide de dónde sale el dato. La degradación
// vive aquí y en un solo sitio, de modo que `GalleryController` no
// necesita saber si hay motor nativo: pide metadatos y recibe lo que
// haya.
//
// # El orden de preferencia
//
// 1. **Motor nativo**: lee la cabecera EXIF en Rust, en un isolate, y
//    devuelve fecha, cámara, GPS y dimensiones. Es el único que puede
//    leer 30.000 fotos sin bloquear la UI.
// 2. **La sonda de NexoraCore (Dart)**: lee la cabecera en isolate. Más lenta
//    pero sin dependencias nativas, y es lo que hay en una máquina de
//    desarrollo sin Rust.
//
// Ninguno de los dos lanza: si los dos fallan, se devuelven los campos
// vacíos y la UI oculta lo que no sabe, que es el comportamiento
// correcto para metadatos opcionales.
import 'dart:io';

import 'package:NexoraCore/NexoraCore.dart';
import 'package:path/path.dart' as p;


/// Metadatos de una foto, con el origen del dato.
///
/// El origen se guarda para poder depurar sin adivinar: si una fecha
/// sale mal, la pregunta es si la leyó Rust o Dart, y eso cambia por
/// completo el sitio donde mirar.
enum MediaSource {
  /// Motor nativo en Rust (`NexoraCore`).
  native,

  /// Sonda en Dart.
  dartProbe,
}

/// Metadatos de una foto, listos para la galería.
class PhotoMetadata {
  final String path;
  final DateTime? capturedAt;
  final String? camera;
  final double? latitude;
  final double? longitude;
  final int? width;
  final int? height;
  final bool hasExif;
  final MediaSource source;

  const PhotoMetadata({
    required this.path,
    this.capturedAt,
    this.camera,
    this.latitude,
    this.longitude,
    this.width,
    this.height,
    this.hasExif = false,
    this.source = MediaSource.dartProbe,
  });

  /// `true` si hay algo que enseñar de verdad.
  ///
  /// Lo usa la UI para decidir si abre el panel de detalles o se
  /// salta: es preferible no mostrarlo a mostrar campos vacíos.
  bool get hasAnything =>
      capturedAt != null ||
      camera != null ||
      latitude != null ||
      width != null;

  /// Fecha efectiva de la foto.
  ///
  /// La de captura si la hay; si no, la de modificación, que es lo que
  /// usa un explorador de archivos y lo único que hay sin metadatos.
  DateTime? get effectiveDate => capturedAt;
}

/// Servicios de medios para la galería.
class MediaService {
  MediaService({MediaIndexService? index, ThumbsService? thumbs})
      : _index = index ?? MediaIndexService(),
        _thumbs = thumbs ?? ThumbsService();

  final MediaIndexService _index;
  final ThumbsService _thumbs;

  /// `true` si la `.so` está disponible.
  bool get hasNativeEngine => _index.isNativeAvailable;

  /// Motivo de la degradación.
  ///
  /// No es `null` ni siquiera antes de la primera operación: el bridge
  /// solo lo conoce después de hablar con el motor, y un motivo nulo se
  /// lee como "todo bien" cuando en realidad nadie lo ha intentado
  /// todavía. Aquí se distingue ese caso del de "no hay motor", que es el
  /// que la app quiere poder mostrar.
  String? get unavailableReason =>
      _index.unavailableReason ?? 'el motor aún no se ha consultado';

  /// Aplica el perfil de rendimiento de `CorePerformance`.
  ///
  /// Debe llamarse en cuanto la app sepa el perfil, antes de la primera
  /// tanda: si no, el motor trabaja con su perfil por defecto.
  void setPerformanceProfile(int profileId) {
    _index.setPerformanceProfile(profileId);
    _thumbs.setPerformanceProfile(profileId);
  }

  /// Lee los metadatos de un lote de fotos.
  ///
  /// [paths] son rutas absolutas. Devuelve un mapa `ruta -> metadatos`
  /// con una entrada por foto: un archivo ilegible sale con los campos
  /// vacíos, no desaparece del mapa, porque la galería ya sabe que
  /// existe y borrarla de la lista sería peor.
  Future<Map<String, PhotoMetadata>> loadMetadata(
    List<String> paths,
  ) async {
    if (paths.isEmpty) return const {};

    // 1) Motor nativo. Lee la cabecera EXIF en Rust, en un isolate.
    final meta = await _index.readMetadata(paths);
    if (meta != null && meta.isNotEmpty) {
      return {
        for (final m in meta)
          m.path: PhotoMetadata(
            path: m.path,
            capturedAt: m.captured,
            camera: m.camera.isEmpty ? null : m.camera,
            latitude: m.latitude,
            longitude: m.longitude,
            width: m.width > 0 ? m.width : null,
            height: m.height > 0 ? m.height : null,
            hasExif: m.hasExif,
            source: MediaSource.native,
          ),
      };
    }

    // 2) Sonda de Dart. Sin `.so`, o si el motor no trajo nada.
    final out = <String, PhotoMetadata>{};
    for (final path in paths) {
      out[path] = await _probeOne(path);
    }
    return out;
  }

  /// Secciones de la galería agrupadas por día.
  ///
  /// Con motor nativo el agrupado lo hace Rust sobre el índice que ya
  /// está en su memoria, así que es barato. Sin él, se agrupa en Dart
  /// por la fecha de modificación, que es el mismo criterio que usa
  /// Rust cuando no hay EXIF.
  Future<List<GallerySection>> groupByDay(List<String> paths) async {
    if (paths.isEmpty) return const [];

    await loadMetadata(paths);
    if (hasNativeEngine) {
      final sections = await _index.group(groupBy: GroupBy.day);
      if (sections.isNotEmpty) {
        return [
          for (final s in sections)
            GallerySection(
              label: s.label,
              day: s.day,
              paths: [for (final m in s.items) m.path],
            ),
        ];
      }
    }

    // Fallback Dart: agrupar por día de modificación.
    final byDay = <DateTime, List<String>>{};
    for (final path in paths) {
      final day = _modifiedDay(path);
      byDay.putIfAbsent(day, () => <String>[]).add(path);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in days)
        GallerySection(
          label: _formatDay(day),
          day: day,
          paths: byDay[day]!,
        ),
    ];
  }

  /// Miniaturas de un lote, por la ruta del JPEG en disco.
  ///
  /// La clave es la ruta original porque así la galería no tiene que
  /// saber nada de la caché: pide por foto y recibe la miniatura.
  /// Sin motor devuelve un mapa vacío y la UI usa su placeholder.
  Future<Map<String, String>> loadThumbnails(
    List<String> paths, {
    int boxPx = ThumbBox.grid,
  }) async {
    if (paths.isEmpty) return const {};
    final refs = await _thumbs.generate(paths, boxPx: boxPx);
    return {
      for (final r in refs)
        if (r.isUsable) r.source: r.path,
    };
  }

  /// Borra la caché de miniaturas. Devuelve cuántos archivos eliminó.
  Future<int> clearThumbnailCache() => _thumbs.clearCache();

  // ── Interno ────────────────────────────────────────────────────────────

  /// Sonda de Dart para UN archivo.
  Future<PhotoMetadata> _probeOne(String path) async {
    try {
      final probe = await probeImageFile(path);
      if (probe == null) {
        return PhotoMetadata(path: path, source: MediaSource.dartProbe);
      }
      return PhotoMetadata(
        path: path,
        latitude: probe.hasLocation ? probe.latitude : null,
        longitude: probe.hasLocation ? probe.longitude : null,
        width: probe.hasSize ? probe.width : null,
        height: probe.hasSize ? probe.height : null,
        source: MediaSource.dartProbe,
      );
    } catch (_) {
      // Un archivo corrupto no puede impedir que se listen los demás.
      return PhotoMetadata(path: path, source: MediaSource.dartProbe);
    }
  }

  /// Día de modificación, a medianoche local.
  static DateTime _modifiedDay(String path) {
    final ms = File(path).statSync().modified.millisecondsSinceEpoch;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime(d.year, d.month, d.day);
  }

  /// Encabezado de sección: `DD/MM/AAAA`.
  static String _formatDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Extensiones que la galería considera fotos.
  ///
  /// Vive aquí y no en `NexoraCore` porque es una decisión de la
  /// galería, no del motor: Rust no filtra por extensión al leer
  /// metadatos.
  static const Set<String> imageExtensions = {
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif', '.gif', '.bmp',
  };

  /// `true` si [path] parece una foto.
  static bool looksLikeImage(String path) =>
      imageExtensions.contains(p.extension(path).toLowerCase());
}

/// Una sección de la galería: un día con sus fotos.
class GallerySection {
  final String label;
  final DateTime? day;
  final List<String> paths;

  const GallerySection({
    required this.label,
    required this.day,
    required this.paths,
  });

  int get count => paths.length;

  /// La primera foto, para la portada de la sección.
  String? get cover => paths.isEmpty ? null : paths.first;
}
