import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Search tracks with query
  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final searchList = await _yt.search.search(query);
      return searchList.take(25).map((video) {
        return Track(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          durationMs: video.duration?.inMilliseconds ?? 0,
          thumbnailUrl: video.thumbnails.mediumResUrl,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get Top / Trending Music
  Future<List<Track>> getTopMusic({int limit = 15}) async {
    try {
      // Search for top trending music songs
      final results = await _yt.search.search('Top Trending Music Hits');
      return results.take(limit).map((video) {
        return Track(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          durationMs: video.duration?.inMilliseconds ?? 0,
          thumbnailUrl: video.thumbnails.mediumResUrl,
        );
      }).toList();
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

  void dispose() {
    _yt.close();
  }
}
