import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import 'database_service.dart';
import 'music_explore_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final DatabaseService _dbService = DatabaseService();
  final MusicExploreService _exploreService = MusicExploreService();

  /// Download both the audio stream (.m4a) and the companion synchronized lyrics (.lrc)
  Future<Track?> downloadTrack(
    Track track, {
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

      // 1. Resolve exact audio stream via MusicExploreService
      final streamUrl = await _exploreService.getAudioStreamUrl(
        track.id,
        title: track.title,
        artist: track.artist,
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

      // 2. Fetch & Save Companion LRC Lyrics
      String? savedLyricsPath;
      try {
        final cleanTitle = Uri.encodeComponent(
          track.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim(),
        );
        final cleanArtist = Uri.encodeComponent(track.artist.trim());
        final durationSeconds = (track.durationMs / 1000).round();

        final url = Uri.parse(
          'https://lrclib.net/api/get?track_name=$cleanTitle&artist_name=$cleanArtist&duration=$durationSeconds',
        );

        final lyricRes = await http.get(url, headers: {
          'User-Agent': 'ispotipay-music-player (v1.0.0)',
        }).timeout(const Duration(seconds: 4));

        if (lyricRes.statusCode == 200) {
          final data = json.decode(lyricRes.body) as Map<String, dynamic>;
          final syncedLyrics = data['syncedLyrics'] as String? ?? data['plainLyrics'] as String?;
          if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
            final lyricsFile = File(lyricsFilePath);
            await lyricsFile.writeAsString(syncedLyrics);
            savedLyricsPath = lyricsFilePath;
          }
        }
      } catch (_) {}

      // 3. Update SQLite track entry with local file paths
      final updatedTrack = track.copyWith(
        audioPath: audioFilePath,
        lyricsPath: savedLyricsPath,
      );
      await _dbService.saveTrack(updatedTrack);

      return updatedTrack;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _yt.close();
    _exploreService.dispose();
  }
}
