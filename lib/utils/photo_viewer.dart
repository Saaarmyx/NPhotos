import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/gallery_controller.dart';
import '../models/photo.dart';
import '../screens/gallery/photo_viewer_screen.dart';

/// Abre el visor de pantalla completa sobre cualquier lista de fotos.
///
/// Úsalo desde cualquier screen (galería, álbumes, colecciones, etc.):
/// ```dart
/// onTap: () => openPhotoViewer(
///   context,
///   controller: controller,
///   photos: album.photos,
///   initialId: photo.id,
/// ),
/// ```
/// Comparte varias fotos/vídeos a la vez.
///
/// Si el sistema no admite selección múltiple, cae a archivos de uno en
/// uno para no perder la acción.
Future<void> sharePhotos(
  BuildContext context,
  List<Photo> photos,
) async {
  if (photos.isEmpty) return;
  final files = [for (final p in photos) XFile(p.path)];
  try {
    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: photos.length == 1 ? photos.first.title : 'NPhotos',
      ),
    );
  } catch (_) {
    // Algunos SHARE_SHEET no aceptan N archivos: se comparten de a uno.
    for (final file in files) {
      try {
        await SharePlus.instance.share(ShareParams(files: [file]));
      } catch (_) {
        break;
      }
    }
  }
}

Future<void> openPhotoViewer(
  BuildContext context, {
  required GalleryController controller,
  required List<Photo> photos,
  int initialIndex = 0,
  String? initialId,
}) {
  if (photos.isEmpty) return Future.value();
  var index = initialIndex;
  if (initialId != null) {
    final found = photos.indexWhere((p) => p.id == initialId);
    if (found != -1) index = found;
  }
  return pushNPage<void>(
    context,
    PhotoViewerScreen(
      controller: controller,
      initialIndex: index.clamp(0, photos.length - 1),
      photosOverride: photos,
    ),
  );
}
