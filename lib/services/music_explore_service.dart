import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Search tracks safely using searchContent
  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final searchResults = await _yt.search.searchContent(query);
      final List<Track> tracks = [];

      for (final item in searchResults) {
        if (item is SearchVideo) {
          final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last.url.toString() : null;
          tracks.add(
            Track(
              id: item.id.value,
              title: item.title,
              artist: item.author,
              durationMs: _parseDuration(item.duration),
              thumbnailUrl: thumb,
            ),
          );
        }
        if (tracks.length >= 25) break;
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Get Top / Trending Music
  Future<List<Track>> getTopMusic({int limit = 15}) async {
    try {
      final searchResults = await _yt.search.searchContent('Billboard Hot 100 Hits Official');
      final List<Track> tracks = [];

      for (final item in searchResults) {
        if (item is SearchVideo) {
          final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last.url.toString() : null;
          tracks.add(
            Track(
              id: item.id.value,
              title: item.title,
              artist: item.author,
              durationMs: _parseDuration(item.duration),
              thumbnailUrl: thumb,
            ),
          );
        }
        if (tracks.length >= limit) break;
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Fetch audio stream URL for playback
  Future<String?> getAudioStreamUrl(String trackId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(trackId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (_) {
      return null;
    }
  }

  int _parseDuration(String durationStr) {
    try {
      final parts = durationStr.split(':').map(int.parse).toList();
      if (parts.length == 2) {
        return (parts[0] * 60 + parts[1]) * 1000;
      } else if (parts.length == 3) {
        return (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
      }
    } catch (_) {}
    return 0;
  }

  void dispose() {
    _yt.close();
  }
}
