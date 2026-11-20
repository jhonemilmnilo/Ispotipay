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

  /// Fetch raw LRC content string with smart multi-tier fallback (exact -> title+artist -> title)
  Future<String?> getRawLrcString(
    Track track, {
    bool forceRefresh = false,
    int? overrideDurationMs,
  }) async {
    // 1. Check local file if track is downloaded and not forcing an online resync
    if (!forceRefresh &&
        track.lyricsPath != null &&
        track.lyricsPath!.isNotEmpty) {
      final file = File(track.lyricsPath!);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }

    final cleanTitle = Uri.encodeComponent(
      track.title.replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '').trim(),
    );
    final cleanArtist = Uri.encodeComponent(
      track.artist.split(RegExp(r'[,&]')).first.trim(),
    );
    final effectiveDurationMs =
        (overrideDurationMs != null && overrideDurationMs > 0)
        ? overrideDurationMs
        : track.durationMs;
    final durationSec = (effectiveDurationMs / 1000).round();

    // Tier 1: Exact match with duration (lrclib /api/get)
    try {
      final url = Uri.parse(
        'https://lrclib.net/api/get?track_name=$cleanTitle&artist_name=$cleanArtist&duration=$durationSec',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'ispotipay-music-player (v1.0.0)'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          await _updateLocalLyricsIfNeeded(track, synced);
          return synced;
        }
        if (!forceRefresh) {
          final plain = data['plainLyrics'] as String?;
          if (plain != null && plain.trim().isNotEmpty) {
            return plain;
          }
        }
      }
    } catch (_) {}

    // Tier 2: Search query ranked by closest duration match for accurate sync
    try {
      final searchUrl = Uri.parse(
        'https://lrclib.net/api/search?q=$cleanTitle+$cleanArtist',
      );
      final searchResponse = await http
          .get(
            searchUrl,
            headers: {'User-Agent': 'ispotipay-music-player (v1.0.0)'},
          )
          .timeout(const Duration(seconds: 4));

      if (searchResponse.statusCode == 200) {
        final results = json.decode(searchResponse.body) as List;
        String? bestSynced;
        int bestDiff = 999999;

        for (final item in results) {
          final syncedLyrics = item['syncedLyrics'] as String?;
          if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
            if (durationSec > 0 && item['duration'] != null) {
              final itemDur = (item['duration'] as num).round();
              final diff = (itemDur - durationSec).abs();
              if (diff < bestDiff) {
                bestDiff = diff;
                bestSynced = syncedLyrics;
              }
            } else {
              bestSynced ??= syncedLyrics;
            }
          }
        }

        if (bestSynced != null) {
          await _updateLocalLyricsIfNeeded(track, bestSynced);
          return bestSynced;
        }

        for (final item in results) {
          final plainLyrics = item['plainLyrics'] as String?;
          if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
            return plainLyrics;
          }
        }
      }
    } catch (_) {}

    // Tier 3: Match without duration constraint
    try {
      final url = Uri.parse(
        'https://lrclib.net/api/get?track_name=$cleanTitle&artist_name=$cleanArtist',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'ispotipay-music-player (v1.0.0)'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final synced = data['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) {
          await _updateLocalLyricsIfNeeded(track, synced);
          return synced;
        }
        final plain = data['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) {
          return plain;
        }
      }
    } catch (_) {}

    // Fallback to local file if forceRefresh failed due to offline state
    if (forceRefresh &&
        track.lyricsPath != null &&
        track.lyricsPath!.isNotEmpty) {
      final file = File(track.lyricsPath!);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }

    return null;
  }

  Future<void> _updateLocalLyricsIfNeeded(Track track, String rawLyrics) async {
    if (track.lyricsPath != null && track.lyricsPath!.isNotEmpty) {
      try {
        final file = File(track.lyricsPath!);
        await file.writeAsString(rawLyrics.trim());
      } catch (_) {}
    }
  }

  /// Fetch lyrics: Checks local file first (offline support), then multi-tier LRCLIB query
  Future<List<LyricLine>> getLyrics(
    Track track, {
    bool forceRefresh = false,
    int? overrideDurationMs,
  }) async {
    final rawLrc = await getRawLrcString(
      track,
      forceRefresh: forceRefresh,
      overrideDurationMs: overrideDurationMs,
    );
    if (rawLrc != null && rawLrc.trim().isNotEmpty) {
      final parsed = parseLrc(rawLrc);
      if (parsed.isNotEmpty) return parsed;

      // If it has plain text without LRC timestamps, convert line-by-line
      return const LineSplitter()
          .convert(rawLrc)
          .map((line) => LyricLine(timestamp: Duration.zero, text: line))
          .toList();
    }
    return [];
  }
}
