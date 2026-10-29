import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track.dart';
import 'database_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final DatabaseService _dbService = DatabaseService();

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

      // 1. Fetch & Download Audio Stream
      final manifest = await _yt.videos.streamsClient.getManifest(track.id);
      final streamInfo = manifest.audioOnly.withHighestBitrate();
      final audioStream = _yt.videos.streamsClient.get(streamInfo);

      final audioFile = File(audioFilePath);
      final output = audioFile.openWrite();

      final totalBytes = streamInfo.size.totalBytes;
      int downloadedBytes = 0;

      await for (final chunk in audioStream) {
        output.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(downloadedBytes / totalBytes);
        }
      }
      await output.flush();
      await output.close();

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

        final response = await http.get(url, headers: {
          'User-Agent': 'ispotipay-music-player (v1.0.0)',
        }).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final syncedLyrics = data['syncedLyrics'] as String? ?? data['plainLyrics'] as String?;
          if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
            final lyricsFile = File(lyricsFilePath);
            await lyricsFile.writeAsString(syncedLyrics);
            savedLyricsPath = lyricsFilePath;
          }
        }
      } catch (_) {
        // Continue even if lyrics fetch fails; audio file is already safe
      }

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
  }
}

