import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/playlist.dart';
import '../models/track.dart';
import 'recommendation_engine.dart';

class MusicExploreService {
  final YoutubeExplode _yt = YoutubeExplode();
  final http.Client _httpClient = http.Client();
  final RecommendationEngine _recEngine = RecommendationEngine();

  int _pageOffset = 0;

  /// Paginated, non-repeating Top Playlists (15 items per batch)
  List<Playlist> getTopPlaylists({int offset = 0, int limit = 15}) {
    final allCuratedPlaylists = [
      const Playlist(
        id: 'pl_1',
        title: "Today's Top Hits",
        description: 'The hottest tracks worldwide',
        thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
        searchQuery: 'Top Global Pop Hits',
      ),
      const Playlist(
        id: 'pl_2',
        title: 'OPM Favorites',
        description: 'Pinoy pride & timeless anthems',
        thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
        searchQuery: 'OPM Trending Hits Maki Dilaw',
      ),
      const Playlist(
        id: 'pl_3',
        title: 'Chill & Relax Vibes',
        description: 'Mellow beats for unwinding',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        searchQuery: 'Acoustic Chill Hits',
      ),
      const Playlist(
        id: 'pl_4',
        title: 'Viral R&B Soul',
        description: 'Smooth rhythms & deep grooves',
        thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        searchQuery: 'Top R&B Soul Hits',
      ),
      const Playlist(
        id: 'pl_5',
        title: 'Workout Energy',
        description: 'High tempo beats to stay pumped',
        thumbnailUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&q=80',
        searchQuery: 'High Energy Workout Hits',
      ),
      const Playlist(
        id: 'pl_6',
        title: 'Pinoy Rock & Alt',
        description: 'Classic & modern local rock',
        thumbnailUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
        searchQuery: 'Pinoy Rock OPM Classic',
      ),
      const Playlist(
        id: 'pl_7',
        title: 'Hip-Hop Beats',
        description: 'Heavy bass & lyricism',
        thumbnailUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80',
        searchQuery: 'Trending Hip Hop Rap Hits',
      ),
      const Playlist(
        id: 'pl_8',
        title: 'Acoustic Sunday',
        description: 'Coffee, rain & guitar strings',
        thumbnailUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80',
        searchQuery: 'Acoustic Sunday Covers',
      ),
      const Playlist(
        id: 'pl_9',
        title: 'EDM Festival',
        description: 'Electrifying festival anthems',
        thumbnailUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&q=80',
        searchQuery: 'Best EDM Festival Hits',
      ),
      const Playlist(
        id: 'pl_10',
        title: 'K-Pop Essentials',
        description: 'Korean pop sensations',
        thumbnailUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
        searchQuery: 'Top Kpop Hits',
      ),
      const Playlist(
        id: 'pl_11',
        title: 'Focus & Study',
        description: 'Instrumental flow for deep work',
        thumbnailUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&q=80',
        searchQuery: 'Lofi Study Beats Chill',
      ),
      const Playlist(
        id: 'pl_12',
        title: 'Late Night Drives',
        description: 'Atmospheric nocturnal tunes',
        thumbnailUrl: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=500&q=80',
        searchQuery: 'Late Night Synthwave Chill',
      ),
      const Playlist(
        id: 'pl_13',
        title: 'Golden Era 90s & 2000s',
        description: 'Throwback to iconic classics',
        thumbnailUrl: 'https://images.unsplash.com/photo-1461360370896-922624d12aa1?w=500&q=80',
        searchQuery: 'Best 2000s Pop Hits',
      ),
      const Playlist(
        id: 'pl_14',
        title: 'Heartbreak & Hugot',
        description: 'Deep emotional ballads',
        thumbnailUrl: 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=500&q=80',
        searchQuery: 'OPM Hugot Sad Songs',
      ),
      const Playlist(
        id: 'pl_15',
        title: 'Indie Discovery',
        description: 'Underground gems & fresh talent',
        thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
        searchQuery: 'Indie Pop Chill Gems',
      ),
      const Playlist(
        id: 'pl_16',
        title: 'Jazz & Coffee',
        description: 'Smooth jazz for relaxing afternoons',
        thumbnailUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500&q=80',
        searchQuery: 'Smooth Coffee Jazz Hits',
      ),
      const Playlist(
        id: 'pl_17',
        title: 'Party Weekend',
        description: 'Non-stop club and dance bangers',
        thumbnailUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
        searchQuery: 'Party Dance Bangers Hits',
      ),
      const Playlist(
        id: 'pl_18',
        title: 'Classical Essentials',
        description: 'Timeless orchestral masterworks',
        thumbnailUrl: 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
        searchQuery: 'Best Classical Music Masterpieces',
      ),
      const Playlist(
        id: 'pl_19',
        title: 'Reggae & Island Vibes',
        description: 'Feel-good sunny rhythms',
        thumbnailUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
        searchQuery: 'Island Reggae Roots Hits',
      ),
      const Playlist(
        id: 'pl_20',
        title: 'Anime Openings & OST',
        description: 'Epic Japanese anime tracks',
        thumbnailUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=500&q=80',
        searchQuery: 'Top Anime Openings Hits',
      ),
      const Playlist(
        id: 'pl_21',
        title: 'City Pop Tokyo',
        description: 'Retro 80s Japanese grooves',
        thumbnailUrl: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=500&q=80',
        searchQuery: 'Japanese City Pop 80s Hits',
      ),
      const Playlist(
        id: 'pl_22',
        title: 'Bossa Nova Sunset',
        description: 'Breezy Brazilian acoustics',
        thumbnailUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
        searchQuery: 'Bossa Nova Sunset Vibes',
      ),
      const Playlist(
        id: 'pl_23',
        title: 'Gaming & Cyberpunk',
        description: 'Futuristic synth bass & electronic beats',
        thumbnailUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=500&q=80',
        searchQuery: 'Cyberpunk Electronic Synth Gaming',
      ),
      const Playlist(
        id: 'pl_24',
        title: 'Deep House Sunset',
        description: 'Hypnotic club rhythms',
        thumbnailUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&q=80',
        searchQuery: 'Deep House Chill Sunset',
      ),
      const Playlist(
        id: 'pl_25',
        title: 'Lo-Fi Rain & Sleep',
        description: 'Gentle textures for peaceful slumber',
        thumbnailUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&q=80',
        searchQuery: 'Lofi Rain Sleep Chill Beats',
      ),
      const Playlist(
        id: 'pl_26',
        title: 'Latin Fiesta Hits',
        description: 'Reggaeton & vibrant Latin pop',
        thumbnailUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
        searchQuery: 'Top Latin Reggaeton Hits',
      ),
      const Playlist(
        id: 'pl_27',
        title: 'Blues & Soul Classics',
        description: 'Raw emotion & electric guitars',
        thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
        searchQuery: 'Classic Blues and Soul Hits',
      ),
      const Playlist(
        id: 'pl_28',
        title: 'Roadtrip Rock Anthems',
        description: 'Classic rock to sing loud in the car',
        thumbnailUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
        searchQuery: 'Classic Rock Roadtrip Hits',
      ),
      const Playlist(
        id: 'pl_29',
        title: 'K-Drama Romance OST',
        description: 'Emotional theme songs from famous dramas',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        searchQuery: 'Kdrama Romance OST Hits',
      ),
      const Playlist(
        id: 'pl_30',
        title: 'Neo-Soul Sunday',
        description: 'Rich chords and velvety vocals',
        thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        searchQuery: 'Neo Soul Chill R&B',
      ),
      const Playlist(
        id: 'pl_31',
        title: 'Acoustic Coffeehouse',
        description: 'Warm indie acoustic covers',
        thumbnailUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80',
        searchQuery: 'Acoustic Coffeehouse Indie Covers',
      ),
      const Playlist(
        id: 'pl_32',
        title: 'Country Sunset',
        description: 'Heartfelt storytelling and acoustic guitars',
        thumbnailUrl: 'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=500&q=80',
        searchQuery: 'Top Country Music Hits',
      ),
      const Playlist(
        id: 'pl_33',
        title: 'Trap Nation Wave',
        description: '808s and modern hip-hop flow',
        thumbnailUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80',
        searchQuery: 'Trap Hits Rap Trending',
      ),
      const Playlist(
        id: 'pl_34',
        title: 'Synthwave & Retrowave',
        description: 'Neon 80s nostalgia vibes',
        thumbnailUrl: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=500&q=80',
        searchQuery: 'Synthwave Retrowave 80s',
      ),
      const Playlist(
        id: 'pl_35',
        title: 'Piano Peace',
        description: 'Calming solo piano melodies',
        thumbnailUrl: 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?w=500&q=80',
        searchQuery: 'Peaceful Piano Relaxing Hits',
      ),
      const Playlist(
        id: 'pl_36',
        title: 'Dancehall Reggae',
        description: 'Energetic Jamaican riddims',
        thumbnailUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=500&q=80',
        searchQuery: 'Top Dancehall Reggae Hits',
      ),
      const Playlist(
        id: 'pl_37',
        title: 'Bollywood Hits',
        description: 'Energetic Indian cinema chart-toppers',
        thumbnailUrl: 'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=500&q=80',
        searchQuery: 'Top Bollywood Dance Hits',
      ),
      const Playlist(
        id: 'pl_38',
        title: 'Indie Folk & Wood',
        description: 'Acoustic harmonies and forest vibes',
        thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
        searchQuery: 'Indie Folk Acoustic Anthems',
      ),
      const Playlist(
        id: 'pl_39',
        title: 'Disco Revival',
        description: 'Funk basslines and groove',
        thumbnailUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500&q=80',
        searchQuery: 'Modern Disco Nu Funk Hits',
      ),
      const Playlist(
        id: 'pl_40',
        title: 'Instrumental Sleep Melodies',
        description: 'Deep relaxation soundscapes',
        thumbnailUrl: 'https://images.unsplash.com/photo-1515694346937-94d85e41e6f0?w=500&q=80',
        searchQuery: 'Relaxing Instrumental Sleep Music',
      ),
    ];

    if (offset >= allCuratedPlaylists.length) {
      // Dynamic generative playlists for endless scrolling without duplicates
      final pageIndex = (offset - allCuratedPlaylists.length) ~/ limit + 1;
      return List.generate(limit, (i) {
        final itemNumber = offset + i + 1;
        return Playlist(
          id: 'gen_pl_$itemNumber',
          title: 'Special Mix Vol. $itemNumber',
          description: 'Curated mix edition #$pageIndex',
          thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
          searchQuery: 'Hit Music Mix Vol $itemNumber',
        );
      });
    }

    return allCuratedPlaylists.skip(offset).take(limit).toList();
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

  /// Get Official Top Hits with infinite paginated scrolling (15 per chunk) across country feeds
  Future<List<Track>> getTopMusic({int offset = 0, int limit = 15}) async {
    final countryFeeds = ['ph', 'us', 'gb', 'jp', 'kr'];
    final country = countryFeeds[(offset ~/ limit) % countryFeeds.length];

    try {
      final url = Uri.parse('https://itunes.apple.com/$country/rss/topsongs/limit=50/json');
      final response = await _httpClient.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final feed = data['feed'] as Map<String, dynamic>?;
        final entries = feed?['entry'] as List?;

        if (entries != null) {
          final mapped = entries.map((e) {
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

          final start = (offset % 50);
          final chunk = mapped.skip(start).take(limit).toList();
          if (chunk.isNotEmpty) return chunk;
          return mapped.take(limit).toList();
        }
      }
    } catch (_) {}

    return [];
  }

  /// Algorithm-based recommended infinite scroll for "All Music" with diverse interleaved artists
  Future<List<Track>> fetchNextAllMusicBatch({int batchSize = 25}) async {
    final chunkIndex = _pageOffset ~/ batchSize;
    _pageOffset += batchSize;

    // Fetch across 4 distinct queries in parallel to ensure diverse artists
    final seedQueries = await _recEngine.getMultiSeedQueries(
      count: 4,
      offsetIndex: chunkIndex * 3,
    );

    final futureResults = seedQueries.map((q) => searchTracks(q, limit: 10));
    final fetchedLists = await Future.wait(futureResults);

    // Interleave so no contiguous tracks come from the same artist
    return _recEngine.interleaveDiverseArtists(fetchedLists, limit: batchSize);
  }

  /// Get Personalized "Recommended for You" tracks (capped at 20, strictly 1 song per unique artist)
  Future<List<Track>> getRecommendedTracks({int limit = 20}) async {
    // Query 15 diverse seed queries to guarantee at least 20 unique artists
    final seedQueries = await _recEngine.getMultiSeedQueries(
      count: 15,
      offsetIndex: DateTime.now().minute,
    );

    final futureResults = seedQueries.map((q) => searchTracks(q, limit: 5));
    final fetchedLists = await Future.wait(futureResults);

    return _recEngine.interleaveDiverseArtists(
      fetchedLists,
      limit: limit,
      strictUniqueArtists: true,
    );
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
