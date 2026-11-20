import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/download_album.dart';
import '../models/track.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  /// Broadcast stream to notify UI listeners whenever library data (favorites, downloads, plays) changes
  final StreamController<void> _libraryUpdateController = StreamController<void>.broadcast();
  Stream<void> get libraryUpdatesStream => _libraryUpdateController.stream;

  void notifyLibraryChanged() {
    if (!_libraryUpdateController.isClosed) {
      _libraryUpdateController.add(null);
    }
  }

  Future<Database> init({String? customPath}) async {
    if (_database != null) return _database!;
    _database = await _initDatabase(customPath: customPath);
    return _database!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase({String? customPath}) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, 'ispotipay.db');
    }

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Tracks master table (caches metadata + play count)
        await db.execute('''
          CREATE TABLE tracks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            duration_ms INTEGER NOT NULL,
            thumbnail_url TEXT,
            audio_path TEXT,
            lyrics_path TEXT,
            play_count INTEGER DEFAULT 0,
            last_played_at INTEGER
          )
        ''');

        // Favorites table
        await db.execute('''
          CREATE TABLE favorites (
            track_id TEXT PRIMARY KEY,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
          )
        ''');

        // Recents table
        await db.execute('''
          CREATE TABLE recents (
            track_id TEXT PRIMARY KEY,
            played_at INTEGER NOT NULL,
            FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
          )
        ''');

        // Download albums table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS download_albums (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Download album tracks join table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS download_album_tracks (
            album_id TEXT NOT NULL,
            track_id TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            PRIMARY KEY (album_id, track_id),
            FOREIGN KEY (album_id) REFERENCES download_albums (id) ON DELETE CASCADE,
            FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
          )
        ''');
      },
      onOpen: (db) async {
        // Ensure download album tables exist on legacy database versions
        await db.execute('''
          CREATE TABLE IF NOT EXISTS download_albums (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS download_album_tracks (
            album_id TEXT NOT NULL,
            track_id TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            PRIMARY KEY (album_id, track_id),
            FOREIGN KEY (album_id) REFERENCES download_albums (id) ON DELETE CASCADE,
            FOREIGN KEY (track_id) REFERENCES tracks (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  /// Upsert track metadata
  Future<void> saveTrack(Track track) async {
    final db = await database;
    await db.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyLibraryChanged();
  }

  /// Record a play event (increments play_count and adds to recents, capped at 15)
  Future<void> recordPlay(Track track) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      // 1. Ensure track exists & increment play_count
      final existing = await txn.query('tracks', where: 'id = ?', whereArgs: [track.id]);
      if (existing.isEmpty) {
        final newTrack = track.copyWith(playCount: 1, lastPlayedAt: now);
        await txn.insert('tracks', newTrack.toMap());
      } else {
        final currentPlayCount = (existing.first['play_count'] as num?)?.toInt() ?? 0;
        await txn.update(
          'tracks',
          {
            'play_count': currentPlayCount + 1,
            'last_played_at': now,
            'title': track.title,
            'artist': track.artist,
            if (track.thumbnailUrl != null) 'thumbnail_url': track.thumbnailUrl,
          },
          where: 'id = ?',
          whereArgs: [track.id],
        );
      }

      // 2. Insert into recents
      await txn.insert(
        'recents',
        {'track_id': track.id, 'played_at': now},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Trim recents to max 15 items
      await txn.rawDelete('''
        DELETE FROM recents
        WHERE track_id NOT IN (
          SELECT track_id FROM recents
          ORDER BY played_at DESC
          LIMIT 15
        )
      ''');
    });
    notifyLibraryChanged();
  }

  /// Get Recent Tracks (Max 15)
  Future<List<Track>> getRecents({int limit = 15}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN recents r ON t.id = r.track_id
      ORDER BY r.played_at DESC
      LIMIT ?
    ''', [limit]);

    return results.map(Track.fromMap).toList();
  }

  /// Get Most Played Tracks (Max 10)
  Future<List<Track>> getMostPlayed({int limit = 10}) async {
    final db = await database;
    final results = await db.query(
      'tracks',
      where: 'play_count > 0',
      orderBy: 'play_count DESC',
      limit: limit,
    );
    return results.map(Track.fromMap).toList();
  }

  /// Get track by ID from SQLite (checks local audio_path and lyrics_path)
  Future<Track?> getTrackById(String trackId) async {
    final db = await database;
    final results = await db.query(
      'tracks',
      where: 'id = ?',
      whereArgs: [trackId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Track.fromMap(results.first);
    }
    return null;
  }

  /// Toggle Favorite
  Future<bool> toggleFavorite(Track track) async {
    final db = await database;
    await saveTrack(track);

    final exists = await db.query('favorites', where: 'track_id = ?', whereArgs: [track.id]);
    final bool isFav;
    if (exists.isNotEmpty) {
      await db.delete('favorites', where: 'track_id = ?', whereArgs: [track.id]);
      isFav = false; // un-favorited
    } else {
      await db.insert('favorites', {
        'track_id': track.id,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      isFav = true; // favorited
    }

    notifyLibraryChanged();
    return isFav;
  }

  /// Check if track is favorited
  Future<bool> isFavorite(String trackId) async {
    final db = await database;
    final res = await db.query('favorites', where: 'track_id = ?', whereArgs: [trackId]);
    return res.isNotEmpty;
  }

  /// Get Favorites paginated (chunk of 25)
  Future<List<Track>> getFavorites({int limit = 25, int offset = 0}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN favorites f ON t.id = f.track_id
      ORDER BY f.created_at DESC
      LIMIT ? OFFSET ?
    ''', [limit, offset]);

    return results.map(Track.fromMap).toList();
  }

  /// Get all downloaded tracks paginated
  Future<List<Track>> getDownloadedTracks({int limit = 25, int offset = 0}) async {
    final db = await database;
    final results = await db.query(
      'tracks',
      where: 'audio_path IS NOT NULL AND audio_path != ""',
      orderBy: 'title ASC',
      limit: limit,
      offset: offset,
    );
    return results.map(Track.fromMap).toList();
  }

  /// Create a new Download Album
  Future<DownloadAlbum> createDownloadAlbum(String name) async {
    final db = await database;
    final id = 'album_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'download_albums',
      {
        'id': id,
        'name': name.trim(),
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyLibraryChanged();
    return DownloadAlbum(
      id: id,
      name: name.trim(),
      createdAt: now,
      trackCount: 0,
    );
  }

  /// Fetch all created download albums with their song count and cover art
  Future<List<DownloadAlbum>> getDownloadAlbums() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT a.id, a.name, a.created_at, 
             COUNT(dat.track_id) AS track_count,
             (
               SELECT t.thumbnail_url 
               FROM tracks t 
               INNER JOIN download_album_tracks dat2 ON t.id = dat2.track_id 
               WHERE dat2.album_id = a.id AND t.thumbnail_url IS NOT NULL AND t.thumbnail_url != ""
               ORDER BY dat2.added_at DESC
               LIMIT 1
             ) AS cover_url
      FROM download_albums a
      LEFT JOIN download_album_tracks dat ON a.id = dat.album_id
      GROUP BY a.id
      ORDER BY a.created_at DESC
    ''');
    return results.map(DownloadAlbum.fromMap).toList();
  }

  /// Get a single album by ID
  Future<DownloadAlbum?> getDownloadAlbumById(String albumId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT a.id, a.name, a.created_at, 
             COUNT(dat.track_id) AS track_count,
             (
               SELECT t.thumbnail_url 
               FROM tracks t 
               INNER JOIN download_album_tracks dat2 ON t.id = dat2.track_id 
               WHERE dat2.album_id = a.id AND t.thumbnail_url IS NOT NULL AND t.thumbnail_url != ""
               LIMIT 1
             ) AS cover_url
      FROM download_albums a
      LEFT JOIN download_album_tracks dat ON a.id = dat.album_id
      WHERE a.id = ?
      GROUP BY a.id
      LIMIT 1
    ''', [albumId]);
    if (results.isNotEmpty) {
      return DownloadAlbum.fromMap(results.first);
    }
    return null;
  }

  /// Add a downloaded track to a specific album
  Future<void> addTrackToDownloadAlbum(String albumId, String trackId) async {
    final db = await database;
    await db.insert(
      'download_album_tracks',
      {
        'album_id': albumId,
        'track_id': trackId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyLibraryChanged();
  }

  /// Remove a track from an album
  Future<void> removeTrackFromDownloadAlbum(String albumId, String trackId) async {
    final db = await database;
    await db.delete(
      'download_album_tracks',
      where: 'album_id = ? AND track_id = ?',
      whereArgs: [albumId, trackId],
    );
    notifyLibraryChanged();
  }

  /// Delete an album (does NOT delete the downloaded audio file itself)
  Future<void> deleteDownloadAlbum(String albumId) async {
    final db = await database;
    await db.delete('download_album_tracks', where: 'album_id = ?', whereArgs: [albumId]);
    await db.delete('download_albums', where: 'id = ?', whereArgs: [albumId]);
    notifyLibraryChanged();
  }

  /// Get all tracks inside a specific download album
  Future<List<Track>> getTracksForAlbum(String albumId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT t.* FROM tracks t
      INNER JOIN download_album_tracks dat ON t.id = dat.track_id
      WHERE dat.album_id = ? AND t.audio_path IS NOT NULL AND t.audio_path != ""
      ORDER BY dat.added_at DESC
    ''', [albumId]);
    return results.map(Track.fromMap).toList();
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
