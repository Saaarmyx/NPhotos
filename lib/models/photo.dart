// lib/models/photo.dart
class Photo {
  final String id;
  final String path;
  final String? thumbnailPath;
  final String title;
  final DateTime dateCreated;
  final DateTime dateModified;
  final int sizeInBytes;
  final bool isFavorite;
  final bool isVideo;
  final int? width;
  final int? height;

  /// Duración solo para vídeos. Null si aún no se resolvió (badge genérico).
  final Duration? duration;

  /// Foto animada / motion photo (p. ej. MVIMG, motion).
  final bool isMotionPhoto;

  /// Selfie / cámara frontal (heurística por nombre/carpeta).
  final bool isSelfie;

  /// GPS EXIF en decimal. Null = la foto no trae ubicación.
  final double? latitude;
  final double? longitude;

  /// Etiqueta geográfica legible (ciudad, lugar). Nunca la ruta de archivo.
  /// Null = ubicación desconocida (el visor la oculta).
  final String? locationLabel;

  const Photo({
    required this.id,
    required this.path,
    this.thumbnailPath,
    required this.title,
    required this.dateCreated,
    required this.dateModified,
    required this.sizeInBytes,
    this.isFavorite = false,
    this.isVideo = false,
    this.width,
    this.height,
    this.duration,
    this.isMotionPhoto = false,
    this.isSelfie = false,
    this.latitude,
    this.longitude,
    this.locationLabel,
  });

  /// True cuando el EXIF trae GPS válido.
  bool get hasLocation => latitude != null && longitude != null;

  /// Megapíxeles cuando hay dimensiones, null si se desconocen.
  double? get megapixels {
    if (width == null || height == null) return null;
    return width! * height! / 1000000.0;
  }

  /// Alta definición: +50MP o 8K aprox. Solo fotos.
  bool get isHighResolution {
    if (isVideo) return false;
    final mp = megapixels;
    if (mp != null) return mp >= 50.0;
    // Sin dimensiones no se afirma HD (evita badges falsos).
    return false;
  }

  /// 'mm:ss' para el badge inferior central de vídeos.
  String? get formattedDuration {
    final d = duration;
    if (!isVideo || d == null) return null;
    final totalSeconds = d.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Photo copyWith({
    String? id,
    String? path,
    String? thumbnailPath,
    String? title,
    DateTime? dateCreated,
    DateTime? dateModified,
    int? sizeInBytes,
    bool? isFavorite,
    bool? isVideo,
    int? width,
    int? height,
    Duration? duration,
    bool? isMotionPhoto,
    bool? isSelfie,
    double? latitude,
    double? longitude,
    String? locationLabel,
  }) {
    return Photo(
      id: id ?? this.id,
      path: path ?? this.path,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      title: title ?? this.title,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      isFavorite: isFavorite ?? this.isFavorite,
      isVideo: isVideo ?? this.isVideo,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      isMotionPhoto: isMotionPhoto ?? this.isMotionPhoto,
      isSelfie: isSelfie ?? this.isSelfie,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationLabel: locationLabel ?? this.locationLabel,
    );
  }
}
