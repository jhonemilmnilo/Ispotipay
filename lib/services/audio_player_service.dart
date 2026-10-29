import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'database_service.dart';
import 'music_explore_service.dart';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;
  AudioPlayerService._internal() {
    _initListeners();
  }

  final AudioPlayer _player = AudioPlayer();
  final DatabaseService _dbService = DatabaseService();
  final MusicExploreService _exploreService = MusicExploreService();

  Track? _currentTrack;
  Track? get currentTrack => _currentTrack;

  AudioPlayer get player => _player;

  final _currentTrackController = StreamController<Track?>.broadcast();
  Stream<Track?> get currentTrackStream => _currentTrackController.stream;

  final _isPreloadingController = StreamController<bool>.broadcast();
  Stream<bool> get isPreloadingStream => _isPreloadingController.stream;
  bool _isPreloading = false;
  bool get isPreloading => _isPreloading;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // Queue Management (Strict Sequential Queue & Endless Radio)
  final List<Track> _queue = [];
  List<Track> get queue => List.unmodifiable(_queue);

  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  // Session-wide played tracks tracking to ensure NO repetition during listening session
  final Set<String> _sessionPlayedTrackIds = {};
  final Set<String> _sessionPlayedTitles = {};

  // Contextual Vibe memory: tracks history in current session to seed future radio chunks
  final List<Track> _recentVibeSeeds = [];

  // Stream URL pre-warmed cache for instant 0-delay playback
  final Map<String, String> _urlCache = {};
  bool _isAutoReplenishing = false;

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Continuous Non-Stop Autoplay
        playNext();
      }
    });
  }

  /// Set the active Up Next queue and prefetch streams in background
  void setQueue(List<Track> newQueue) {
    _queue.clear();
    // Exclude anything that has already been played in this session
    for (final t in newQueue) {
      if (!_sessionPlayedTrackIds.contains(t.id) &&
          !_sessionPlayedTitles.contains(t.title.toLowerCase().trim())) {
        _queue.add(t);
      }
    }
    _queueController.add(_queue);
    _prefetchUpcomingUrls();
  }

  /// Append more tracks to the queue (endless stream)
  void appendToQueue(List<Track> moreTracks) {
    final existingIds = _queue.map((t) => t.id).toSet();
    if (_currentTrack != null) existingIds.add(_currentTrack!.id);

    for (final track in moreTracks) {
      final cleanTitle = track.title.toLowerCase().trim();
      if (!existingIds.contains(track.id) &&
          !_sessionPlayedTrackIds.contains(track.id) &&
          !_sessionPlayedTitles.contains(cleanTitle)) {
        _queue.add(track);
      }
    }
    _queueController.add(_queue);
    _prefetchUpcomingUrls();
  }

  /// User taps a specific track in the Up Next list:
  /// Play that track and slice the queue so all songs below it become the upcoming queue in order!
  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;

    final selectedTrack = _queue[index];

    // The upcoming queue becomes strictly everything after the selected item
    final remainingQueue = _queue.sublist(index + 1);
    _queue.clear();
    _queue.addAll(remainingQueue);
    _queueController.add(_queue);

    await _executePlay(selectedTrack);
  }

  /// Play a track directly
  Future<void> playTrack(Track track, {List<Track>? initialQueue}) async {
    if (initialQueue != null) {
      setQueue(initialQueue);
    } else {
      _queue.removeWhere((t) => t.id == track.id);
      _queueController.add(_queue);
    }

    await _executePlay(track);
  }

  Future<void> _executePlay(Track track) async {
    await _player.pause();
    _isPreloading = true;
    _isPreloadingController.add(true);

    _currentTrack = track;
    _currentTrackController.add(_currentTrack);

    // Record in session played history
    _sessionPlayedTrackIds.add(track.id);
    _sessionPlayedTitles.add(track.title.toLowerCase().trim());

    // Record in Vibe memory (keep last 5 tracks as radio context)
    _recentVibeSeeds.add(track);
    if (_recentVibeSeeds.length > 5) {
      _recentVibeSeeds.removeAt(0);
    }

    // Record in local SQLite
    await _dbService.recordPlay(track);

    try {
      if (track.isDownloaded && track.audioPath != null) {
        await _player.setFilePath(track.audioPath!);
      } else {
        // Check pre-warmed cache first for instant zero-delay playback
        String? streamUrl = _urlCache[track.id];
        streamUrl ??= await _exploreService.getAudioStreamUrl(
          track.id,
          title: track.title,
          artist: track.artist,
          targetDurationMs: track.durationMs,
        );

        if (streamUrl != null) {
          _urlCache[track.id] = streamUrl;
          await _player.setUrl(streamUrl);
        } else {
          throw Exception('Could not resolve audio stream URL');
        }
      }

      _isPreloading = false;
      _isPreloadingController.add(false);
      await _player.play();

      // Trigger pre-warm for subsequent tracks
      _prefetchUpcomingUrls();

      // If queue is running low (<= 3), auto-replenish from radio in background
      if (_queue.length <= 3) {
        _autoReplenishQueue();
      }
    } catch (e) {
      _isPreloading = false;
      _isPreloadingController.add(false);
      debugPrint('[AudioPlayerService] Playback error: $e');
    }
  }

  /// Play the next song in the queue (Continuous Autoplay)
  Future<void> playNext() async {
    if (_queue.isNotEmpty) {
      final nextTrack = _queue.removeAt(0);
      _queueController.add(_queue);
      await _executePlay(nextTrack);
    } else if (_currentTrack != null) {
      // Emergency queue replenishment if empty
      await _autoReplenishQueue();
      if (_queue.isNotEmpty) {
        final nextTrack = _queue.removeAt(0);
        _queueController.add(_queue);
        await _executePlay(nextTrack);
      }
    }
  }

  /// Preload stream URLs for the top 3 items in the queue so next songs start instantly
  void _prefetchUpcomingUrls() {
    final toWarm = _queue.take(3);
    for (final track in toWarm) {
      if (!_urlCache.containsKey(track.id) && !track.isDownloaded) {
        _exploreService
            .getAudioStreamUrl(
              track.id,
              title: track.title,
              artist: track.artist,
              targetDurationMs: track.durationMs,
            )
            .then((url) {
              if (url != null) {
                _urlCache[track.id] = url;
              }
            })
            .catchError((_) {});
      }
    }
  }

  /// Automatically fetch new tracks based on currently playing and previous vibe context
  Future<void> _autoReplenishQueue() async {
    if (_isAutoReplenishing || _currentTrack == null) return;
    _isAutoReplenishing = true;

    try {
      // Use recent vibe context (up to 3 recent tracks) to anchor the next radio wave
      final anchorTrack = _recentVibeSeeds.isNotEmpty
          ? _recentVibeSeeds[_recentVibeSeeds.length ~/ 2]
          : _currentTrack!;

      final more = await _exploreService.getUpNextQueue(anchorTrack, limit: 25);
      appendToQueue(more);
    } catch (_) {}

    _isAutoReplenishing = false;
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void dispose() {
    _currentTrackController.close();
    _isPreloadingController.close();
    _queueController.close();
    _player.dispose();
  }
}
