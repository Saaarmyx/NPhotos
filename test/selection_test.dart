import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/controllers/selection_controller.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SelectionController', () {
    late SelectionController s;

    setUp(() => s = SelectionController());
    tearDown(() => s.dispose());

    test('empieza inactiva', () {
      expect(s.isActive, isFalse);
      expect(s.count, 0);
      expect(s.kind, SelectionKind.photos);
    });

    test('selectOnly activa y reemplaza la selección anterior', () {
      s.selectOnly('a');
      expect(s.isActive, isTrue);
      expect(s.count, 1);
      expect(s.isSelected('a'), isTrue);

      s.selectOnly('b');
      expect(s.count, 1);
      expect(s.isSelected('a'), isFalse);
      expect(s.isSelected('b'), isTrue);
    });

    test('toggle añade y quita', () {
      s.selectOnly('a');
      s.toggle('b');
      expect(s.count, 2);
      s.toggle('a');
      expect(s.isSelected('a'), isFalse);
      expect(s.count, 1);
    });

    test('selectAll y clear', () {
      s.selectAll(['a', 'b', 'c']);
      expect(s.count, 3);
      expect(s.isAllSelected(['a', 'b', 'c']), isTrue);
      // Pregunta por esos ids concretos: si 'd' no está, no están todos.
      expect(s.isAllSelected(['a', 'b', 'd']), isFalse);
      expect(s.isAllSelected(<String>[]), isFalse);
      s.clear();
      expect(s.isActive, isFalse);
    });

    test('notifica en cada cambio y no en redundancias', () {
      var calls = 0;
      s.addListener(() => calls++);
      s.selectOnly('a');
      s.toggle('b');
      s.clear();
      expect(calls, 3);
      s.clear(); // ya vacío: no notifica
      expect(calls, 3);
    });

    test('cambiar de tipo limpia la selección', () {
      s.selectOnly('a', kind: SelectionKind.photos);
      s.selectOnly('b', kind: SelectionKind.albums);
      expect(s.kind, SelectionKind.albums);
      expect(s.count, 1);
      expect(s.isSelected('a'), isFalse);
    });
  });

  group('Acciones en lote', () {
    late Directory tmp;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('nphotos_batch');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<String> image(String name) async {
      final f = File(p.join(tmp.path, name));
      await f.writeAsBytes(List.filled(16, 1));
      return f.path;
    }

    Future<GalleryController> loaded() async {
      final c = GalleryController(photoService: PhotoService(roots: [tmp]));
      await c.fetchPhotos();
      return c;
    }

    test('toggleFavoritesBatch marca todos y luego quita', () async {
      final a = await image('a.jpg');
      final b = await image('b.jpg');
      final c = await loaded();

      await c.toggleFavoritesBatch([a, b]);
      expect(
        c.photos.where((p) => p.isFavorite).map((p) => p.path).toSet(),
        {a, b},
      );

      // Todos ya son favoritos: la siguiente llamada los quita.
      await c.toggleFavoritesBatch([a, b]);
      expect(c.photos.where((p) => p.isFavorite), isEmpty);
      c.dispose();
    });

    test('toggleFavoritesBatch: si alguna no es favorita, marca todas', () async {
      final a = await image('a.jpg');
      final b = await image('b.jpg');
      final c = await loaded();
      await c.toggleFavorite(a);
      expect(c.photos.firstWhere((p) => p.path == a).isFavorite, isTrue);

      // No todas son favoritas → el lote se marca completo.
      await c.toggleFavoritesBatch([a, b]);
      expect(c.photos.where((p) => p.isFavorite).length, 2);

      // Ahora todas son favoritas → el siguiente toggle las quita.
      await c.toggleFavoritesBatch([a, b]);
      expect(c.photos.where((p) => p.isFavorite), isEmpty);
      c.dispose();
    });

    test('moveToTrashBatch manda varios y los persiste', () async {
      final a = await image('a.jpg');
      final b = await image('b.jpg');
      final c = await loaded();
      expect(c.photos.length, 2);

      await c.moveToTrashBatch([a, b]);
      expect(c.photos, isEmpty);
      expect(c.trash.length, 2);

      // Persiste: otra instancia los ve en la papelera.
      final other = await loaded();
      expect(other.trash.length, 2);
      c.dispose();
      other.dispose();
    });

    test('deletePermanentlyBatch borra los archivos', () async {
      final a = await image('a.jpg');
      final b = await image('b.jpg');
      final c = await loaded();
      await c.moveToTrashBatch([a, b]);

      await c.deletePermanentlyBatch([a]);
      expect(c.trash.length, 1);
      expect(File(a).existsSync(), isFalse);
      expect(File(b).existsSync(), isTrue);
      c.dispose();
    });

    test('restoreFromTrashBatch devuelve varios a la galería', () async {
      final a = await image('a.jpg');
      final b = await image('b.jpg');
      final c = await loaded();
      await c.moveToTrashBatch([a, b]);
      expect(c.photos, isEmpty);

      await c.restoreFromTrashBatch([a, b]);
      expect(c.photos.length, 2);
      expect(c.trash, isEmpty);
      c.dispose();
    });

    test('lotes vacíos o inexistentes no rompen', () async {
      await image('a.jpg');
      final c = await loaded();
      await c.moveToTrashBatch([]);
      await c.toggleFavoritesBatch(['/no/existe.jpg']);
      await c.deletePermanentlyBatch(['/no/existe.jpg']);
      expect(c.photos.length, 1);
      expect(c.trash, isEmpty);
      c.dispose();
    });
  });
}
