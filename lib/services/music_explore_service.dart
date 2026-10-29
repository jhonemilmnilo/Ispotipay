import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();
  final http.Client _httpClient = http.Client();

  int _pageOffset = 0;

  /// Search real studio tracks via iTunes Search API (clean metadata, no video compilations)
  Future<List<Track>> searchTracks(String query, {int limit = 25}) async {
    if (query.trim().isEmpty) return [];

    try {
      final encoded = Uri.encodeComponent(query.trim());
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=$encoded&entity=song&limit=$limit',
      );

      final response = await _httpClient.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List;

        return results.map((item) {
          final trackId = item['trackId'].toString();
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final album = item['collectionName'] as String?;
          final durationMs = (item['trackTimeMillis'] as num?)?.toInt() ?? 0;
          final artworkUrl = (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');

          return Track(
            id: trackId,
            title: title,
            artist: artist,
            album: album,
            durationMs: durationMs,
            thumbnailUrl: artworkUrl,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Get Official Top Hits from iTunes Top Songs Chart (Philippines + Global)
  Future<List<Track>> getTopMusic({int limit = 15}) async {
    try {
      final url = Uri.parse('https://itunes.apple.com/ph/rss/topsongs/limit=$limit/json');
      final response = await _httpClient.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final feed = data['feed'] as Map<String, dynamic>?;
        final entries = feed?['entry'] as List?;

        if (entries != null) {
          return entries.map((e) {
            final id = e['id']?['attributes']?['im:id']?.toString() ??
                e['im:name']?['label']?.hashCode.toString() ??
                '';
            final title = e['im:name']?['label'] as String? ?? 'Unknown Title';
            final artist = e['im:artist']?['label'] as String? ?? 'Unknown Artist';
            final images = e['im:image'] as List?;
            final artworkUrl = images?.isNotEmpty == true
                ? images!.last['label'] as String?
                : null;

            return Track(
              id: id,
              title: title,
              artist: artist,
              durationMs: 210000,
              thumbnailUrl: artworkUrl,
            );
          }).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Paginated infinite scroll for "All Music" with 25-item chunks
  Future<List<Track>> fetchNextAllMusicBatch({int batchSize = 25}) async {
    final searchTerms = ['pop hits', 'opm hits', 'top trending', 'acoustic hits', 'rnb hits'];
    final term = searchTerms[(_pageOffset ~/ batchSize) % searchTerms.length];
    final offset = _pageOffset % 100;
    _pageOffset += batchSize;

    try {
      final encoded = Uri.encodeComponent(term);
      final url = Uri.parse(
        'https://itunes.apple.com/search?term=$encoded&entity=song&limit=$batchSize&offset=$offset',
      );

      final response = await _httpClient.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final results = data['results'] as List;

        return results.map((item) {
          final trackId = item['trackId'].toString();
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final album = item['collectionName'] as String?;
          final durationMs = (item['trackTimeMillis'] as num?)?.toInt() ?? 0;
          final artworkUrl = (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');

          return Track(
            id: trackId,
            title: title,
            artist: artist,
            album: album,
            durationMs: durationMs,
            thumbnailUrl: artworkUrl,
          );
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  /// Resolve exact matching playable stream URL by song title & artist
  Future<String?> getAudioStreamUrl(String trackId, {String? title, String? artist}) async {
    try {
      final searchQuery = (title != null && artist != null)
          ? '$title $artist official audio'
          : trackId;

      final searchResults = await _yt.search.searchContent(searchQuery);

      for (final item in searchResults) {
        if (item is SearchVideo) {
          final durationSec = _parseDuration(item.duration) / 1000;
          if (durationSec >= 30 && durationSec <= 600) {
            final manifest = await _yt.videos.streamsClient.getManifest(item.id);

            // Progressive stream (itag 18 - 360p mp4) has no SABR/403 throttling
            // and plays smoothly through ExoPlayer on all Android devices
            if (manifest.muxed.isNotEmpty) {
              final progressiveStream = manifest.muxed.firstWhere(
                (s) => s.tag == 18,
                orElse: () => manifest.muxed.first,
              );
              return progressiveStream.url.toString();
            }

            // Fallback to highest bitrate audio
            if (manifest.audioOnly.isNotEmpty) {
              return manifest.audioOnly.withHighestBitrate().url.toString();
            }
          }
        }
      }
    } catch (_) {}

    return null;
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
    _httpClient.close();
    _yt.close();
  }
}
