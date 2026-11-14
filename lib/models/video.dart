import 'package:pocketbase/pocketbase.dart';

class Video {
  final String id;
  final String name;
  final String url;
  final int size;
  final DateTime createdAt;
  final String? thumbnailUrl;
  int likesCount;
  bool isLiked;
  int commentsCount;

  Video({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.createdAt,
    this.thumbnailUrl,
    this.likesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
  });

  /// 🛠️ FACTORY: Construye un Video de forma segura desde un `RecordModel` nativo de PocketBase
  factory Video.fromRecord(RecordModel record) {
    return Video(
      id: record.id,
      name: record.getStringValue('title').isEmpty
          ? record.getStringValue('titulo', 'Video sin título')
          : record.getStringValue('title'),
      url: record.getStringValue('url').isEmpty
          ? record.getStringValue('video_url')
          : record.getStringValue('url'),
      size: record.getIntValue('size', 0),
      createdAt: DateTime.tryParse(record.created) ?? DateTime.now(),
      thumbnailUrl: record.getStringValue('thumbnail_url').isEmpty
          ? null
          : record.getStringValue('thumbnail_url'),
      likesCount:
          record.getIntValue('likesCount', record.getIntValue('likes', 0)),
      commentsCount: record.getIntValue(
          'commentsCount', record.getIntValue('comments', 0)),
      isLiked: record.getBoolValue('isLiked', false),
    );
  }

  /// 🛠️ FACTORY: Construye un Video desde un mapa JSON estándar (Respaldo o Caché)
  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: (json['id'] ?? '').toString(),
      name: (json['title'] ?? json['titulo'] ?? 'Video sin título').toString(),
      url: (json['url'] ?? json['video_url'] ?? '').toString(),
      size: int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.tryParse(json['created']?.toString() ??
              json['createdAt']?.toString() ??
              '') ??
          DateTime.now(),
      thumbnailUrl:
          json['thumbnail_url']?.toString() ?? json['thumbnailUrl']?.toString(),
      likesCount: int.tryParse(json['likesCount']?.toString() ??
              json['likes']?.toString() ??
              '0') ??
          0,
      commentsCount: int.tryParse(json['commentsCount']?.toString() ??
              json['comments']?.toString() ??
              '0') ??
          0,
      isLiked: json['isLiked'] == true,
    );
  }

  /// Convierte el objeto actual a un Mapa JSON (Útil para almacenamiento local o analytics)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': name,
      'url': url,
      'size': size,
      'created': createdAt.toIso8601String(),
      'thumbnail_url': thumbnailUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'isLiked': isLiked,
    };
  }

  /// 🔗 BONUS: Genera dinámicamente la URL del archivo si se almacena directamente en PocketBase
  /// Uso: `video.getAbsoluteFileUrl('https://api.videitosapp.cl', 'nombre_coleccion')`
  String getAbsoluteFileUrl(
      String baseUrl, String collectionName, String fileName) {
    if (fileName.isEmpty) return url;
    return '$baseUrl/api/files/$collectionName/$id/$fileName';
  }
}
