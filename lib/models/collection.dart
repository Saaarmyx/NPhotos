import 'package:flutter/material.dart';

/// Colecciones especiales de NPhotos (las opciones de la pantalla
/// "Colecciones" y destinos del sidebar en desktop).
///
/// Vídeos y Papelera NO viven aquí: están pineados en Álbumes.
enum CollectionKind { people, places, videos, recent, archive, locked, trash }

/// Colecciones visibles en la pantalla Colecciones (y sidebar desktop).
/// Release 26.09.28: solo lo funcional. Personas, Archivo y Privada son
/// placeholders sin lógica; Vídeos y Papelera viven pineados en Álbumes.
const visibleCollectionKinds = [
  CollectionKind.places,
  CollectionKind.recent,
];

extension CollectionKindData on CollectionKind {
  String get label => switch (this) {
    CollectionKind.people => 'Personas y mascotas',
    CollectionKind.places => 'Lugares',
    CollectionKind.videos => 'Vídeos',
    CollectionKind.recent => 'Añadidos recientemente',
    CollectionKind.archive => 'Archivo',
    CollectionKind.locked => 'Carpeta privada',
    CollectionKind.trash => 'Papelera',
  };

  String get description => switch (this) {
    CollectionKind.people => 'Agrupación de rostros (próximamente)',
    CollectionKind.places => 'Fotos agrupadas por carpeta de origen',
    CollectionKind.videos => 'Tus vídeos (pineado en Álbumes)',
    CollectionKind.recent => 'Lo último que has añadido',
    CollectionKind.archive => 'Fotos archivadas',
    CollectionKind.locked => 'Solo visible para ti (próximamente)',
    CollectionKind.trash => 'Papelera (pineada en Álbumes)',
  };

  IconData get icon => switch (this) {
    CollectionKind.people => Icons.people_outline,
    CollectionKind.places => Icons.place_outlined,
    CollectionKind.videos => Icons.videocam_outlined,
    CollectionKind.recent => Icons.access_time_outlined,
    CollectionKind.archive => Icons.archive_outlined,
    CollectionKind.locked => Icons.lock_outline,
    CollectionKind.trash => Icons.delete_outline,
  };
}
