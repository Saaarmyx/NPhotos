import 'package:flutter/material.dart';

/// Colecciones especiales de NPhotos (las opciones de la pantalla
/// "Colecciones" y destinos del sidebar en desktop).
enum CollectionKind { people, places, videos, recent, archive, locked, trash }

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
    CollectionKind.places => 'Fotos por ubicación (próximamente)',
    CollectionKind.videos => 'Tus vídeos',
    CollectionKind.recent => 'Lo último que has añadido',
    CollectionKind.archive => 'Fotos archivadas',
    CollectionKind.locked => 'Solo visible para ti (próximamente)',
    CollectionKind.trash => 'La papelera está vacía',
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
