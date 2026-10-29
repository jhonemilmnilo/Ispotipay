import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/lyric_line.dart';
import '../models/track.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  /// Parse raw LRC content into a sorted list of LyricLine objects
  List<LyricLine> parseLrc(String lrcContent) {
    final List<LyricLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in const LineSplitter().convert(lrcContent)) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3) ?? '00';
        final millis = int.parse(millisStr.padRight(3, '0').substring(0, 3));

        final duration = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        final text = match.group(4)?.trim() ?? '';
        lines.add(LyricLine(timestamp: duration, text: text));
      }
    }

    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  /// Fetch lyrics: Checks local file first (offline support), then multi-tier LRCLIB query
  Future<List<LyricLine>> getLyrics(Track track) async {
    // 1. Check local file if track is downloaded
    if (track.lyricsPath != null && track.lyricsPath!.isNotEmpty) {
      final file = File(track.lyricsPath!);
      if (await file.exists()) {
        final content = await file.readAsString();
        return parseLrc(content);
      }
    }

    final cleanTitle = Uri.encodeComponent(
      track.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim(),
    );
    final cleanArtist = Uri.encodeComponent(
      track.artist.split(RegExp(r'[,&]')).first.trim(),
    );

    // 2. Tier 1: Try direct match without strict duration constraint
    try {
      final url = Uri.parse(
        'https://lrclib.net/api/get?track_name=$cleanTitle&artist_name=$cleanArtist',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'ispotipay-music-player (v1.0.0)',
      }).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final syncedLyrics = data['syncedLyrics'] as String?;
        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          return parseLrc(syncedLyrics);
        }
      }
    } catch (_) {}

    // 3. Tier 2: Search fallback (resolves remixes, featuring artists, and catalog discrepancies)
    try {
      final searchUrl = Uri.parse(
        'https://lrclib.net/api/search?q=$cleanTitle+$cleanArtist',
      );

      final searchResponse = await http.get(searchUrl, headers: {
        'User-Agent': 'ispotipay-music-player (v1.0.0)',
      }).timeout(const Duration(seconds: 4));

      if (searchResponse.statusCode == 200) {
        final results = json.decode(searchResponse.body) as List;
        for (final item in results) {
          final syncedLyrics = item['syncedLyrics'] as String?;
          if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
            return parseLrc(syncedLyrics);
          }
        }

        // Fallback to plain lyrics if synced isn't available
        for (final item in results) {
          final plainLyrics = item['plainLyrics'] as String?;
          if (plainLyrics != null && plainLyrics.isNotEmpty) {
            return const LineSplitter()
                .convert(plainLyrics)
                .map((line) => LyricLine(timestamp: Duration.zero, text: line))
                .toList();
          }
        }
      }
    } catch (_) {}

    return [];
  }
}
