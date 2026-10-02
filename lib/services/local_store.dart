import 'dart:convert';

import 'package:NexoraCore/NexoraCore.dart';
import 'package:NexoraUi/NexoraUi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../controllers/gallery_controller.dart';
import 'view_prefs.dart';

/// Persistencia local de NPhotos (favoritos y papelera).
///
/// Guarda solo identificadores (rutas) y metadatos: las fotos se
/// redescubren del disco en cada arranque y los registros huérfanos
/// (archivos que ya no existen) se podan al cargar.
///
/// Los favoritos se sincronizan con el índice nativo (redb compartido con NFiles)
/// para que una foto marcada en NPhotos se refleje inmediatamente en NFiles.
class LocalStore {
  static const _favoritesKey = 'nphotos_favorites_v1';
  static const _trashKey = 'nphotos_trash_v1';
  static const _snapshotKey = 'nphotos_snapshot_v1';
  static const _pinsKey = 'nphotos_pins_v1';
  static const _privateOriginsKey = 'nphotos_private_origins_v1';
  static const _albumsKey = 'nphotos_albums_v1';
  static const _onboardingDoneKey = 'nphotos_onboarding_done_v1';

  final SharedPreferences _prefs;
  NativeIndexStore? _nativeIndex;

  LocalStore(this._prefs);

  static Future<LocalStore> load() async =>
      LocalStore(await SharedPreferences.getInstance());

  /// Índice nativo (redb) para favoritos compartidos con NFiles.
  NativeIndexStore get _native => _nativeIndex ??= NativeIndexStore();

  /// Ids (rutas) marcados como favoritos.
  /// Lee del índice nativo (redb) como fuente principal; si no está disponible,
  /// cae a SharedPreferences (legacy).
  Set<String> favoriteIds() {
    // 1) Índice nativo: fuente de verdad compartida con NFiles
    try {
      final nativeFavs = _native.loadFavorites();
      if (nativeFavs != null && nativeFavs.isNotEmpty) {
        return Set.of(nativeFavs);
      }
    } catch (_) {
      // Silencioso: degradamos a SP
    }
    // 2) Fallback: SharedPreferences (solo esta app)
    return Set.of(_prefs.getStringList(_favoritesKey) ?? const []);
  }

  /// Guarda favoritos en AMBOS almacenes: índice nativo (para NFiles) y SP (legacy).
  Future<void> saveFavoriteIds(Set<String> ids) async {
    // 1) Índice nativo (redb) - prioritario para sincronía
    try {
      if (_native.isAvailable && ids.isNotEmpty) {
        _native.setFavorites(ids.toList(), true);
      }
    } catch (_) {}

    // 2) SharedPreferences - fallback legacy
    await _prefs.setStringList(_favoritesKey, ids.toList());
  }

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

