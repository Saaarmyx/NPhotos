import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local de NPhotos (favoritos y papelera).
///
/// Guarda solo identificadores (rutas) y metadatos: las fotos se
/// redescubren del disco en cada arranque y los registros huérfanos
/// (archivos que ya no existen) se podan al cargar.
class LocalStore {
  static const _favoritesKey = 'nphotos_favorites_v1';
  static const _trashKey = 'nphotos_trash_v1';

  final SharedPreferences _prefs;

  LocalStore(this._prefs);

  static Future<LocalStore> load() async =>
      LocalStore(await SharedPreferences.getInstance());

  /// Ids (rutas) marcados como favoritos.
  Set<String> favoriteIds() =>
      Set.of(_prefs.getStringList(_favoritesKey) ?? const []);

  Future<void> saveFavoriteIds(Set<String> ids) =>
      _prefs.setStringList(_favoritesKey, ids.toList());

  /// Ruta → fecha en que se movió a la papelera.
  Map<String, DateTime> trashedAt() {
    final raw = _prefs.getString(_trashKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          entry.key: DateTime.fromMillisecondsSinceEpoch(entry.value as int),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveTrashed(Map<String, DateTime> trashed) =>
      _prefs.setString(_trashKey, jsonEncode({
        for (final entry in trashed.entries)
          entry.key: entry.value.millisecondsSinceEpoch,
      }));
}
