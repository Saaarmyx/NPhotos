import 'photo_repo_helper.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/controllers/gallery_controller.dart';
import 'package:NexoraCore/NexoraCore.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

// Construye un JPEG mínimo con EXIF GPS:
// 12°34'56"N, 65°43'21"E + SOF0 de 16x16.
Uint8List gpsJpeg() {
  final tiff = BytesBuilder();
  // TIFF header LE.
  tiff.add([0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00]);
  // IFD0: 1 entrada (puntero GPS).
  tiff.add([0x01, 0x00]);
  tiff.add([
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x1A, 0x00, 0x00, 0x00, // offset 26
  ]);
  tiff.add([0x00, 0x00, 0x00, 0x00]); // next IFD
  // GPS IFD en 26: 4 entradas.
  tiff.add([0x04, 0x00]);
  // LatRef 'N'.
  tiff.add([
    0x01, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00,
    0x4E, 0x00, 0x00, 0x00,
  ]);
  // Lat RATIONAL x3 en offset 80.
  tiff.add([
    0x02, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00,
    0x50, 0x00, 0x00, 0x00,
  ]);
  // LngRef 'E'.
  tiff.add([
    0x03, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00,
    0x45, 0x00, 0x00, 0x00,
  ]);
  // Lng RATIONAL x3 en offset 104.
  tiff.add([
    0x04, 0x00, 0x05, 0x00, 0x03, 0x00, 0x00, 0x00,
    0x68, 0x00, 0x00, 0x00,
  ]);
  tiff.add([0x00, 0x00, 0x00, 0x00]); // next IFD
  // Datos lat: 12/1, 34/1, 5600/100.
  for (final r in [(12, 1), (34, 1), (5600, 100)]) {
    tiff.add(_u32le(r.$1));
    tiff.add(_u32le(r.$2));
  }
  // Datos lng: 65/1, 43/1, 2100/100.
  for (final r in [(65, 1), (43, 1), (2100, 100)]) {
    tiff.add(_u32le(r.$1));
    tiff.add(_u32le(r.$2));
  }
  final tiffBytes = tiff.toBytes();
  assert(tiffBytes.length == 128);

  final jpg = BytesBuilder();
  jpg.add([0xFF, 0xD8]);
  final app1len = 2 + 6 + tiffBytes.length;
  jpg.add([0xFF, 0xE1, app1len >> 8, app1len & 0xFF]);
  jpg.add([...'Exif'.codeUnits, 0x00, 0x00]);
  jpg.add(tiffBytes);
  // SOF0 16x16.
  jpg.add([0xFF, 0xC0, 0x00, 0x08, 0x08, 0x00, 0x10, 0x00, 0x10]);
  return jpg.toBytes();
}

