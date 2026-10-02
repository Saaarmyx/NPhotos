import 'package:flutter_test/flutter_test.dart';
import 'package:NPhotos/services/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LocalStore', () {
    test('favoritos: guardar y recuperar', () async {
      final store = await LocalStore.load();
      expect(store.favoriteIds(), isEmpty);

      await store.saveFavoriteIds({'/a.jpg', '/b.png'});

      final reloaded = await LocalStore.load();
      expect(reloaded.favoriteIds(), {'/a.jpg', '/b.png'});
    });

    test('papelera: guardar y recuperar con fechas', () async {
      final store = await LocalStore.load();
      final at = DateTime(2026, 9, 27, 15, 30);
      await store.saveTrashed({'/gone.jpg': at});

      final reloaded = await LocalStore.load();
      expect(reloaded.trashedAt().keys, ['/gone.jpg']);
      expect(reloaded.trashedAt()['/gone.jpg'], at);
    });

    test('papelera corrupta no revienta', () async {
      SharedPreferences.setMockInitialValues({
        'nphotos_trash_v1': 'no-json{{{',
      });
      final store = await LocalStore.load();
      expect(store.trashedAt(), isEmpty);
    });
  });
}
