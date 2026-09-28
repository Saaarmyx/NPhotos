// lib/services/media_probe.dart
//
// Sonda ligera de metadatos (solo cabecera, sin decodificar la imagen).
//
// - Dimensiones para jpg/jpeg, png, gif y webp (VP8/VP8L/VP8X).
// - GPS EXIF (latitud/longitud) para jpg/jpeg (y heic best-effort)
//   vía `package:exif`.
//
// Puro Dart, sin imports de Flutter: apto para correr dentro del isolate
// de escaneo (`compute`) y para tests unitarios.
import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:path/path.dart' as p;

/// Resultado de la sonda. Todo nullable: lo que no se pudo leer queda null
/// y la UI lo oculta (nunca se inventan metadatos).
class MediaProbe {
  final int? width;
  final int? height;
  final double? latitude;
  final double? longitude;

  const MediaProbe({this.width, this.height, this.latitude, this.longitude});

  bool get hasSize => width != null && height != null;
  bool get hasLocation => latitude != null && longitude != null;

  double? get megapixels {
    if (!hasSize) return null;
    return width! * height! / 1000000.0;
  }
}

/// DMS (grados, minutos, segundos) + referencia ('N'/'S'/'E'/'W') → decimal.
double? gpsToDecimal(List<double> dms, String ref) {
  if (dms.length != 3) return null;
  if (!dms.every((v) => v.isFinite)) return null;
  var decimal = dms[0].abs() + dms[1].abs() / 60.0 + dms[2].abs() / 3600.0;
  if (!decimal.isFinite) return null;
  final upper = ref.trim().toUpperCase();
  if (upper == 'S' || upper == 'W') decimal = -decimal;
  return decimal;
}

/// Lee hasta [maxBytes] del inicio del archivo (síncrono, para isolates).
Uint8List? _headChunk(String path, int maxBytes) {
  try {
    final file = File(path);
    final raf = file.openSync(mode: FileMode.read);
    try {
      final length = raf.lengthSync();
      if (length <= 0) return null;
      return Uint8List.fromList(raf.readSync(length < maxBytes ? length : maxBytes));
    } finally {
      raf.closeSync();
    }
  } catch (_) {
    return null;
  }
}

int _u16be(Uint8List b, int i) => (b[i] << 8) | b[i + 1];
int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);
int _u32be(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

bool _has(Uint8List b, int need) => b.length >= need;

/// JPEG: recorre marcadores hasta el primer SOF (dimensiones reales).
({int width, int height})? _jpegSize(Uint8List b) {
  if (!_has(b, 4) || b[0] != 0xFF || b[1] != 0xD8) return null;
  const sof = {
    0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
    0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF,
  };
  var i = 2;
  while (i + 4 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    // Salta relleno 0xFF.
    while (i < b.length && b[i] == 0xFF) {
      i++;
    }
    if (i >= b.length) return null;
    final marker = b[i];
    i++;
    // Sin payload: SOI, EOI, RSTn, TEM.
    if (marker == 0xD8 || marker == 0xD9 || marker == 0x01) continue;
    if (marker >= 0xD0 && marker <= 0xD7) continue;
    if (i + 2 > b.length) return null;
    final length = _u16be(b, i);
    if (length < 2 || i + length > b.length + 2) {
      // El SOF puede estar más allá del chunk: se reporta desconocido.
      return null;
    }
    if (sof.contains(marker)) {
      if (length < 7 || i + 6 >= b.length) return null;
      final height = _u16be(b, i + 3);
      final width = _u16be(b, i + 5);
      if (width <= 0 || height <= 0) return null;
      return (width: width, height: height);
    }
    i += length;
  }
  return null;
}

({int width, int height})? _pngSize(Uint8List b) {
  if (!_has(b, 24)) return null;
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var k = 0; k < 8; k++) {
    if (b[k] != sig[k]) return null;
  }
  if (b[12] != 0x49 || b[13] != 0x48 || b[14] != 0x44 || b[15] != 0x52) {
    return null;
  }
  final width = _u32be(b, 16);
  final height = _u32be(b, 20);
  if (width <= 0 || height <= 0) return null;
  return (width: width, height: height);
}

