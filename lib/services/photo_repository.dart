// lib/services/photo_repository.dart
//
// Puente entre el repositorio de medios del núcleo y el modelo de dominio
// de NPhotos.
//
// # Por qué existe este archivo
//
// `NexoraCore` ya sabe leer el disco: qué rutas son de medios en cada
// plataforma, qué motor usar (R nativo o la sonda Dart cuando el `.so` no
// está), dónde está la caché de miniaturas. La app no duplica nada de
// eso: **no pregunta por rutas, ni por motores, ni por cabeceras**.
// Pide medios y recibe medios con sus metadatos.
//
// Lo único que queda de la app es el modelo. `Photo` lleva cosas que el
// núcleo no tiene por qué saber — favorito, etiqueta geográfica legible
// como texto, selfie — y este archivo es la única traducción entre
// `MediaAsset` y `Photo`.
//
// # Consecuencia práctica
//
// Cambiar de motor en el núcleo, añadir otra plataforma o apagar el
// nativo no toca ni una línea del controlador ni de la app.
import 'dart:io';

import 'package:NexoraCore/NexoraCore.dart';
import 'package:path/path.dart' as p;

import '../models/photo.dart';

/// Lector de medios para la galería.
///
/// Solo lectura. Lo que modifica el disco (borrar, mover, la bóveda
/// privada) es otra responsabilidad a propósito: mezclar lectura y
/// escritura en un objeto es lo que hace imposible probar una sin la
/// otra.
class PhotoRepository {
  final MediaRepository _media;

  /// Raíces a recorrer. `null` = las que diga la plataforma, decididas
  /// por el núcleo. Se fija solo en tests o para leer un volumen concreto.
  final List<String>? roots;

  PhotoRepository({MediaRepository? media, this.roots})
      : _media = media ?? DefaultMediaRepository();

  /// El repositorio del núcleo, para lo que necesite llamarlo de verdad
  /// (diagnóstico, miniaturas en lote).
  MediaRepository get media => _media;

  /// Motor que sirve las lecturas: `native` o `dart`. Para diagnóstico.
  String get engine => _media.engine;

  bool get isNativeAvailable => _media.isNativeAvailable;

  String? get unavailableReason => _media.unavailableReason;

  /// Lee todos los medios y los devuelve como `Photo`.
  ///
  /// Acepta el motor nativo o el de Dart indistintamente: quien llama
  /// pide fotos, no motores.
  ///
  /// Los metadatos se piden **al final y en un solo lote**. Intercalar la
  /// lectura de la cabecera con el barrido multiplica las esperas — son
  /// dos viajes al disco por archivo en lugar de uno— y el motor trabaja
  /// mucho mejor con la lista completa de una vez.
  ///
  /// Que la sonda Dart viva en el núcleo es lo que hace esto posible sin
  /// una reserva en la app: antes, sin motor nativo, las fotos perdían
  /// dimensiones y GPS sin que nada fallara.
  Future<List<Photo>> loadPhotos() async {
    final entries = <MediaAsset>[];
    await for (final asset in _media.scan(
      MediaScanOptions(roots: roots ?? const []),
    )) {
      // Las carpetas son los álbumes, no fotos: el controlador las deriva
      // de las rutas de los archivos, así que aquí se descartan.
      if (asset.entry.type == EntryType.directory) continue;
      if (!asset.isMedia) continue;
      entries.add(asset);
    }

    if (entries.isEmpty) return const [];

    final meta = await _media.metadataOf([for (final a in entries) a.path]);

    // El asset vuelve a salir con su metadato puesto: el mapeo de abajo
    // solo lee del asset, y no necesita saber de dónde salió el dato.
    final photos = [
      for (final asset in entries)
        _toPhoto(asset.copyWith(meta: meta[asset.path])),
    ];
    photos.sort((a, b) => b.dateModified.compareTo(a.dateModified));
    return photos;
  }

  /// Raíces que la plataforma considera, como directorios que existen.
  ///
  /// Es lo que hay que observar con [Directory.watch] para recargar: lo
  /// que se detecte aquí es lo que aparecerá en la galería. Las rutas las
  /// decide el núcleo, no la app.
  ///
  /// La comprobación de existencia es **async** a propósito: una raíz
  /// puede estar en un montaje de red (SMB, NFS) y `existsSync()` dejaría
  /// la interfaz congelada esperando el tiempo de espera del servidor.
  Future<List<Directory>> existingRoots() async {
    final out = <Directory>[];
    // Si se fijaron raíces (tests, un volumen concreto), mandan sobre
    // las de la plataforma. Si no, las decide el núcleo.
    final candidates =
        (roots != null && roots!.isNotEmpty) ? roots! : _media.platformRoots;
    for (final root in candidates) {
      final dir = Directory(root);
      if (await dir.exists()) out.add(dir);
    }
    return out;
  }

  /// Rutas de miniatura ya generadas, indexadas por ruta de origen.
  Future<Map<String, String>> loadThumbnails(
    List<String> paths, {
    int? boxPx,
  }) =>
      _media.thumbnailsOf(paths, boxPx: boxPx);

  /// Aplica la política de rendimiento al motor.
  void applyPerformanceProfile(int profileId) =>
      _media.setPerformanceProfile(profileId);

  void dispose() => _media.dispose();

  /// Traducción única de `MediaAsset` a `Photo`.
  ///
  /// Todo lo opcional sale del `meta` del asset y, si ahí no está, se
  /// deja en `null`: la ficha se pinta igual, solo que con menos datos.
  /// No se inventan dimensiones ni coordenadas que nadie pudo leer.
  Photo _toPhoto(MediaAsset asset) {
    final entry = asset.entry;
    final meta = asset.meta;
    final lat = asset.latitude;
    final lng = asset.longitude;

    return Photo(
      id: entry.path,
      path: entry.path,
      title: entry.name,
      // Sin EXIF, `asset.captured` cae a la fecha del sistema: mejor una
      // fecha aproximada que un álbum sin fecha.
      dateCreated: asset.captured,
      dateModified: entry.modified,
      sizeInBytes: entry.size,
      isVideo: asset.isVideo,
      width: asset.width,
      height: asset.height,
      latitude: lat,
      longitude: lng,
      locationLabel: locationLabel(lat, lng),
      isMotionPhoto: (meta?.isMotionPhoto ?? false) ||
          looksLikeMotionPhoto(entry.path),
      isSelfie: (meta?.isSelfie ?? false) || looksLikeSelfie(entry.path),
    );
  }

  /// Etiqueta geográfica legible a partir de coordenadas EXIF.
  ///
  /// Sin red: coordenadas con 4 decimales (~11 m). `null` = el visor
  /// oculta la ubicación.
  static String? locationLabel(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Heurística Motion Photo por nombre (MVIMG, motion, live).
  ///
  /// El motor la lee de la cabecera, pero un archivo con la pista en el
  /// nombre y el EXIF ausente se detectaría como foto estática. Solo es
  /// red de seguridad para lo que la cabecera no dice.
  static bool looksLikeMotionPhoto(String path) {
    final name = p.basename(path).toUpperCase();
    return name.contains('MVIMG') ||
        name.contains('MOTION') ||
        name.contains('LIVE');
  }

  /// Heurística selfie por nombre/carpeta (frontal, selfie).
  static bool looksLikeSelfie(String path) {
    final lower = path.toLowerCase();
    return lower.contains('selfie') ||
        lower.contains('front') ||
        lower.contains('img_f');
  }
}
