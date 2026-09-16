import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_photos/src/rust/api.dart';
import 'package:nexora_photos/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('Rust core: escaneo, favoritos y álbumes', (tester) async {
    final root = await Directory.systemTemp.createTemp('nexora_it');
    final config = await Directory.systemTemp.createTemp('nexora_it_cfg');

    // 1x1 PNG válido (red)
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final png = File('${root.path}/foto.png');
    await png.writeAsBytes(pngBytes);

    final store = await PhotoStore.newInstance(configDir: config.path);

    final photos = await store.scanDirectory(root: root.path);
    expect(photos, isNotEmpty);
    expect(photos.first.width, 1);
    expect(photos.first.height, 1);

    await store.setFavorite(path: photos.first.path, isFavorite: true);
    expect(await store.favoritePaths(), [photos.first.path]);

    final album = await store.createAlbum(name: 'Prueba');
    final upd = await store.addPhotosToAlbum(
      albumId: album.id,
      photos: [photos.first.path],
    );
    expect(upd.photoPaths, hasLength(1));

    final thumb = await store.thumbnailBytes(path: photos.first.path, size: 256);
    expect(thumb, isNotNull);
    expect(thumb!.isNotEmpty, isTrue);

    await store.deletePhoto(path: photos.first.path);
    expect(File(photos.first.path).existsSync(), isFalse);
    expect(await store.favoritePaths(), isEmpty);
    final albumsAfter = await store.listAlbums();
    expect(albumsAfter.first.photoPaths, isEmpty);
  });

  testWidgets('Rust core: papelera, carpeta segura y videos', (tester) async {
    final root = await Directory.systemTemp.createTemp('nexora_it2');
    final config = await Directory.systemTemp.createTemp('nexora_it2_cfg');

    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    final png = File('${root.path}/foto.png');
    await png.writeAsBytes(pngBytes);
    final movie = File('${root.path}/clip.mp4');
    await movie.writeAsBytes([0, 0, 0, 0]);

    final store = await PhotoStore.newInstance(configDir: config.path);

    // Videos
    final videos = await store.scanVideos(root: root.path);
    expect(videos, hasLength(1));
    expect(videos.first.name, 'clip.mp4');

    // Papelera: mover, restaurar, borrar
    await store.moveToTrash(path: png.path);
    expect(File(png.path).existsSync(), isFalse);
    var trash = await store.listTrash();
    expect(trash, hasLength(1));
    await store.restoreTrash(name: trash.first.name);
    expect(File(png.path).existsSync(), isTrue);
    expect(await store.listTrash(), isEmpty);

    await store.moveToTrash(path: png.path);
    trash = await store.listTrash();
    await store.deleteTrashItem(name: trash.first.name);
    expect(await store.listTrash(), isEmpty);

    // Carpeta segura con PIN (se recrea el archivo tras borrarlo de la papelera)
    await png.writeAsBytes(pngBytes);
    expect(await store.pinIsSet(), isFalse);
    await store.setPin(pin: '1234');
    expect(await store.pinIsSet(), isTrue);
    expect(await store.verifyPin(pin: '1234'), isTrue);
    expect(await store.verifyPin(pin: '0000'), isFalse);

    await store.moveToSecure(path: png.path);
    expect(File(png.path).existsSync(), isFalse);
    var sec = await store.listSecure();
    expect(sec, hasLength(1));
    await store.restoreSecure(name: sec.first.name);
    expect(File(png.path).existsSync(), isTrue);

    await store.moveToSecure(path: png.path);
    sec = await store.listSecure();
    await store.deleteSecureItem(name: sec.first.name);
    expect(await store.listSecure(), isEmpty);
    await store.clearPin();
    expect(await store.pinIsSet(), isFalse);
  });
}