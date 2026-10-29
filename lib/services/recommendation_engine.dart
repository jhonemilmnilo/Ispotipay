import 'database_service.dart';

class RecommendationEngine {
  final DatabaseService _dbService = DatabaseService();

  /// Analyze user listening profile to extract top artists and taste signals
  Future<List<String>> getTasteSeeds() async {
    final mostPlayed = await _dbService.getMostPlayed(limit: 10);
    final recents = await _dbService.getRecents(limit: 15);

    final Set<String> artistSeeds = {};

    for (final track in mostPlayed) {
      final clean = track.artist.split(RegExp(r'[,&]')).first.trim();
      if (clean.isNotEmpty && clean.length > 2) {
        artistSeeds.add(clean);
      }
    }

    for (final track in recents) {
      final clean = track.artist.split(RegExp(r'[,&]')).first.trim();
      if (clean.isNotEmpty && clean.length > 2) {
        artistSeeds.add(clean);
      }
    }

    // Default global & OPM fallback seeds if user history is brand new
    if (artistSeeds.isEmpty) {
      return [
        'Maki',
        'Billie Eilish',
        'Sabrina Carpenter',
        'Taylor Swift',
        'The Weeknd',
        'Ben&Ben',
        'Bruno Mars',
        'Olivia Rodrigo',
      ];
    }

    return artistSeeds.toList();
  }

  /// Generate personalized search query for the next music recommendation chunk
  Future<String> getRecommendedQuery(int chunkIndex) async {
    final seeds = await getTasteSeeds();
    final seed = seeds[chunkIndex % seeds.length];
    final modifiers = ['hits', 'popular songs', 'live audio', 'best tracks', 'music'];
    final mod = modifiers[(chunkIndex ~/ seeds.length) % modifiers.length];

    return '$seed $mod';
  }
}
