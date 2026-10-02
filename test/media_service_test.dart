// test/media_service_test.dart
//
// La conexión de NPhotos con la capa de medios de NexoraCore.
//
// Lo que se comprueba aquí es el contrato de degradación: la galería
// tiene que funcionar con motor nativo, sin él, y con archivos rotos,
// sin que nada lance. Si esto falla, la app se queda sin galería en una
// máquina sin Rust.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/services/media_service.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nphotos_media_test');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('el servicio se construye y degrada', () {
    test('sin .so no lanza y explica por qué', () {
      final service = MediaService();
      // Con o sin motor, esto no lanza: es la degradación documentada.
      expect(service.hasNativeEngine, isA<bool>());
      if (!service.hasNativeEngine) {
        expect(service.unavailableReason, isNotNull);
      }
    });

    test('el perfil de rendimiento se acepta sin lanzar', () {
      final service = MediaService();
      for (final id in [0, 1, 2]) {
        expect(() => service.setPerformanceProfile(id), returnsNormally);
      }
    });

    test('listas vacías devuelven vacío sin tocar el motor', () async {
      final service = MediaService();
      expect(await service.loadMetadata(const []), isEmpty);
      expect(await service.loadThumbnails(const []), isEmpty);
      expect(await service.groupByDay(const []), isEmpty);
    });
  });

  group('loadMetadata nunca pierde una foto', () {
    test('con archivos reales devuelve una entrada por foto', () async {
      final service = MediaService();
      final paths = [
        _writePng('${tmp.path}/a.png'),
        _writePng('${tmp.path}/b.png'),
      ];
      final meta = await service.loadMetadata(paths);
      // Un archivo ilegible sale con campos vacíos, NO desaparece: la
      // galería ya sabe que existe y borrarla de la lista sería peor.
      expect(meta.length, paths.length);
      for (final p in paths) {
        expect(meta.containsKey(p), isTrue);
      }
    });

    test('un archivo que no existe sale vacío y no rompe el lote', () async {
      final service = MediaService();
      final good = _writePng('${tmp.path}/ok.png');
      final roto = '${tmp.path}/no_existe.png';

      final meta = await service.loadMetadata([good, roto]);
      expect(meta.length, 2, reason: 'ambos deben aparecer');
      expect(meta[roto]!.hasAnything, isFalse,
          reason: 'sin datos, no se inventa ninguno');
    });

    test('basura en vez de imagen no lanza', () async {
      final service = MediaService();
      final basura = File('${tmp.path}/basura.png')
        ..writeAsStringSync('esto no es una imagen');
      final meta = await service.loadMetadata([basura.path]);
      expect(meta.length, 1);
      expect(meta[basura.path]!.hasAnything, isFalse);
    });
  });

  group('groupByDay', () {
    test('agrupa en secciones con etiqueta y contenido', () async {
      final service = MediaService();
      final paths = [
        _writePng('${tmp.path}/x1.png'),
        _writePng('${tmp.path}/x2.png'),
      ];
      final sections = await service.groupByDay(paths);
      expect(sections, isNotEmpty);
      expect(sections.first.label, isNotEmpty);
      expect(sections.first.count, greaterThan(0));
      expect(sections.first.cover, isNotNull);
      // Todas las secciones juntas cubren las fotos.
      final total = sections.fold<int>(0, (a, s) => a + s.count);
      expect(total, paths.length);
    });

    test('la etiqueta tiene formato DD/MM/AAAA', () async {
      final service = MediaService();
      final sections = await service.groupByDay([_writePng('${tmp.path}/f.png')]);
      expect(sections.first.label, matches(RegExp(r'^\d{2}/\d{2}/\d{4}$')));
    });
  });

  group('loadThumbnails', () {
    test('devuelve un mapa por ruta original', () async {
      final service = MediaService();
      final paths = [_writePng('${tmp.path}/t1.png')];
      final thumbs = await service.loadThumbnails(paths);
      // Sin motor: vacío. Con motor: la ruta del JPEG. Ambas son
      // válidos; lo que no vale es lanzar o devolver basura.
      expect(thumbs, isA<Map<String, String>>());
      for (final entry in thumbs.entries) {
        expect(paths.contains(entry.key), isTrue,
            reason: 'la clave debe ser la ruta original');
        expect(File(entry.value).existsSync(), isTrue,
            reason: 'la miniatura debe existir en disco');
      }
    });

    test('sin motor devuelve vacío, no rutas rotas', () async {
      final service = MediaService();
      final thumbs = await service.loadThumbnails(
        [_writePng('${tmp.path}/t2.png')],
      );
      if (!service.hasNativeEngine) {
        expect(thumbs, isEmpty,
            reason: 'sin motor no debe inventar rutas de miniatura');
      }
    });
  });

  group('PhotoMetadata', () {
    test('hasAnything refleja si hay algo que enseñar', () {
      const vacio = PhotoMetadata(path: '/a.jpg');
      expect(vacio.hasAnything, isFalse);

      final conFecha = PhotoMetadata(
        path: '/a.jpg',
        capturedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
      expect(conFecha.hasAnything, isTrue);

      const conGps = PhotoMetadata(path: '/a.jpg', latitude: 1.0);
      expect(conGps.hasAnything, isTrue);

      const conTamano = PhotoMetadata(path: '/a.jpg', width: 100);
      expect(conTamano.hasAnything, isTrue);
    });

    test('el origen del dato queda registrado para depurar', () {
      const nativa = PhotoMetadata(path: '/a.jpg', source: MediaSource.native);
      const dart = PhotoMetadata(path: '/a.jpg', source: MediaSource.dartProbe);
      expect(nativa.source, isNot(dart.source));
    });
  });

  group('el filtro de extensiones', () {
    test('reconoce los formatos habituales de foto', () {
      for (final ext in ['.jpg', '.JPG', '.png', '.webp', '.heic']) {
        expect(MediaService.looksLikeImage('/x/foto$ext'), isTrue,
            reason: 'debe aceptar $ext');
      }
    });

    test('rechaza lo que no es una foto', () {
      for (final ext in ['.mp4', '.txt', '.zip']) {
        expect(MediaService.looksLikeImage('/x/f$ext'), isFalse,
            reason: 'no debe aceptar $ext');
      }
    });
  });
}

/// Escribe un PNG 1x1 válido.
///
/// Se construye a mano en lugar de tirar de un paquete de imágenes:
/// lo que se prueba es el fallback de metadatos, no la decodificación.
String _writePng(String path) {
  const png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
  return (File(path)..writeAsBytesSync(base64Decode(png))).path;
}
