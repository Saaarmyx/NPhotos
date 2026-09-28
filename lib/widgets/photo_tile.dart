// lib/widgets/photo_tile.dart
//
// Adaptador de dominio: mapea el modelo `Photo` a las primitivas de
// imagen del kit (NImageTile + insignias). No contiene lógica visual
// propia salvo la regla de insignias, que es del dominio.
//
// Reglas de insignias:
// - Siempre hay miniatura. En vídeos NO se intenta decodificar el
//   archivo (fallaría siempre): se usa NVideoThumb, reconocible.
// - Arriba derecha: favorito (si aplica).
// - Abajo centro: si es vídeo, play + duración.
// - Abajo izquierda: solo fotos, máximo 2 iconos
//   (motion > HD/+50MP > selfie). En vídeos va vacío.
import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../models/photo.dart';

class PhotoTile extends StatelessWidget {
  final String path;
  final int cacheWidth;
  final BoxFit fit;
  final double? width;
  final bool isVideo;

  /// Modelo rico opcional. Si se pasa, las insignias se derivan de él.
  /// Mantiene compat con llamadas legacy que solo pasan [path]/[isVideo].
  final Photo? photo;

  /// Modo selección: si no es null, se muestra el estado seleccionado.
  final bool? selected;

  /// Silencia las insignias (para listas de selección compactas).
  final bool showBadges;

  const PhotoTile({
    super.key,
    required this.path,
    this.cacheWidth = 250,
    this.fit = BoxFit.cover,
    this.width,
    this.isVideo = false,
    this.photo,
    this.selected,
    this.showBadges = true,
  });

  bool get _effectiveIsVideo => photo?.isVideo ?? isVideo;
  bool get _effectiveIsFavorite => photo?.isFavorite ?? false;
  String get _effectivePath => photo?.path ?? path;

  @override
  Widget build(BuildContext context) {
    final video = _effectiveIsVideo;
    final inSelection = selected != null;
    final badges = showBadges && !inSelection ? _buildBadges(video) : const <NImageBadge>[];

    // La miniatura la resuelve el kit: vídeo → portada (Flutter no
    // decodifica MP4), foto → `Image.file` con su fallback.
    return NImageTile.file(
      _effectivePath,
      width: width,
      fit: fit,
      cacheWidth: cacheWidth,
      isVideo: video,
      badges: badges,
      selected: selected,
    );
  }

  List<NImageBadge> _buildBadges(bool video) {
    return [
      if (_effectiveIsFavorite)
        const NImageBadge(
          anchor: NBadgeAnchor.topEnd,
          child: NImageCircleBadge(icon: Icons.favorite, iconColor: Colors.red),
        ),
      if (video)
        NImageBadge(
          anchor: NBadgeAnchor.bottomCenter,
          margin: 0,
          child: Center(
            child: NVideoBadge(label: photo?.formattedDuration),
          ),
        )
      else if (_statusIcons().isNotEmpty)
        NImageBadge(
          anchor: NBadgeAnchor.bottomStart,
          child: NImageBadgeRow(icons: _statusIcons()),
        ),
    ];
  }

  /// Máximo 2 iconos de estado para fotos. Prioridad:
  /// motion > HD/+50MP > selfie.
  List<IconData> _statusIcons() {
    final p = photo;
    if (p == null || p.isVideo) return const [];
    final icons = <IconData>[];
    if (p.isMotionPhoto) icons.add(Icons.motion_photos_on_outlined);
    if (p.isHighResolution) icons.add(Icons.hd_outlined);
    if (p.isSelfie) icons.add(Icons.face_outlined);
    if (icons.length > 2) return icons.sublist(0, 2);
    return icons;
  }
}
