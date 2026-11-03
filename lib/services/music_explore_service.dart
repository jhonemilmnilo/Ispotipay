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

  /// Curated Artist Albums & Spotlights (One artist per album collection)
  List<Playlist> getArtistAlbums() {
    return const [
      Playlist(
        id: 'album_taylor_swift',
        title: 'Taylor Swift: The Eras Collection',
        description: 'Complete studio anthology & greatest hits',
        thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&q=80',
        searchQuery: 'Taylor Swift',
      ),
      Playlist(
        id: 'album_the_weeknd',
        title: 'The Weeknd: After Hours & Highlights',
        description: 'Atmospheric R&B, pop anthems & synth vibes',
        thumbnailUrl: 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?w=500&q=80',
        searchQuery: 'The Weeknd',
      ),
      Playlist(
        id: 'album_maki',
        title: 'Maki: OPM Breakthrough',
        description: 'Dilaw, Namumula, Kahit Kailan & solo hits',
        thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&q=80',
        searchQuery: 'Maki',
      ),
      Playlist(
        id: 'album_bruno_mars',
        title: 'Bruno Mars: 24K Magic & Classics',
        description: 'Funk grooves, smooth ballads & pop soul',
        thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&q=80',
        searchQuery: 'Bruno Mars',
      ),
      Playlist(
        id: 'album_billie_eilish',
        title: 'Billie Eilish: Hit Me Hard & Soft',
        description: 'Hypnotic dark pop & intimate melodies',
        thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
        searchQuery: 'Billie Eilish',
      ),
      Playlist(
        id: 'album_olivia_rodrigo',
        title: 'Olivia Rodrigo: GUTS & SOUR',
        description: 'Raw teen angst, pop-rock & piano ballads',
        thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&q=80',
        searchQuery: 'Olivia Rodrigo',
      ),
      Playlist(
        id: 'album_dilaw',
        title: 'Dilaw: Sansinukob & Rock Anthems',
        description: 'Uhaw, Orasa, 3019 & expressive indie rock',
        thumbnailUrl: 'https://images.unsplash.com/photo-1498038432885-c6f3f1b912ee?w=500&q=80',
        searchQuery: 'Dilaw',
      ),
      Playlist(
        id: 'album_ariana_grande',
        title: 'Ariana Grande: Eternal Sunshine',
        description: 'Powerhouse vocals, sweet trap-pop & R&B',
        thumbnailUrl: 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?w=500&q=80',
        searchQuery: 'Ariana Grande',
      ),
      Playlist(
        id: 'album_ed_sheeran',
        title: 'Ed Sheeran: Mathematics & Acoustics',
        description: 'Loop pedal anthems & emotional love songs',
        thumbnailUrl: 'https://images.unsplash.com/photo-1510915361894-db8b60106cb1?w=500&q=80',
        searchQuery: 'Ed Sheeran',
      ),
      Playlist(
        id: 'album_post_malone',
        title: 'Post Malone: Austin & Greatest Hits',
        description: 'Melodic rap, pop fusion & acoustic grit',
        thumbnailUrl: 'https://images.unsplash.com/photo-1508700115892-45ecd05ae2ad?w=500&q=80',
        searchQuery: 'Post Malone',
      ),
      Playlist(
        id: 'album_sza',
        title: 'SZA: SOS & Deluxe Classics',
        description: 'Introspective R&B, silky melodies & honest storytelling',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&q=80',
        searchQuery: 'SZA',
      ),
      Playlist(
        id: 'album_cup_of_joe',
        title: 'Cup of Joe: Patutunguhan',
        description: 'Tingin, Estranghero & heartfelt Baguio indie pop',
        thumbnailUrl: 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500&q=80',
        searchQuery: 'Cup of Joe',
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

        final seenIds = <String>{};
        final seenTitles = <String>{};
        final tracks = <Track>[];

        for (final item in results) {
          final trackId = item['trackId'].toString();
          final title = item['trackName'] as String? ?? 'Unknown Title';
          final artist = item['artistName'] as String? ?? 'Unknown Artist';
          final album = item['collectionName'] as String?;
          final durationMs = (item['trackTimeMillis'] as num?)?.toInt() ?? 0;
          final artworkUrl = (item['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');

          // Strict deduplication by trackId and clean normalized title+artist
          final normalizedKey = '${title.toLowerCase().trim()}_${artist.toLowerCase().trim()}';
          if (!seenIds.contains(trackId) && !seenTitles.contains(normalizedKey)) {
            seenIds.add(trackId);
            seenTitles.add(normalizedKey);
            tracks.add(
              Track(
                id: trackId,
                title: title,
                artist: artist,
                album: album,
                durationMs: durationMs,
                thumbnailUrl: artworkUrl,
              ),
            );
          }
        }

        return tracks;
      }
    } catch (_) {}

    return [];
  }

  /// Search matching Artists and Albums via iTunes Search API
  Future<List<Playlist>> searchArtistsAndAlbums(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final List<Playlist> matchedPlaylists = [];
    final seenTitles = <String>{};

    try {
      final encoded = Uri.encodeComponent(query.trim());

      // Query both albums and music artists in parallel
      final albumUrl = Uri.parse(
        'https://itunes.apple.com/search?term=$encoded&entity=album&limit=$limit',
      );
      final artistUrl = Uri.parse(
        'https://itunes.apple.com/search?term=$encoded&entity=musicArtist&limit=5',
      );

      final responses = await Future.wait([
        _httpClient.get(albumUrl).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('{}', 500)),
        _httpClient.get(artistUrl).timeout(const Duration(seconds: 5)).catchError((_) => http.Response('{}', 500)),
      ]);

      // 1. Process matching Artists
      if (responses[1].statusCode == 200) {
        final artistData = json.decode(responses[1].body) as Map<String, dynamic>;
        final artistResults = artistData['results'] as List? ?? [];
        for (final a in artistResults) {
          final artistName = a['artistName'] as String? ?? '';
          if (artistName.isNotEmpty && !seenTitles.contains(artistName.toLowerCase())) {
            seenTitles.add(artistName.toLowerCase());
            matchedPlaylists.add(
              Playlist(
                id: 'artist_${a['artistId'] ?? artistName.hashCode}',
                title: artistName,
                description: 'Artist Discography & Top Tracks',
                thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&q=80',
                searchQuery: artistName,
              ),
            );
          }
        }
      }

      // 2. Process matching Albums
      if (responses[0].statusCode == 200) {
        final albumData = json.decode(responses[0].body) as Map<String, dynamic>;
        final albumResults = albumData['results'] as List? ?? [];
        for (final alb in albumResults) {
          final albumName = alb['collectionName'] as String? ?? '';
          final artistName = alb['artistName'] as String? ?? '';
          final artwork = (alb['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb');
          final key = '${albumName.toLowerCase()}_${artistName.toLowerCase()}';

          if (albumName.isNotEmpty && !seenTitles.contains(key)) {
            seenTitles.add(key);
            matchedPlaylists.add(
              Playlist(
                id: 'album_${alb['collectionId'] ?? key.hashCode}',
                title: albumName,
                description: 'Album by $artistName',
                thumbnailUrl: artwork,
                searchQuery: '$albumName $artistName',
              ),
            );
          }
        }
      }
    } catch (_) {}

    return matchedPlaylists;
  }

  /// Search tracks by lyrics content using LRCLIB search endpoint, then enrich with iTunes metadata
  Future<List<Track>> searchTracksByLyrics(String lyricsQuery, {int limit = 15}) async {
    if (lyricsQuery.trim().isEmpty) return [];

    try {
      final encoded = Uri.encodeComponent(lyricsQuery.trim());
      final lrclibUrl = Uri.parse('https://lrclib.net/api/search?q=$encoded');

      final response = await _httpClient.get(lrclibUrl, headers: {
        'User-Agent': 'ispotipay-music-player (v1.0.0)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final results = json.decode(response.body) as List? ?? [];
        final List<Track> lyricMatches = [];
        final seenKeys = <String>{};

        for (final item in results) {
          final trackName = item['trackName'] as String? ?? '';
          final artistName = item['artistName'] as String? ?? '';
          final durationSec = (item['duration'] as num?)?.toInt() ?? 0;
          final syncedLyrics = item['syncedLyrics'] as String?;
          final plainLyrics = item['plainLyrics'] as String?;

          // Must have matching lyrics text
          final hasLyrics = (syncedLyrics != null && syncedLyrics.isNotEmpty) ||
              (plainLyrics != null && plainLyrics.isNotEmpty);

          if (trackName.isNotEmpty && artistName.isNotEmpty && hasLyrics) {
            final key = '${trackName.toLowerCase().trim()}_${artistName.toLowerCase().trim()}';
            if (!seenKeys.contains(key)) {
              seenKeys.add(key);

              // Find high-res artwork & studio metadata via iTunes for this song
              final itunesCandidates = await searchTracks('$trackName $artistName', limit: 1);
              if (itunesCandidates.isNotEmpty) {
                lyricMatches.add(itunesCandidates.first);
              } else {
                lyricMatches.add(
                  Track(
                    id: 'lrc_${trackName.hashCode}_${artistName.hashCode}',
                    title: trackName,
                    artist: artistName,
                    album: item['albumName'] as String?,
                    durationMs: durationSec * 1000,
                  ),
                );
              }

              if (lyricMatches.length >= limit) break;
            }
          }
        }
        return lyricMatches;
      }
    } catch (_) {}

    return [];
  }

  /// Get live search suggestions/recommendations based on query or popular topics
  List<String> getSearchSuggestions(String query) {
    final clean = query.trim().toLowerCase();

    final allPopularSuggestions = [
      'Taylor Swift',
      'Maki Dilaw',
      'Cup of Joe',
      'The Weeknd',
      'SZA SOS',
      'Post Malone',
      'Billie Eilish',
      'Dilaw Uhaw',
      'Bruno Mars Die With A Smile',
      'Sabrina Carpenter Espresso',
      'Ed Sheeran Shape of You',
      'Coldplay Yellow',
      'Hev Abi',
      'TJ Monterde Palagi',
      'Arthur Nery Pagsamo',
      'Dionela Sining',
      'Olivia Rodrigo',
      'Ariana Grande',
      'Laufey From The Start',
      'Kendrick Lamar Not Like Us',
    ];

    if (clean.isEmpty) {
      return allPopularSuggestions.take(6).toList();
    }

    final matches = allPopularSuggestions
        .where((s) => s.toLowerCase().contains(clean))
        .toList();

    if (matches.isEmpty) {
      // Suggest search prompts
      return [
        query.trim(),
        '${query.trim()} lyrics',
        '${query.trim()} album',
        '${query.trim()} acoustic',
      ];
    }

    return matches.take(6).toList();
  }
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

  /// YouTube Music Radio Queue: Get sonically-aligned Up Next tracks for currently playing track
  Future<List<Track>> getUpNextQueue(Track currentTrack, {int limit = 20}) async {
    final radioQueries = await _recEngine.getRadioQueriesForTrack(currentTrack, count: 6);
    final futureResults = radioQueries.map((q) => searchTracks(q, limit: 6));
    final fetchedLists = await Future.wait(futureResults);

    final interleaved = _recEngine.interleaveDiverseArtists(
      fetchedLists,
      limit: limit,
      strictUniqueArtists: true,
    );

    // Filter out the current track itself if it appeared in results
    return interleaved.where((t) => t.id != currentTrack.id).toList();
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
