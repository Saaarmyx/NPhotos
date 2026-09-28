// lib/controllers/selection_controller.dart
//
// Estado de selección múltiple (fotos y álbumes) para las acciones en
// bloque: compartir, favoritos y eliminar.
//
// Es independiente de [GalleryController]: la selección es efímera (no se
// persiste) y vive por encima de la pantalla activa.
import 'package:flutter/material.dart';

/// Tipo de contenido seleccionado: cambia la barra de acciones.
enum SelectionKind { photos, albums }

class SelectionController extends ChangeNotifier {
  final Set<String> _ids = {};
  SelectionKind _kind = SelectionKind.photos;

  /// Seleccionados.
  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;

  /// true si no hay nada seleccionado (la app muestra la UI normal).
  bool get isActive => _ids.isNotEmpty;

  SelectionKind get kind => _kind;

  bool isSelected(String id) => _ids.contains(id);

  /// Selecciona solo este id y limpia el resto.
  void selectOnly(String id, {SelectionKind kind = SelectionKind.photos}) {
    if (_kind != kind || _ids.isNotEmpty) _ids.clear();
    _kind = kind;
    _ids.add(id);
    notifyListeners();
  }

  /// Alterna un id (mantiene el resto de la selección del mismo tipo).
  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// Selecciona todo un conjunto (respeta el tipo actual).
  void selectAll(Iterable<String> ids) {
    _ids
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// ¿Están todos los disponibles seleccionados?
  ///
  /// Compara conjuntos: el orden de [ids] es irrelevante y un id
  /// repetido no debe hacer fallar la comparación.
  bool isAllSelected(Iterable<String> ids) {
    final set = ids.toSet();
    return set.isNotEmpty && set.every(_ids.contains);
  }

  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}
