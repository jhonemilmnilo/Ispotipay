import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/playlist.dart';
import '../models/track.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();
  final http.Client _httpClient = http.Client();

  int _pageOffset = 0;

  /// Curated Top Playlists
  List<Playlist> getTopPlaylists() {
    return const [
      Playlist(
        id: 'pl_1',
        title: "Today's Top Hits",
        description: 'The hottest tracks right now',
        thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
        searchQuery: 'Top Global Pop Hits',
      ),
      Playlist(
        id: 'pl_2',
        title: 'OPM Favorites',
        description: 'Pinoy pride & timeless anthems',
        thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
        searchQuery: 'OPM Trending Hits Maki Dilaw',
      ),
      Playlist(
        id: 'pl_3',
        title: 'Chill & Relax Vibes',
        description: 'Mellow beats for unwinding',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        searchQuery: 'Acoustic Chill Hits',
      ),
      Playlist(
        id: 'pl_4',
        title: 'Viral R&B Soul',
        description: 'Smooth rhythms & deep grooves',
        thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        searchQuery: 'Top R&B Soul Hits',
      ),
      Playlist(
        id: 'pl_5',
        title: 'Workout Energy',
        description: 'High tempo beats to stay pumped',
        thumbnailUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&q=80',
        searchQuery: 'High Energy Workout Hits',
      ),
    ];
  }

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

  /// Resolve exact matching playable stream URL with strict 0-delay duration delta ranking
  Future<String?> getAudioStreamUrl(
    String trackId, {
    String? title,
    String? artist,
    int? targetDurationMs,
  }) async {
    try {
      final cleanTitle = (title ?? '').replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim();
      final cleanArtist = (artist ?? '').trim();

      // Search across clean lyric videos and official studio audio tracks
      final queries = [
        '$cleanTitle $cleanArtist lyrics',
        '$cleanTitle $cleanArtist audio',
        '"$cleanTitle" "$cleanArtist" - Topic',
      ];

      final List<SearchVideo> allCandidates = [];

      for (final query in queries) {
        final results = await _yt.search.searchContent(query);
        for (final item in results) {
          if (item is SearchVideo) {
            final lowerTitle = item.title.toLowerCase();
            // Disqualify long music videos, live performances, and interviews with intros
            if (lowerTitle.contains('official music video') ||
                lowerTitle.contains(' mv ') ||
                lowerTitle.contains('live') ||
                lowerTitle.contains('interview') ||
                lowerTitle.contains('intro') ||
                lowerTitle.contains('trailer') ||
                lowerTitle.contains('reaction')) {
              continue;
            }
            allCandidates.add(item);
          }
        }
        if (allCandidates.length >= 12) break;
      }

      if (allCandidates.isEmpty) return null;

      // Sort all candidates by lowest duration delta (gap between video and studio track)
      if (targetDurationMs != null && targetDurationMs > 0) {
        allCandidates.sort((a, b) {
          final diffA = (_parseDuration(a.duration) - targetDurationMs).abs();
          final diffB = (_parseDuration(b.duration) - targetDurationMs).abs();
          return diffA.compareTo(diffB);
        });
      }

      // Pick the best candidate (lowest delta, closest to exact studio cut)
      final bestMatch = allCandidates.first;

      final manifest = await _yt.videos.streamsClient.getManifest(bestMatch.id);

      if (manifest.muxed.isNotEmpty) {
        final progressiveStream = manifest.muxed.firstWhere(
          (s) => s.tag == 18,
          orElse: () => manifest.muxed.first,
        );
        return progressiveStream.url.toString();
      }

      if (manifest.audioOnly.isNotEmpty) {
        return manifest.audioOnly.withHighestBitrate().url.toString();
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
