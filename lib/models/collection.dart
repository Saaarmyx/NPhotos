import 'package:flutter/material.dart';

/// Colecciones especiales de NPhotos (las opciones de la pantalla
/// "Colecciones" y destinos del sidebar en desktop).
///
/// Vídeos y Papelera NO viven aquí: están pineados en Álbumes.
enum CollectionKind {
  people,
  places,
  videos,
  recent,
  documents,
  hd,
  archive,
  locked,
  hiddenAlbums,
  trash,
}

/// Colecciones visibles en la pantalla Colecciones (y sidebar desktop):
/// solo lo funcional. Personas (v1 heurística), Archivo y el resto de
/// placeholders quedan fuera hasta tener lógica real detrás.
const visibleCollectionKinds = [
  CollectionKind.recent,
  CollectionKind.people,
  CollectionKind.places,
  CollectionKind.documents,
  CollectionKind.hd,
  CollectionKind.locked,
  CollectionKind.hiddenAlbums,
];

/// Grupo de colecciones para la vista "Por grupo" (cada uno con título).
class CollectionGroup {
  final String title;
  final List<CollectionKind> kinds;
  const CollectionGroup(this.title, this.kinds);
}

/// Agrupado de la lista de colecciones: recientes con privada,
/// personas con lugares y archivos juntos.
const collectionGroups = [
  CollectionGroup('Recientes', [CollectionKind.recent, CollectionKind.locked]),
  CollectionGroup('Personas y lugares', [
    CollectionKind.people,
    CollectionKind.places,
  ]),
  CollectionGroup('Archivos', [CollectionKind.documents, CollectionKind.hd]),
  CollectionGroup('Organización', [CollectionKind.hiddenAlbums]),
];

extension CollectionKindData on CollectionKind {
  String get label => switch (this) {
    CollectionKind.people => 'Personas',
    CollectionKind.places => 'Lugares',
    CollectionKind.videos => 'Vídeos',
    CollectionKind.recent => 'Añadidos recientemente',
    CollectionKind.documents => 'Documentos',
    CollectionKind.hd => 'Alta definición',
    CollectionKind.archive => 'Archivo',
    CollectionKind.locked => 'Carpeta privada',
    CollectionKind.hiddenAlbums => 'Álbumes ocultos',
    CollectionKind.trash => 'Papelera',
  };

  String get description => switch (this) {
    CollectionKind.people => 'Selfies y cámara frontal (aproximación)',
    CollectionKind.places => 'Fotos agrupadas por carpeta de origen',
    CollectionKind.videos => 'Tus vídeos (pineado en Álbumes)',
    CollectionKind.recent => 'Lo último de los pasados 7 días',
    CollectionKind.documents => 'Documentos y escaneos',
    CollectionKind.hd => 'Fotos de 12 MP o más',
    CollectionKind.archive => 'Fotos archivadas',
    CollectionKind.locked => 'Fuera de la galería (aún sin bloqueo)',
    CollectionKind.hiddenAlbums => 'Tus álbumes ocultos',
    CollectionKind.trash => 'Papelera (pineada en Álbumes)',
  };

  IconData get icon => switch (this) {
    CollectionKind.people => Icons.people_outline,
    CollectionKind.places => Icons.place_outlined,
    CollectionKind.videos => Icons.videocam_outlined,
    CollectionKind.recent => Icons.access_time_outlined,
    CollectionKind.documents => Icons.description_outlined,
    CollectionKind.hd => Icons.hd_outlined,
    CollectionKind.archive => Icons.archive_outlined,
    CollectionKind.locked => Icons.lock_outline,
    CollectionKind.hiddenAlbums => Icons.visibility_off_outlined,
    CollectionKind.trash => Icons.delete_outline,
  };
}
