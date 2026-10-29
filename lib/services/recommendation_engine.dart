import 'dart:math';
import '../models/track.dart';
import 'database_service.dart';

class RecommendationEngine {
  final DatabaseService _dbService = DatabaseService();
  final Random _random = Random();

  // Curated genre discovery pools for dynamic 80/20 exploration (Spotify/YT Music style)
  static const List<String> _discoveryPool = [
    'OPM Indie Hits',
    'Viral Pop Billboard',
    'Acoustic Chill Covers',
    'Modern R&B Grooves',
    'Lofi Beats Relaxation',
    'Synthwave Chillout',
    'Upbeat Dance Electronic',
    'Soul & Blues Modern',
  ];

  /// Extract weighted taste seeds based on User Favorites, Most Played, and Recents
  Future<List<String>> getTasteSeeds() async {
    final favorites = await _dbService.getFavorites(limit: 25);
    final mostPlayed = await _dbService.getMostPlayed(limit: 10);
    final recents = await _dbService.getRecents(limit: 15);

    final Map<String, int> artistWeight = {};

    void addArtist(String rawArtist, int weight) {
      final clean = rawArtist.split(RegExp(r'[,&]')).first.trim();
      if (clean.isNotEmpty && clean.length > 2) {
        artistWeight[clean] = (artistWeight[clean] ?? 0) + weight;
      }
    }

    // Weighting: Favorites (5x) > Most Played (3x) > Recents (1x)
    for (final track in favorites) {
      addArtist(track.artist, 5);
    }
    for (final track in mostPlayed) {
      addArtist(track.artist, 3 * (track.playCount > 0 ? track.playCount : 1));
    }
    for (final track in recents) {
      addArtist(track.artist, 1);
    }

    if (artistWeight.isEmpty) {
      return [
        'Maki',
        'Billie Eilish',
        'Sabrina Carpenter',
        'Taylor Swift',
        'The Weeknd',
        'Ben&Ben',
        'Bruno Mars',
        'Olivia Rodrigo',
        'Arthur Nery',
        'SZA',
      ];
    }

    // Sort by affinity weight descending
    final sorted = artistWeight.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((e) => e.key).toList();
  }

  /// Get distinct seeds for diverse parallel fetching
  Future<List<String>> getMultiSeedQueries({int count = 4, int offsetIndex = 0}) async {
    final seeds = await getTasteSeeds();
    final List<String> queries = [];

    for (int i = 0; i < count; i++) {
      final index = (offsetIndex + i);
      // 80% Personalized Taste, 20% Fresh Discovery pool (like YT Music Radio / Spotify Discover)
      if (i % 5 == 4) {
        queries.add(_discoveryPool[_random.nextInt(_discoveryPool.length)]);
      } else {
        final seed = seeds[index % seeds.length];
        queries.add(seed);
      }
    }

    return queries;
  }

  /// Interleave tracks round-robin style
  /// If [strictUniqueArtists] is true, exactly 1 song maximum per artist is selected
  List<Track> interleaveDiverseArtists(
    List<List<Track>> trackLists, {
    int limit = 25,
    bool strictUniqueArtists = false,
  }) {
    final List<Track> interleaved = [];
    final Set<String> seenTrackIds = {};
    final Set<String> seenTitles = {};
    final Set<String> seenArtists = {};
    String lastArtist = '';

    int maxLen = 0;
    for (final list in trackLists) {
      if (list.length > maxLen) maxLen = list.length;
    }

    for (int depth = 0; depth < maxLen; depth++) {
      for (final list in trackLists) {
        if (interleaved.length >= limit) break;
        if (depth < list.length) {
          final track = list[depth];
          final cleanTitle = track.title.toLowerCase().trim();
          final artistKey = track.artist.toLowerCase().split(RegExp(r'[,&]')).first.trim();

          if (seenTrackIds.contains(track.id) || seenTitles.contains(cleanTitle)) {
            continue;
          }

          if (strictUniqueArtists) {
            // Strictly enforce only 1 song per distinct artist
            if (!seenArtists.contains(artistKey)) {
              seenTrackIds.add(track.id);
              seenTitles.add(cleanTitle);
              seenArtists.add(artistKey);
              interleaved.add(track);
            }
          } else {
            // Avoid contiguous back-to-back songs by the same artist
            if (artistKey != lastArtist) {
              seenTrackIds.add(track.id);
              seenTitles.add(cleanTitle);
              interleaved.add(track);
              lastArtist = artistKey;
            }
          }
        }
      }
      if (interleaved.length >= limit) break;
    }

    // Second pass fill-up if strict spacing filtered too many
    if (interleaved.length < limit) {
      for (final list in trackLists) {
        for (final track in list) {
          if (interleaved.length >= limit) break;
          final cleanTitle = track.title.toLowerCase().trim();
          final artistKey = track.artist.toLowerCase().split(RegExp(r'[,&]')).first.trim();

          if (!seenTrackIds.contains(track.id) && !seenTitles.contains(cleanTitle)) {
            if (strictUniqueArtists && seenArtists.contains(artistKey)) {
              continue;
            }
            seenTrackIds.add(track.id);
            seenTitles.add(cleanTitle);
            seenArtists.add(artistKey);
            interleaved.add(track);
          }
        }
      }
    }

    return interleaved;
  }
}
