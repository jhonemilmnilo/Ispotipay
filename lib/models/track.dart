import 'dart:convert';

/// Represents a single track across streaming, offline, and database storage.
class Track {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int durationMs;
  final String? thumbnailUrl;
  final String? audioPath;
  final String? lyricsPath;
  final int playCount;
  final int? lastPlayedAt;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    required this.durationMs,
    this.thumbnailUrl,
    this.audioPath,
    this.lyricsPath,
    this.playCount = 0,
    this.lastPlayedAt,
  });

  bool get isDownloaded => audioPath != null && audioPath!.isNotEmpty;

  Track copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? durationMs,
    String? thumbnailUrl,
    String? audioPath,
    String? lyricsPath,
    int? playCount,
    int? lastPlayedAt,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      audioPath: audioPath ?? this.audioPath,
      lyricsPath: lyricsPath ?? this.lyricsPath,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration_ms': durationMs,
      'thumbnail_url': thumbnailUrl,
      'audio_path': audioPath,
      'lyrics_path': lyricsPath,
      'play_count': playCount,
      'last_played_at': lastPlayedAt,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String?,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnail_url'] as String?,
      audioPath: map['audio_path'] as String?,
      lyricsPath: map['lyrics_path'] as String?,
      playCount: (map['play_count'] as num?)?.toInt() ?? 0,
      lastPlayedAt: (map['last_played_at'] as num?)?.toInt(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Track.fromJson(String source) =>
      Track.fromMap(json.decode(source) as Map<String, dynamic>);
}
