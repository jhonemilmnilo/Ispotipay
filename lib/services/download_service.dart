import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import 'database_service.dart';
import 'lyrics_service.dart';
import 'music_explore_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final DatabaseService _dbService = DatabaseService();
  final MusicExploreService _exploreService = MusicExploreService();
  final LyricsService _lyricsService = LyricsService();

  /// Download both the audio stream (.m4a) and the companion synchronized lyrics (.lrc)
  Future<Track?> downloadTrack(
    Track track, {
    String? albumId,
    Function(double progress)? onProgress,
  }) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final tracksDir = Directory(p.join(appDocDir.path, 'tracks'));
      final lyricsDir = Directory(p.join(appDocDir.path, 'lyrics'));

      if (!await tracksDir.exists()) await tracksDir.create(recursive: true);
      if (!await lyricsDir.exists()) await lyricsDir.create(recursive: true);

      final safeId = track.id.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final audioFilePath = p.join(tracksDir.path, '$safeId.m4a');
      final lyricsFilePath = p.join(lyricsDir.path, '$safeId.lrc');

      // 1. Resolve exact audio stream via MusicExploreService with studio duration matching
      final streamUrl = await _exploreService.getAudioStreamUrl(
        track.id,
        title: track.title,
        artist: track.artist,
        targetDurationMs: track.durationMs,
      );

      if (streamUrl == null) return null;

      final audioFile = File(audioFilePath);
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(streamUrl));
      final response = await client.send(request);

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;
      final sink = audioFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await sink.flush();
      await sink.close();
      client.close();

      // 2. Fetch & Save Companion LRC Lyrics using smart multi-tier lookup
      String? savedLyricsPath;
      try {
        final rawLyrics = await _lyricsService.getRawLrcString(track);
        if (rawLyrics != null && rawLyrics.trim().isNotEmpty) {
          final lyricsFile = File(lyricsFilePath);
          await lyricsFile.writeAsString(rawLyrics.trim());
          savedLyricsPath = lyricsFilePath;
        }
      } catch (_) {}

      // 3. Update SQLite track entry with local file paths
      final updatedTrack = track.copyWith(
        audioPath: audioFilePath,
        lyricsPath: savedLyricsPath,
      );
      await _dbService.saveTrack(updatedTrack);

      if (albumId != null && albumId.isNotEmpty && albumId != 'general') {
        await _dbService.addTrackToDownloadAlbum(albumId, track.id);
      }
      _dbService.notifyLibraryChanged();

      return updatedTrack;
    } catch (_) {
      return null;
    }
  }

  /// Delete a downloaded track: removes .m4a and .lrc files from disk and clears SQLite paths
  Future<bool> deleteDownloadedTrack(Track track) async {
    try {
      if (track.audioPath != null && track.audioPath!.isNotEmpty) {
        final audioFile = File(track.audioPath!);
        if (await audioFile.exists()) {
          await audioFile.delete();
        }
      }

      if (track.lyricsPath != null && track.lyricsPath!.isNotEmpty) {
        final lyricsFile = File(track.lyricsPath!);
        if (await lyricsFile.exists()) {
          await lyricsFile.delete();
        }
      }

      // Clear local file paths in SQLite
      final clearedTrack = Track(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        durationMs: track.durationMs,
        thumbnailUrl: track.thumbnailUrl,
        audioPath: null,
        lyricsPath: null,
        playCount: track.playCount,
        lastPlayedAt: track.lastPlayedAt,
      );

      await _dbService.saveTrack(clearedTrack);
      _dbService.notifyLibraryChanged();
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _yt.close();
    _exploreService.dispose();
  }
}
