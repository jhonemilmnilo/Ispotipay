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

  // Queue Management (Continuous Radio Loop)
  final List<Track> _queue = [];
  List<Track> get queue => List.unmodifiable(_queue);

  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  // Stream URL pre-warmed cache for instant 0-delay playback
  final Map<String, String> _urlCache = {};
  bool _isAutoReplenishing = false;

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Continuous Autoplay when song reaches end
        playNext();
      }
    });
  }

  /// Set the active Up Next queue and prefetch streams in background
  void setQueue(List<Track> newQueue) {
    _queue.clear();
    _queue.addAll(newQueue);
    _queueController.add(_queue);

    // Warm up the upcoming tracks stream URLs immediately
    _prefetchUpcomingUrls();
  }

  /// Append more tracks to the queue (endless stream)
  void appendToQueue(List<Track> moreTracks) {
    final existingIds = _queue.map((t) => t.id).toSet();
    if (_currentTrack != null) existingIds.add(_currentTrack!.id);

    for (final track in moreTracks) {
      if (!existingIds.contains(track.id)) {
        _queue.add(track);
      }
    }
    _queueController.add(_queue);
    _prefetchUpcomingUrls();
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

  /// Play a track (from local file or remote stream)
  Future<void> playTrack(Track track, {List<Track>? initialQueue}) async {
    await _player.pause();
    _isPreloading = true;
    _isPreloadingController.add(true);

    _currentTrack = track;
    _currentTrackController.add(_currentTrack);

    // Remove from upcoming queue if it's currently in queue
    _queue.removeWhere((t) => t.id == track.id);
    if (initialQueue != null) {
      setQueue(initialQueue);
    } else {
      _queueController.add(_queue);
    }

    // Record in local SQLite
    await _dbService.recordPlay(track);

    try {
      if (track.isDownloaded && track.audioPath != null) {
        await _player.setFilePath(track.audioPath!);
      } else {
        // Check cache first for instant zero-delay playback
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
      await playTrack(nextTrack);
    } else if (_currentTrack != null) {
      // Emergency queue replenishment if empty
      await _autoReplenishQueue();
      if (_queue.isNotEmpty) {
        final nextTrack = _queue.removeAt(0);
        _queueController.add(_queue);
        await playTrack(nextTrack);
      }
    }
  }

  /// Automatically fetch new tracks based on currently playing artist/vibe
  Future<void> _autoReplenishQueue() async {
    if (_isAutoReplenishing || _currentTrack == null) return;
    _isAutoReplenishing = true;

    try {
      final more = await _exploreService.getUpNextQueue(_currentTrack!, limit: 20);
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
