import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/services/local_store.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('nphotos_ctrl_test');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> image(String name, {int size = 16}) async {
    final file = File(p.join(tmp.path, name));
    await file.writeAsBytes(List.filled(size, 1));
    return file;
  }

  GalleryController controller() => GalleryController(
    photoService: PhotoService(roots: [tmp]),
  );

  group('GalleryController', () {
    test('carga solo imágenes válidas no vacías ni ocultas', () async {
      await image('a.jpg');
      await image('b.png');
      await image('c.txt');
      await image('.hidden.jpg');
      await image('empty.jpg', size: 0);

      final c = controller();
      await c.fetchPhotos();

      expect(c.state, GalleryState.loaded);
      expect(
        c.photos.map((photo) => photo.title).toSet(),
        {'a.jpg', 'b.png'},
      );
    });

    test('el favorito persiste entre instancias', () async {
      final file = await image('a.jpg');

      final first = controller();
      await first.fetchPhotos();
      await first.toggleFavorite(file.path);
      expect(
        first.photos.singleWhere((p) => p.id == file.path).isFavorite,
        isTrue,
      );

      final second = controller();
      await second.fetchPhotos();
      expect(
        second.photos.singleWhere((p) => p.id == file.path).isFavorite,
        isTrue,
      );
    });

    test('papelera: mover, restaurar y vaciar', () async {
      await image('a.jpg');
      await image('b.png');

      final c = controller();
      await c.fetchPhotos();
      expect(c.photos.length, 2);

      await c.moveToTrash(p.join(tmp.path, 'a.jpg'));
      expect(c.photos.length, 1);
      expect(c.trash.length, 1);
      expect(c.albums.expand((a) => a.photos).length, 1);

      await c.restoreFromTrash(p.join(tmp.path, 'a.jpg'));
      expect(c.photos.length, 2);
      expect(c.trash, isEmpty);

      await c.moveToTrash(p.join(tmp.path, 'a.jpg'));
      await c.moveToTrash(p.join(tmp.path, 'b.png'));
      await c.emptyTrash();
      expect(c.trash, isEmpty);
      expect(await File(p.join(tmp.path, 'a.jpg')).exists(), isFalse);
      expect(await File(p.join(tmp.path, 'b.png')).exists(), isFalse);
    });

    test('borrado permanente elimina el archivo', () async {
      final file = await image('a.jpg');

      final c = controller();
      await c.fetchPhotos();
      await c.moveToTrash(file.path);
      await c.deletePermanently(file.path);

      expect(c.trash, isEmpty);
      expect(await file.exists(), isFalse);
    });

    test('poda registros de archivos que ya no existen', () async {
      final file = await image('a.jpg');

      final c = controller();
      await c.fetchPhotos();
      await c.toggleFavorite(file.path);
      await file.delete();

      await c.fetchPhotos();
      expect(c.photos, isEmpty);

      final store = await LocalStore.load();
      expect(store.favoriteIds(), isEmpty);
    });
  });
}
