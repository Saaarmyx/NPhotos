// lib/services/view_prefs.dart
//
// Persistencia del popup de la topbar (⋮): orden, modo de vista,
// filtros y secciones ocultas.
//
// Es la misma forma que en NFiles: enums con nombre + booleans. Aquí
// vive el mapa de cada ajuste a su clave para que el resto de la app no
// toque cadenas sueltas.
//
// El guardado cuelga de un único `addListener` del controller: todos sus
// setters pasan por `notifyListeners()`, así que no hay que acordarse de
// guardar en ninguno de ellos. El coste es que un cambio de filtro
// dispara también la escritura de los otros tres, y a cambio nadie
// puede añadir un ajuste y olvidarse de persistirlo.
import 'dart:async';

import 'package:NexoraUi/NexoraUi.dart';

import '../controllers/gallery_controller.dart';


/// Lee y escribe [GalleryViewState] en el almacén.
class GalleryViewPrefs {
  final NViewPrefs _prefs;
  Timer? _debounce;

  GalleryViewPrefs(NKeyValueStore store)
      : _prefs = NViewPrefs(store, prefix: 'nphotos_view_');

  /// Lee lo guardado. Cada clave cae a su valor por defecto, así que un
  /// almacén a medias (app vieja) no deja ningún ajuste sin valor.
  GalleryViewState load() => GalleryViewState(
        sort: _prefs.enumOf(GallerySort.values, 'sort', GallerySort.captureDay),
        viewMode: _prefs.enumOf(
            GalleryViewMode.values, 'view_mode', GalleryViewMode.byDate),
        filter:
            _prefs.enumOf(GalleryFilter.values, 'filter', GalleryFilter.all),
        albumsViewMode: _prefs.enumOf(
            AlbumsViewMode.values, 'albums_view_mode', AlbumsViewMode.grid),
        collectionsViewMode: _prefs.enumOf(CollectionsViewMode.values,
            'collections_view_mode', CollectionsViewMode.compact),
        collectionsSort: _prefs.enumOf(
            CollectionsSort.values, 'collections_sort', CollectionsSort.az),
        hidePins: _prefs.boolOf('hide_pins'),
        hideAlbums: _prefs.boolOf('hide_albums'),
        hideSystem: _prefs.boolOf('hide_system'),
        hideCovers: _prefs.boolOf('hide_covers'),
      );

  /// Aplica lo guardado al controller, sin emitir cambios.
  ///
  /// Sin `notifyListeners`: se llama antes de que la UI se suscriba, y
  /// avisar aquí solo provocaría un repintado que no cambia nada.
  void applyTo(GalleryController c, GalleryViewState state) {
    c.restoreViewState(state);
  }

  Future<void> save(GalleryViewState state) =>
      _prefs.writeAll(state.toMap());

  /// Guarda el estado actual del controller.
  ///
  /// Agrupa los cambios en 250 ms: abrir el popup y tocar cuatro
  /// switches seguidos son cuatro escrituras de diez claves, y sin
  /// agrupar se nota en dispositivos modestos.
  void attach(GalleryController c) {
    c.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        unawaited(save(GalleryViewState.of(c)));
      });
    });
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
  }
}