({int width, int height})? _gifSize(Uint8List b) {
  if (!_has(b, 10)) return null;
  final isGif =
      b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38;
  if (!isGif) return null;
  final width = _u16le(b, 6);
  final height = _u16le(b, 8);
  if (width <= 0 || height <= 0) return null;
  return (width: width, height: height);
}

({int width, int height})? _webpSize(Uint8List b) {
  if (!_has(b, 30)) return null;
  final riff =
      b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46;
  final webp =
      b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50;
  if (!riff || !webp) return null;
  final fourcc = String.fromCharCodes(b.sublist(12, 16));
  switch (fourcc) {
    case 'VP8 ':
      if (!_has(b, 30)) return null;
      final width = _u16le(b, 26) & 0x3FFF;
      final height = _u16le(b, 28) & 0x3FFF;
      if (width <= 0 || height <= 0) return null;
      return (width: width, height: height);
    case 'VP8L':
      if (!_has(b, 25)) return null;
      final bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
      final width = (bits & 0x3FFF) + 1;
      final height = ((bits >> 14) & 0x3FFF) + 1;
      return (width: width, height: height);
    case 'VP8X':
      if (!_has(b, 30)) return null;
      final width =
          (b[24] | (b[25] << 8) | (b[26] << 16)) + 1;
      final height =
          (b[27] | (b[28] << 8) | (b[29] << 16)) + 1;
      return (width: width, height: height);
    default:
      return null;
  }
}

double? _ratioToDouble(Object? value) {
  if (value is Ratio) {
    if (value.denominator == 0) return null;
    return value.numerator / value.denominator;
  }
  if (value is num) return value.toDouble();
  return null;
}

/// Extrae (lat, lng) de tags EXIF ya parseados. Null si no hay GPS.
({double lat, double lng})? gpsFromExif(Map<String, IfdTag> tags) {
  final latTag = tags['GPS GPSLatitude'];
  final latRef = tags['GPS GPSLatitudeRef']?.printable ?? 'N';
  final lngTag = tags['GPS GPSLongitude'];
  final lngRef = tags['GPS GPSLongitudeRef']?.printable ?? 'E';
  if (latTag == null || lngTag == null) return null;
  final latParts = [
    for (final v in latTag.values.toList()) _ratioToDouble(v),
  ];
  final lngParts = [
    for (final v in lngTag.values.toList()) _ratioToDouble(v),
  ];
  if (latParts.length != 3 ||
      lngParts.length != 3 ||
      latParts.any((v) => v == null) ||
      lngParts.any((v) => v == null)) {
    return null;
  }
  final lat = gpsToDecimal(latParts.cast<double>(), latRef);
  final lng = gpsToDecimal(lngParts.cast<double>(), lngRef);
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return (lat: lat, lng: lng);
}

/// Sonda completa de un archivo de imagen. Nunca lanza.
Future<MediaProbe?> probeImageFile(String path) async {
  final ext = p.extension(path).toLowerCase();
  final isHeic = ext == '.heic';
  if (ext == '.gif' || ext == '.webp' || ext == '.png' || ext == '.jpg' || ext == '.jpeg' || isHeic) {
    // Nada: sigue abajo.
  } else {
    return null;
  }
  try {
    final chunk = _headChunk(path, isHeic ? 1024 * 1024 : 256 * 1024);
    if (chunk == null) return null;

    ({int width, int height})? size;
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        size = _jpegSize(chunk);
        break;
      case '.png':
        size = _pngSize(chunk);
        break;
      case '.gif':
        size = _gifSize(chunk);
        break;
      case '.webp':
        size = _webpSize(chunk);
        break;
      case '.heic':
        size = null; // El meta-box HEIC varía: se omite a propósito.
        break;
    }

    double? lat;
    double? lng;
    if (ext == '.jpg' || ext == '.jpeg' || isHeic) {
      try {
        final tags = await readExifFromBytes(chunk);
        final gps = gpsFromExif(tags);
        lat = gps?.lat;
        lng = gps?.lng;
      } catch (_) {
        // EXIF ausente o más allá del chunk: sin ubicación.
      }
    }
    if (size == null && lat == null) return null;
    return MediaProbe(
      width: size?.width,
      height: size?.height,
      latitude: lat,
      longitude: lng,
    );
  } catch (_) {
    return null;
  }
}
