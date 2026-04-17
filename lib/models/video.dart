class Video {
  final String id;
  final String name;
  final String url;
  final int size;
  final DateTime createdAt;
  final String? thumbnailUrl;

  Video({
    required this.id,
    required this.name,
    required this.url,
    required this.size,
    required this.createdAt,
    this.thumbnailUrl,
  });

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] ?? json['record_id'] ?? '',
      name: json['name'] ?? json['filename'] ?? 'Sin título',
      url: json['url'] ?? json['video_url'] ?? '',
      size: json['size'] ?? json['size_bytes'] ?? 0,
      createdAt: DateTime.parse(json['created'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String()),
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'size': size,
        'created': createdAt.toIso8601String(),
        'thumbnail_url': thumbnailUrl,
      };
}
