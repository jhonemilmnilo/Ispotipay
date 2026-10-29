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

  // Spotify / YouTube Music Style Musical Neighborhood Knowledge Graph
  static const Map<String, List<String>> _artistNeighbors = {
    // Pinoy / OPM
    'maki': ['dilaw', 'cup of joe', 'lola amour', 'arthur nery', 'adie', 'tj monterde', 'sunshine', 'ben&ben', 'zack tabudlo'],
    'dilaw': ['maki', 'cup of joe', 'lola amour', 'ben&ben', 'juan karlos', 'the juans', 'over october'],
    'cup of joe': ['maki', 'dilaw', 'lola amour', 'sunshine', 'adie', 'arthur nery', 'ben&ben'],
    'lola amour': ['dilaw', 'cup of joe', 'maki', 'ben&ben', 'iv of spades', 'zild', 'autotelic'],
    'arthur nery': ['adie', 'maki', 'tj monterde', 'dionela', 'mrld', 'rob deniel', 'ace banzinga'],
    'ben&ben': ['cup of joe', 'lola amour', 'dilaw', 'moira dela torre', 'the juans', 'december avenue', 'maki'],
    'tj monterde': ['kz tandingan', 'arthur nery', 'adie', 'moira dela torre', 'zack tabudlo', 'dionela'],
    'adie': ['arthur nery', 'maki', 'rob deniel', 'mrld', 'janine berdin', 'dionela'],

    // Western Pop & Global Chart
    'billie eilish': ['olivia rodrigo', 'sabrina carpenter', 'phoebe bridgers', 'finneas', 'lana del rey', 'lorde', 'gracie abrams'],
    'sabrina carpenter': ['olivia rodrigo', 'taylor swift', 'chappell roan', 'ariana grande', 'billie eilish', 'tate mcrae', 'dua lipa'],
    'olivia rodrigo': ['sabrina carpenter', 'billie eilish', 'taylor swift', 'conan gray', 'chappell roan', 'gracie abrams', 'paramore'],
    'taylor swift': ['sabrina carpenter', 'gracie abrams', 'olivia rodrigo', 'phoebe bridgers', 'lana del rey', 'ed sheeran', 'harry styles'],
    'the weeknd': ['post malone', 'dua lipa', 'sza', 'bruno mars', 'khalid', 'frank ocean', 'joji', 'doja cat', 'travis scott'],
    'bruno mars': ['anderson .paak', 'the weeknd', 'lady gaga', 'post malone', 'charlie puth', 'silk sonic', 'michael jackson'],
    'sza': ['summer walker', 'jhene aiko', 'the weeknd', 'frank ocean', 'kehlani', 'kali uchis', 'steve lacy', 'brent faiyaz'],
    'post malone': ['the weeknd', 'khalid', 'juice wrld', 'morgan wallen', 'xxxtentacion', 'mac miller', 'shaboozey'],
    'chappell roan': ['sabrina carpenter', 'olivia rodrigo', 'renee rapp', 'boygenius', 'muna', 'billie eilish'],
    'dua lipa': ['calvin harris', 'the weeknd', 'charlie puth', 'tate mcrae', 'ariana grande', 'elton john'],

    // K-Pop / J-Pop
    'bts': ['jungkook', 'jimin', 'v', 'txt', 'stray kids', 'enhypen', 'seventeen', 'newjeans'],
    'newjeans': ['illit', 'le sserafim', 'ive', 'twice', 'blackpink', 'aespa', 'boynextdoor'],
    'blackpink': ['jennie', 'rosé', 'lisa', 'twice', 'aespa', 'newjeans', 'itzy', 'le sserafim'],
  };

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

  /// YouTube Music / Spotify Radio Algorithm:
  /// Generate context-aware seeds tightly aligned with the currently playing track
  Future<List<String>> getRadioQueriesForTrack(Track currentTrack, {int count = 6}) async {
    final cleanArtist = currentTrack.artist.split(RegExp(r'[,&]')).first.trim().toLowerCase();
    final List<String> queries = [];

    // 1. Direct Musical Neighbors (60% weight - high vibe cohesion)
    final neighbors = _artistNeighbors[cleanArtist] ?? [];
    if (neighbors.isNotEmpty) {
      final shuffled = List<String>.from(neighbors)..shuffle(_random);
      queries.addAll(shuffled.take(4));
    } else {
      // Fallback: search similar songs with title context and related style
      queries.add('${currentTrack.artist} similar music');
      queries.add('${currentTrack.artist} radio');
    }

    // 2. Blend with User Taste Seeds (20% weight - personalized familiarity)
    final userSeeds = await getTasteSeeds();
    final familiarSeeds = userSeeds.where((s) => s.toLowerCase() != cleanArtist).toList();
    if (familiarSeeds.isNotEmpty) {
      queries.add(familiarSeeds[_random.nextInt(familiarSeeds.length)]);
    }

    // 3. Ambient Genre Discovery (20% weight - keeps it fresh)
    queries.add(_discoveryPool[_random.nextInt(_discoveryPool.length)]);

    return queries.take(count).toList();
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
