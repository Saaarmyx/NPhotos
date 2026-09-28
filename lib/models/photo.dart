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
  });

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
    );
  }
}
