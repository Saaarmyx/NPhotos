import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistencia local de NPhotos (favoritos y papelera).
///
/// Guarda solo identificadores (rutas) y metadatos: las fotos se
/// redescubren del disco en cada arranque y los registros huérfanos
/// (archivos que ya no existen) se podan al cargar.
class LocalStore {
  static const _favoritesKey = 'nphotos_favorites_v1';
  static const _trashKey = 'nphotos_trash_v1';
  static const _snapshotKey = 'nphotos_snapshot_v1';
  static const _pinsKey = 'nphotos_pins_v1';
  static const _privateOriginsKey = 'nphotos_private_origins_v1';
  static const _albumsKey = 'nphotos_albums_v1';
  static const _onboardingDoneKey = 'nphotos_onboarding_done_v1';
  static const _usernameKey = 'nphotos_username_v1';
  static const _avatarKey = 'nphotos_avatar_v1';
  static const _accentKey = 'nphotos_accent_v1';
  static const _themeModeKey = 'nphotos_theme_mode_v1';
  static const _barStyleKey = 'nphotos_bar_style_v1';
  static const _performanceKey = 'nphotos_performance_v1';

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

  /// Persiste la bienvenida: estado actual de [AppAppearance] + fin.
  Future<void> saveOnboarding() async {
    await _prefs.setString(_usernameKey, AppAppearance.userName.value);
    final avatar = AppAppearance.avatarPath.value;
    if (avatar != null) {
      await _prefs.setString(_avatarKey, avatar);
    } else {
      await _prefs.remove(_avatarKey);
    }
    await _prefs.setInt(
        _accentKey, AppAppearance.accentColor.value.toARGB32());
    await _prefs.setString(
        _themeModeKey, AppAppearance.themeMode.value.name);
    await _prefs.setString(
        _barStyleKey, AppAppearance.barStyle.value.name);
    await _prefs.setString(
        _performanceKey, AppAppearance.performanceMode.value.name);
    await _prefs.setBool(_onboardingDoneKey, true);
  }

  /// Aplica la apariencia guardada (o el rosado nphotos por defecto).
  void applyAppearance() {
    if (!onboardingDone()) {
      AppAppearance.setAccentColor(NColors.photosAccent);
      return;
    }
    AppAppearance.setUserName(_prefs.getString(_usernameKey) ?? '');
    AppAppearance.setAvatarPath(_prefs.getString(_avatarKey));
    final accent = _prefs.getInt(_accentKey);
    if (accent != null) AppAppearance.setAccentColor(Color(accent));
    AppAppearance.setThemeMode(ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_themeModeKey),
      orElse: () => ThemeMode.system,
    ));
    AppAppearance.setBarStyle(NBarStyle.values.firstWhere(
      (s) => s.name == _prefs.getString(_barStyleKey),
      orElse: () => NBarStyle.solid,
    ));
    AppAppearance.setPerformanceMode(NPerformanceMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_performanceKey),
      orElse: () => NPerformanceMode.high,
    ));
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
