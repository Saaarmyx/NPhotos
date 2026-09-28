import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nphotos/controllers/gallery_controller.dart';
import 'package:nphotos/services/photo_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('nphotos_pref');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> image(String dir, String name) async {
    final d = Directory(p.join(tmp.path, dir));
    await d.create();
    final f = File(p.join(d.path, name));
    await f.writeAsBytes(List.filled(16, 1));
    return f;
  }

  Future<GalleryController> loaded() async {
    final c = GalleryController(photoService: PhotoService(roots: [tmp]));
    await c.fetchPhotos();
    return c;
  }

  Album albumNamed(GalleryController c, String name) =>
      c.albums.firstWhere((a) => a.name == name);

  test('ocultar saca el álbum de la parrilla y lo devuelve', () async {
    await image('Viajes', 'a.jpg');
    await image('Familia', 'b.jpg');
    await image('Docs', 'c.jpg');
    final c = await loaded();
    final viajes = albumNamed(c, 'Viajes');

    expect(c.unpinnedAlbums.map((a) => a.name), contains('Viajes'));

    await c.setAlbumHidden(viajes.path, true);
    expect(c.hiddenAlbums.map((a) => a.name), contains('Viajes'));
    expect(c.unpinnedAlbums.map((a) => a.name), isNot(contains('Viajes')));

    await c.setAlbumHidden(viajes.path, false);
    expect(c.hiddenAlbums, isEmpty);
    expect(c.unpinnedAlbums.map((a) => a.name), contains('Viajes'));
    c.dispose();
  });

  test('cambiar carátula persiste y se usa como portada', () async {
    final a = await image('Viajes', 'a.jpg');
    final b = await image('Viajes', 'b.jpg');
    final c = await loaded();
    final viajes = albumNamed(c, 'Viajes');

    // Por defecto: la primera foto.
    expect(viajes.coverPhoto.path, isNot(a.path));

    await c.setAlbumCover(viajes.path, a.path);
    final updated = albumNamed(c, 'Viajes');
    expect(updated.coverPhoto.path, a.path);
    expect(updated.customCover, a.path);
    // La otra foto sigue en el álbum.
    expect(updated.photos.map((p) => p.path), contains(b.path));
    c.dispose();
  });

  test('renombrar actualiza el nombre del álbum', () async {
    await image('Viajes', 'a.jpg');
    final c = await loaded();
    final path = p.join(tmp.path, 'Viajes');

    expect(await c.renameAlbum(path, 'Recuerdos'), isTrue);
    // La carpeta se renombró en disco: la ruta también cambia.
    expect(albumNamed(c, 'Recuerdos').path, p.join(tmp.path, 'Recuerdos'));
    expect(Directory(p.join(tmp.path, 'Recuerdos')).existsSync(), isTrue);
    expect(c.albums.map((a) => a.name), isNot(contains('Viajes')));
    c.dispose();
  });

  test('eliminar borra la carpeta y quita el pin', () async {
    await image('Viajes', 'a.jpg');
    await image('Familia', 'b.jpg');
    await image('Docs', 'c.jpg');
    final c = await loaded();
    final viajes = albumNamed(c, 'Viajes');
    await c.togglePin('album:${viajes.path}');
    expect(c.isPinned('album:${viajes.path}'), isTrue);

    expect(await c.deleteAlbum(viajes.path), isTrue);
    expect(Directory(viajes.path).existsSync(), isFalse);
    expect(c.isPinned('album:${viajes.path}'), isFalse);
    expect(c.albums.map((a) => a.name), isNot(contains('Viajes')));
    c.dispose();
  });

  test('las preferencias sobreviven a otra instancia', () async {
    await image('Viajes', 'a.jpg');
    final first = await loaded();
    await first.setAlbumHidden(p.join(tmp.path, 'Viajes'), true);
    first.dispose();

    final second = await loaded();
    expect(second.hiddenAlbums.map((a) => a.name), contains('Viajes'));
    second.dispose();
  });
}
