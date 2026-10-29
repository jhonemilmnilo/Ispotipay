import 'package:flutter_test/flutter_test.dart';
import 'package:ispotipay/models/track.dart';
import 'package:ispotipay/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService dbService;

  setUp(() async {
    dbService = DatabaseService();
    await dbService.init(customPath: inMemoryDatabasePath);
  });

  tearDown(() async {
    await dbService.close();
  });

  test('DatabaseService records plays, caps recents at 15, and tracks most played', () async {
    // 1. Record plays for 20 unique tracks
    for (int i = 1; i <= 20; i++) {
      final track = Track(
        id: 'track_$i',
        title: 'Song $i',
        artist: 'Artist $i',
        durationMs: 180000,
      );
      await dbService.recordPlay(track);
    }

    // Recents should be strictly capped at 15
    final recents = await dbService.getRecents();
    expect(recents.length, 15);
    // Most recent is track_20
    expect(recents.first.id, 'track_20');

    // 2. Play track_1 five times
    final track1 = Track(
      id: 'track_1',
      title: 'Song 1',
      artist: 'Artist 1',
      durationMs: 180000,
    );
    for (int i = 0; i < 5; i++) {
      await dbService.recordPlay(track1);
    }

    final mostPlayed = await dbService.getMostPlayed(limit: 10);
    expect(mostPlayed.length, lessThanOrEqualTo(10));
    expect(mostPlayed.first.id, 'track_1');
    expect(mostPlayed.first.playCount, 6); // 1 initial + 5 additional
  });

  test('DatabaseService toggles favorites correctly', () async {
    final track = Track(
      id: 'fav_1',
      title: 'Favorite Song',
      artist: 'Top Artist',
      durationMs: 200000,
    );

    expect(await dbService.isFavorite(track.id), false);

    // Favorite it
    final added = await dbService.toggleFavorite(track);
    expect(added, true);
    expect(await dbService.isFavorite(track.id), true);

    final favs = await dbService.getFavorites();
    expect(favs.length, 1);
    expect(favs.first.id, 'fav_1');

    // Un-favorite it
    final removed = await dbService.toggleFavorite(track);
    expect(removed, false);
    expect(await dbService.isFavorite(track.id), false);
  });
}
