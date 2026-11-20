/// Represents a user-created local album for grouping downloaded tracks.
class DownloadAlbum {
  final String id;
  final String name;
  final int createdAt;
  final int trackCount;
  final String? coverUrl;

  const DownloadAlbum({
    required this.id,
    required this.name,
    required this.createdAt,
    this.trackCount = 0,
    this.coverUrl,
  });

  factory DownloadAlbum.fromMap(Map<String, dynamic> map) {
    return DownloadAlbum(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: (map['created_at'] as num).toInt(),
      trackCount: (map['track_count'] as num?)?.toInt() ?? 0,
      coverUrl: map['cover_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
    };
  }

  DownloadAlbum copyWith({
    String? id,
    String? name,
    int? createdAt,
    int? trackCount,
    String? coverUrl,
  }) {
    return DownloadAlbum(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      trackCount: trackCount ?? this.trackCount,
      coverUrl: coverUrl ?? this.coverUrl,
    );
  }
}