List<int> _u32le(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

Uint8List pngBytes(int w, int h) {
  final b = BytesBuilder();
  b.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  b.add([0x00, 0x00, 0x00, 0x0D]);
  b.add('IHDR'.codeUnits);
  for (final v in [w, h]) {
    b.add([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
  }
  b.add([0x08, 0x02, 0x00, 0x00, 0x00]);
  return b.toBytes();
}

void main() {
  group('gpsToDecimal', () {
    test('convierte DMS con referencia', () {
      expect(gpsToDecimal([12, 34, 56], 'N'), closeTo(12.5822, 0.0001));
      expect(gpsToDecimal([65, 43, 21], 'E'), closeTo(65.7225, 0.0001));
      expect(gpsToDecimal([12, 34, 56], 'S'), closeTo(-12.5822, 0.0001));
      expect(gpsToDecimal([65, 43, 21], 'W'), closeTo(-65.7225, 0.0001));
    });

    test('rechaza entradas inválidas', () {
      expect(gpsToDecimal([12, 34], 'N'), isNull);
      expect(
        gpsToDecimal([double.nan, 0, 0], 'N'),
        isNull,
      );
    });
  });

  group('gpsFromExif', () {
    test('extrae lat/lng de tags sintéticos', () async {
      final tags = await readExifFromBytes(gpsJpeg());
      final gps = gpsFromExif(tags);
      expect(gps, isNotNull);
      expect(gps!.lat, closeTo(12.5822, 0.0001));
      expect(gps.lng, closeTo(65.7225, 0.0001));
    });

    test('null sin GPS', () {
      expect(gpsFromExif({}), isNull);
    });
  });

  group('probeImageFile', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('nphotos_probe');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('jpeg con GPS: dimensiones + ubicación', () async {
      final file = File(p.join(tmp.path, 'foto.jpg'));
      await file.writeAsBytes(gpsJpeg());
      final probe = await probeImageFile(file.path);
      expect(probe, isNotNull);
      expect(probe!.width, 16);
      expect(probe.height, 16);
      expect(probe.latitude, closeTo(12.5822, 0.0001));
      expect(probe.longitude, closeTo(65.7225, 0.0001));
    });

    test('png gigante: dimensiones sin ubicación', () async {
      final file = File(p.join(tmp.path, 'hd.png'));
      await file.writeAsBytes(pngBytes(4000, 3000));
      final probe = await probeImageFile(file.path);
      expect(probe, isNotNull);
      expect(probe!.width, 4000);
      expect(probe.height, 3000);
      expect(probe.hasLocation, isFalse);
      expect(probe.megapixels, closeTo(12.0, 0.001));
    });

    test('extensión no soportada → null', () async {
      final file = File(p.join(tmp.path, 'clip.mp4'));
      await file.writeAsBytes(List.filled(64, 0));
      expect(await probeImageFile(file.path), isNull);
    });
  });

  group('Colecciones y privada (controlador)', () {
    late Directory tmp;
    late Directory vault;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('nphotos_coll');
      vault = Directory(p.join(tmp.path, '.vault'));
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<File> image(String rel, {List<int>? bytes}) async {
      final file = File(p.join(tmp.path, rel));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes ?? List.filled(64, 1));
      return file;
    }

    GalleryController controller() => GalleryController(
      photos: testPhotoRepository(root: tmp.path),
      privateDirOverride: vault,
    );

    test('escaneo puebla dimensiones, ubicación y colecciones', () async {
      await image('Camera/selfie_01.jpg');
      await image('Documents/scan_doc.jpg');
      await image('Camera/hd.png', bytes: pngBytes(4000, 3000).toList());
      final gps = File(p.join(tmp.path, 'Camera', 'trip.jpg'));
      await gps.parent.create(recursive: true);
      await gps.writeAsBytes(gpsJpeg());

      final c = controller();
      await c.fetchPhotos();
      expect(c.state, GalleryState.loaded);

      final trip = c.photos.firstWhere((e) => e.title == 'trip.jpg');
      expect(trip.hasLocation, isTrue);
      expect(trip.locationLabel, '12.5822, 65.7225');
      expect(c.photosWithLocation.map((e) => e.title), contains('trip.jpg'));
      expect(c.locationGroups.keys.first, '12.58, 65.72');

      expect(c.peoplePhotos.map((e) => e.title), contains('selfie_01.jpg'));
      expect(
        c.documentPhotos.map((e) => e.title),
        contains('scan_doc.jpg'),
      );
      expect(c.hdPhotos.map((e) => e.title), contains('hd.png'));
      // Recién creados: dentro de la ventana de 7 días.
      expect(c.recentWeek.length, c.photos.length);
    });

    test('privada: mover y restaurar conserva favorito y origen', () async {
      final file = await image('Camera/a.jpg');
      final c = controller();
      await c.fetchPhotos();
      await c.toggleFavorite(file.path);

      await c.moveToPrivate(file.path);
      expect(c.photos, isEmpty);
      expect(c.privatePhotos.length, 1);
      expect(c.privatePhotos.single.isFavorite, isTrue);
      expect(await file.exists(), isFalse);

      await c.restoreFromPrivate(c.privatePhotos.single.id);
      expect(c.privatePhotos, isEmpty);
      expect(c.photos.length, 1);
      expect(c.photos.single.path, file.path);
      expect(await File(file.path).exists(), isTrue);
    });
  });
}
