import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Curated queries for single tracks and music exploration
  static const List<String> _seedQueries = [
    'Top Global Hits Official Audio',
    'OPM Trending Hits Official Audio',
    'Billboard Hot 100 Official Music',
    'Viral Pop Hits Official Audio',
    'R&B Chill Hits Official Music',
  ];

  int _queryIndex = 0;

  /// Search tracks with duration filter (30 seconds to 10 minutes max)
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return [];

    try {
      final searchResults = await _yt.search.searchContent('$query audio');
      final List<Track> tracks = [];

      for (final item in searchResults) {
        if (item is SearchVideo) {
          final durationMs = _parseDuration(item.duration);
          final durationSec = durationMs / 1000;

          // Guardrail: Only accept single tracks (30s to 10 mins)
          if (durationSec >= 30 && durationSec <= 600) {
            final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last.url.toString() : null;
            tracks.add(
              Track(
                id: item.id.value,
                title: _cleanTitle(item.title),
                artist: item.author,
                durationMs: durationMs,
                thumbnailUrl: thumb,
              ),
            );
          }
        }
        if (tracks.length >= limit) break;
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Get Top / Trending Single Music (30s to 10 mins)
  Future<List<Track>> getTopMusic({int limit = 15}) async {
    try {
      final searchResults = await _yt.search.searchContent('Billboard Hot 100 Official Audio');
      final List<Track> tracks = [];

      for (final item in searchResults) {
        if (item is SearchVideo) {
          final durationMs = _parseDuration(item.duration);
          final durationSec = durationMs / 1000;

          if (durationSec >= 30 && durationSec <= 600) {
            final thumb = item.thumbnails.isNotEmpty ? item.thumbnails.last.url.toString() : null;
            tracks.add(
              Track(
                id: item.id.value,
                title: _cleanTitle(item.title),
                artist: item.author,
                durationMs: durationMs,
                thumbnailUrl: thumb,
              ),
            );
          }
        }
        if (tracks.length >= limit) break;
      }
      return tracks;
    } catch (_) {
      return [];
    }
  }

  /// Paginated infinite scroll loader for "All Music"
  Future<List<Track>> fetchNextAllMusicBatch({int batchSize = 25}) async {
    final query = _seedQueries[_queryIndex % _seedQueries.length];
    _queryIndex++;
    return await searchTracks(query, limit: batchSize);
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

  String _cleanTitle(String title) {
    return title
        .replaceAll(RegExp(r'\[Official Audio\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Official Audio\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Official Music Video\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Official Music Video\)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[Lyric Video\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(Lyric Video\)', caseSensitive: false), '')
        .trim();
  }

  void dispose() {
    _yt.close();
  }
}