  /// Snapshot ligero para arranque instantáneo (0ms percibidos).
  ///
  /// Solo guarda primitivos (ruta + mtime) para hidratar la grilla desde
  /// caché antes del escaneo real. Los metadatos ricos se resuelven después.
  List<Map<String, Object>> loadSnapshot() {
    final raw = _prefs.getString(_snapshotKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in decoded)
          if (e is Map<String, dynamic> &&
              e['path'] is String &&
              e['modified'] is int)
            {'path': e['path'] as String, 'modified': e['modified'] as int},
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveSnapshot(List<Map<String, Object>> rows) =>
      _prefs.setString(_snapshotKey, jsonEncode(rows));

  /// Pines de Álbumes en orden (máx 4). Ids: `album:<dirPath>` para
  /// carpetas y `__videos__` / `__trash__` / `__favorites__` para listas
  /// sintéticas. Sin clave = primera vez (la app siembra los defaults).
  bool hasPins() => _prefs.containsKey(_pinsKey);

  List<String> pinnedIds() =>
      List.of(_prefs.getStringList(_pinsKey) ?? const []);

  Future<void> savePinnedIds(List<String> ids) =>
      _prefs.setStringList(_pinsKey, ids);

  /// Orígenes de la carpeta privada: ruta actual en bóveda → carpeta
  /// original, para restaurar cada foto a su sitio.
  Map<String, String> privateOrigins() {
    final raw = _prefs.getString(_privateOriginsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key: entry.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> savePrivateOrigins(Map<String, String> origins) =>
      _prefs.setString(_privateOriginsKey, jsonEncode(origins));

  // ─── Personalización de álbumes ───

  /// Previsualización por ruta: {ruta: AlbumPrefs}.
  /// Se serializa como lista para no duplicar claves en JSON.
  Map<String, AlbumPrefs> albumPrefs() {
    final raw = _prefs.getString(_albumsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return {
        for (final e in decoded)
          if (e is Map<String, dynamic> && e['path'] is String)
            e['path'] as String: AlbumPrefs(
              name: e['name'] as String?,
              cover: e['cover'] as String?,
              hidden: e['hidden'] as bool? ?? false,
            ),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAlbumPrefs(Map<String, AlbumPrefs> prefs) =>
      _prefs.setString(
        _albumsKey,
        jsonEncode([
          for (final entry in prefs.entries)
            if (entry.value.isCustom)
              {
                'path': entry.key,
                if (entry.value.name != null) 'name': entry.value.name,
                if (entry.value.cover != null) 'cover': entry.value.cover,
                if (entry.value.hidden) 'hidden': true,
              },
        ]),
      );

  // ─── Bienvenida / apariencia ───

  /// Si ya se completó la bienvenida inicial.
  bool onboardingDone() => _prefs.getBool(_onboardingDoneKey) ?? false;

  /// Preferencias del popup de la topbar (orden, vista, filtros,
  /// secciones ocultas). Mismo almacén que la apariencia, otro prefijo.
  late final GalleryViewPrefs viewPrefs =
      GalleryViewPrefs(PrefsKeyValueStore(_prefs));

  /// Aplica lo guardado al controller y se queda escuchando.
  ///
  /// Se separa de [applyAppearance] a propósito: la apariencia se
  /// carga una vez al arrancar, estas preferencias se guardan y recargan
  /// cada vez que el usuario toca el popup.
  void applyViewPreferences(GalleryController controller) {
    viewPrefs.applyTo(controller, viewPrefs.load());
    viewPrefs.attach(controller);
  }

  /// Persistencia de la apariencia, delegada en el kit.
  ///
  /// La lista de ajustes (acento, tema, estilo, intensidad, modo, usuario
  /// y foto) la define [NAppearanceStore] para que las dos apps no puedan
  /// desincronizarse. Aqui solo se le da nombre y prefijo.
  late final NAppearanceStore appearance =
      NAppearanceStore(PrefsKeyValueStore(_prefs), prefix: 'nphotos_appearance_');

  /// Persiste la bienvenida y marca el fin.
  Future<void> saveOnboarding() async {
    await appearance.save();
    await _prefs.setBool(_onboardingDoneKey, true);
  }

  /// Aplica la apariencia guardada y se queda escuchando para que
  /// cualquier cambio posterior se guarde solo.
  ///
  /// Antes solo se guardaba al terminar la bienvenida, asi que cambiar el
  /// acento o el estilo despues se perdia al reiniciar.
  void applyAppearance() {
    appearance.load(defaultAccent: NAccentColors.photos);
    appearance.attach();
  }
}

/// Previsualización de un álbum: nombre, carátula y visibilidad.
///
/// Todo opcional: null = se usa el valor real del disco.
class AlbumPrefs {
  final String? name;
  final String? cover;
  final bool hidden;

  const AlbumPrefs({this.name, this.cover, this.hidden = false});

  /// False si no aporta nada: entonces no se persiste.
  bool get isCustom => name != null || cover != null || hidden;

  AlbumPrefs copyWith({
    String? name,
    String? cover,
    bool? hidden,
    bool clearName = false,
    bool clearCover = false,
  }) => AlbumPrefs(
    name: clearName ? null : (name ?? this.name),
    cover: clearCover ? null : (cover ?? this.cover),
    hidden: hidden ?? this.hidden,
  );
}

/// Adaptador de [NKeyValueStore] sobre `SharedPreferences`.
///
/// El kit define la persistencia de la apariencia pero no depende de
/// `shared_preferences`, para no arrastrar el plugin a quien solo quiera
/// un componente. Esta clase es todo el pegamento que hace falta.
class PrefsKeyValueStore implements NKeyValueStore {
  final SharedPreferences prefs;

  const PrefsKeyValueStore(this.prefs);

  @override
  String? getString(String key) => prefs.getString(key);

  @override
  double? getDouble(String key) => prefs.getDouble(key);

  @override
  int? getInt(String key) => prefs.getInt(key);

  @override
  bool? getBool(String key) => prefs.getBool(key);

  @override
  Future<void> setString(String key, String? value) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  @override
  Future<void> setDouble(String key, double value) =>
      prefs.setDouble(key, value);

  @override
  Future<void> setInt(String key, int value) => prefs.setInt(key, value);

  @override
  Future<void> setBool(String key, bool value) => prefs.setBool(key, value);
}
