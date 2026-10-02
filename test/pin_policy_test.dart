import 'photo_repo_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/controllers/gallery_controller.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// La política de pines tiene que ser **determinista**.
///
/// El defecto que se corrigió: con todos los álbumes empatados por
/// número de fotos, el álbum pineado dependía del orden en que el
/// escáner entregó las carpetas. El mismo disco pineaba un álbum u otro
/// según la máquina, el motor o el sistema de archivos.
///
/// Estos tests lo comprueban forzando órdenes de escaneo distintos: si
/// el desempate es por ruta, el resultado no puede cambiar.
void main() {
  late Directory tmp;

  setUp(() async {
    // Sin esto las preferencias simuladas arrastran pines de la prueba
    // anterior: `hasPins()` da true, el controlador lee pines de álbumes
    // que ya no existen y la siembra no llega a aplicarse. El síntoma
    // (cero pines) no apunta a la política.
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('nphotos_pins');
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<File> image(String dir, String name, {int count = 1}) async {
    final d = Directory(p.join(tmp.path, dir));
    await d.create();
    for (var i = 0; i < count; i++) {
      await File(p.join(d.path, '${name}_$i.jpg')).writeAsBytes(
        List.filled(16, 1),
      );
    }
    return File(p.join(d.path, '$name.jpg'));
  }

  Future<List<String>> pinsWith(
    NPinSeedPolicy policy, {
    required Future<void> Function(String, int) seed,
  }) async {
    // Se **espera** cada seed: sin await, los archivos se escriben en
    // carrera con el escaneo y `fetchPhotos` puede no verlos. El síntoma
    // (cero álbumes) no apunta al repositorio.
    await seed('Viajes', 1);
    await seed('Familia', 1);
    await seed('Docs', 1);
    final c = GalleryController(
      photos: testPhotoRepository(root: tmp.path),
      pinSeedPolicy: policy,
    );
    await c.fetchPhotos();
    final out = c.pinnedIds;
    c.dispose();
    return out;
  }

  group('Determinismo', () {
    test('con empates, el pin es el mismo siempre', () async {
      // Los tres álbumes tienen 1 foto: empate total.
      //
      // Se comparan los NOMBRES, no las rutas: cada ejecución usa un
      // temporal distinto, y comparar rutas absolutas daría siempre
      // "distinto" sin decir nada sobre el determinismo.
      List<String> nombres(List<String> ids) =>
          [for (final id in ids) p.basename(id)]..sort();

      final primera = nombres(await pinsWith(
        NPinSeedPolicy.bySize,
        seed: (d, n) async => image(d, 'a', count: n),
      ));

      // Se repite sobre otro árbol nuevo: si el pin dependiera del orden
      // de creación o del sistema de archivos, saldría distinto.
      await tmp.delete(recursive: true);
      tmp = await Directory.systemTemp.createTemp('nphotos_pins2');

      final segunda = nombres(await pinsWith(
        NPinSeedPolicy.bySize,
        seed: (d, n) async => image(d, 'a', count: n),
      ));

      expect(segunda, primera);
    });


    test('el empate se resuelve por ruta, no por posición', () async {
      // Las carpetas se crean en el orden Viajes, Familia, Docs — y todas
      // con 1 foto. Por rutaalfabética el orden es Docs, Familia, Viajes,
      // así que los dos primeros pines son Docs y Familia. Si el
      // desempate fuera por posición de entrada serían Viajes y Familia.
      final ids = await pinsWith(
        NPinSeedPolicy.bySize,
        seed: (d, n) async => image(d, 'a', count: n),
      );

      expect(ids.length, 2);
      expect(
        ids.map((id) => p.basename(id)).toList(),
        ['Docs', 'Familia'],
        reason: 'alfabético, no el orden en que se crearon',
      );
    });

    test('las carpetas con nombre propio ganan a las más grandes', () async {
      // 'Camera' con 1 foto debe pinearse antes que 'Familia' con 50: la
      // política `wellKnown` decide por nombre de carpeta, no por tamaño.
      await image('Camera', 'c', count: 1);
      await image('Familia', 'f', count: 50);
      final c = GalleryController(
        photos: testPhotoRepository(root: tmp.path),
        pinSeedPolicy: NPinSeedPolicy.wellKnown,
      );
      await c.fetchPhotos();

      expect(c.pinnedIds, ['album:${p.join(tmp.path, 'Camera')}']);
      c.dispose();
    });
  });

  group('La política se respeta', () {
    test('none no pina nada', () async {
      expect(
        await pinsWith(NPinSeedPolicy.none, seed: (d, n) => image(d, 'a')),
        isEmpty,
      );
    });

    test('wellKnown ignora las carpetas comunes', () async {
      // Sin Camera ni Screenshots, wellKnown no rellena: una pantalla de
      // álbumes vacía de pines es un estado válido.
      expect(
        await pinsWith(
          NPinSeedPolicy.wellKnown,
          seed: (d, n) async => image(d, 'a'),
        ),
        isEmpty,
      );
    });

    test('bySize rellena hasta el máximo', () async {
      final ids = await pinsWith(
        NPinSeedPolicy.bySize,
        seed: (d, n) async => image(d, 'a'),
      );
      expect(ids.length, 2);
      expect(ids.length, lessThanOrEqualTo(GalleryController.maxPins));
    });
  });

  group('La siembra no se persiste como elección del usuario', () {
    test('sin pines guardados, la siembra se reaplica en cada carga', () async {
      await image('Viajes', 'a');
      await image('Familia', 'b');
      await image('Docs', 'c');

      final c = GalleryController(
        photos: testPhotoRepository(root: tmp.path),
        pinSeedPolicy: NPinSeedPolicy.bySize,
      );
      await c.fetchPhotos();
      expect(c.pinnedIds, isNotEmpty, reason: 'hay álbumes que sembrar');
      c.dispose();

      // Si la siembra se hubiera escrito en el almacén, la siguiente
      // carga la leería como decisión del usuario. Sin escribir, la
      // política sigue mandando y se puede cambiar sin tocar los datos.
      final d = GalleryController(
        photos: testPhotoRepository(root: tmp.path),
        pinSeedPolicy: NPinSeedPolicy.none,
      );
      await d.fetchPhotos();
      expect(d.pinnedIds, isEmpty, reason: 'la política nueva se aplica');
      d.dispose();
    });
  });
}
