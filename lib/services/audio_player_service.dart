import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track.dart';
import 'database_service.dart';
import 'music_explore_service.dart';

enum LoopModeType {
  off,
  repeatOne,
  repeatAll,
  playOnce,
}

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

  // Loop & Shuffle State
  LoopModeType _loopMode = LoopModeType.off;
  LoopModeType get loopMode => _loopMode;
  final _loopModeController = StreamController<LoopModeType>.broadcast();
  Stream<LoopModeType> get loopModeStream => _loopModeController.stream;

  bool _isShuffle = false;
  bool get isShuffle => _isShuffle;
  final _isShuffleController = StreamController<bool>.broadcast();
  Stream<bool> get isShuffleStream => _isShuffleController.stream;

  // Queue Management (Strict Sequential Queue & Endless Radio)
  final List<Track> _queue = [];
  List<Track> get queue => List.unmodifiable(_queue);

  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  // Session-wide played tracks tracking to ensure NO repetition during listening session
  final Set<String> _sessionPlayedTrackIds = {};
  final Set<String> _sessionPlayedTitles = {};

  // Stack of previously played tracks for the Previous button & History
  final List<Track> _playbackHistory = [];
  List<Track> get playbackHistory => List.unmodifiable(_playbackHistory);

  final _historyController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get historyStream => _historyController.stream;

  // Contextual Vibe memory: tracks history in current session to seed future radio chunks
  final List<Track> _recentVibeSeeds = [];

  // Stream URL pre-warmed cache for instant 0-delay playback
  final Map<String, String> _urlCache = {};
  bool _isAutoReplenishing = false;

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
      }
    });
  }

  Future<void> _handleTrackCompleted() async {
    switch (_loopMode) {
      case LoopModeType.repeatOne:
        await seek(Duration.zero);
        await play();
        break;
      case LoopModeType.playOnce:
        await pause();
        await seek(Duration.zero);
        break;
      case LoopModeType.repeatAll:
        if (_queue.isNotEmpty) {
          await playNext();
        } else if (_playbackHistory.isNotEmpty) {
          // Wrap all history back into queue and play first
          final loopedQueue = List<Track>.from(_playbackHistory);
          if (_currentTrack != null) loopedQueue.add(_currentTrack!);
          _playbackHistory.clear();
          _historyController.add(_playbackHistory);
          setQueue(loopedQueue);
          await playNext();
        } else if (_currentTrack != null) {
          await seek(Duration.zero);
          await play();
        }
        break;
      case LoopModeType.off:
        // Continuous Non-Stop Autoplay
        await playNext();
        break;
    }
  }

  /// Toggle shuffle on / off. When activated, shuffles the upcoming Up Next tracks!
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _isShuffleController.add(_isShuffle);

    if (_isShuffle && _queue.isNotEmpty) {
      _queue.shuffle();
      _queueController.add(_queue);
      _prefetchUpcomingUrls();
    }
  }

  /// Cycle through Repeat modes: off -> repeatOne -> repeatAll -> playOnce -> off
  void cycleLoopMode() {
    switch (_loopMode) {
      case LoopModeType.off:
        _loopMode = LoopModeType.repeatOne;
        break;
      case LoopModeType.repeatOne:
        _loopMode = LoopModeType.repeatAll;
        break;
      case LoopModeType.repeatAll:
        _loopMode = LoopModeType.playOnce;
        break;
      case LoopModeType.playOnce:
        _loopMode = LoopModeType.off;
        break;
    }
    _loopModeController.add(_loopMode);
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
    if (_isShuffle) {
      _queue.shuffle();
    }
    _queueController.add(_queue);
    _prefetchUpcomingUrls();
  }

  /// Append more tracks to the queue (endless stream)
  void appendToQueue(List<Track> moreTracks) {
    final existingIds = _queue.map((t) => t.id).toSet();
    if (_currentTrack != null) existingIds.add(_currentTrack!.id);

    final incoming = <Track>[];
    for (final track in moreTracks) {
      final cleanTitle = track.title.toLowerCase().trim();
      if (!existingIds.contains(track.id) &&
          !_sessionPlayedTrackIds.contains(track.id) &&
          !_sessionPlayedTitles.contains(cleanTitle)) {
        incoming.add(track);
      }
    }
    if (_isShuffle) {
      incoming.shuffle();
    }
    _queue.addAll(incoming);
    _queueController.add(_queue);
    _prefetchUpcomingUrls();
  }

  /// User taps a specific track in the Previous/History list:
  /// Rewind queue so this track plays, and all subsequent history + current becomes upcoming!
  Future<void> playFromHistory(int historyIndex) async {
    if (historyIndex < 0 || historyIndex >= _playbackHistory.length) return;

    final selectedTrack = _playbackHistory[historyIndex];

    // Everything after this history index moves back to the upcoming queue
    final subsequentHistory = _playbackHistory.sublist(historyIndex + 1);
    _playbackHistory.removeRange(historyIndex, _playbackHistory.length);
    _historyController.add(_playbackHistory);

    final newQueue = <Track>[];
    newQueue.addAll(subsequentHistory);
    if (_currentTrack != null) {
      newQueue.add(_currentTrack!);
    }
    newQueue.addAll(_queue);

    _queue.clear();
    _queue.addAll(newQueue);
    _queueController.add(_queue);

    await _executePlay(selectedTrack, addToHistory: false);
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

  /// Reorder items in the upcoming queue via drag and drop
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > _queue.length) newIndex = _queue.length;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, item);
    _queueController.add(_queue);

    // Warm up newly rearranged top upcoming tracks immediately
    _prefetchUpcomingUrls();
  }

  /// Reorder active timeline without interrupting current playback!
  /// The currently playing track keeps playing without stopping.
  /// Songs placed ABOVE it become prior tracks, and songs placed BELOW it become the upcoming queue.
  void reorderActiveTimeline(int oldIndex, int newIndex) {
    if (_currentTrack == null) return;

    final activeList = <Track>[];
    activeList.add(_currentTrack!);
    activeList.addAll(_queue);

    if (oldIndex < 0 || oldIndex >= activeList.length) return;
    if (newIndex < 0) newIndex = 0;
    if (newIndex > activeList.length) newIndex = activeList.length;

    final movedTrack = activeList.removeAt(oldIndex);
    activeList.insert(newIndex, movedTrack);

    // Locate where _currentTrack is now positioned
    final currentPos = activeList.indexWhere((t) => t.id == _currentTrack!.id);

    if (currentPos != -1) {
      // Everything before currentPos becomes part of playback history
      final priorTracks = activeList.sublist(0, currentPos);
      if (priorTracks.isNotEmpty) {
        _playbackHistory.addAll(priorTracks);
        _historyController.add(_playbackHistory);
      }

      // Everything after currentPos becomes the new upcoming queue
      final subsequentTracks = activeList.sublist(currentPos + 1);
      _queue.clear();
      _queue.addAll(subsequentTracks);
      _queueController.add(_queue);

      // Pre-warm the new top tracks in the queue
      _prefetchUpcomingUrls();
    }
  }

  /// Play a track directly
  Future<void> playTrack(
    Track track, {
    List<Track>? initialQueue,
    bool resetQueue = false,
  }) async {
    if (resetQueue) {
      _queue.clear();
      _playbackHistory.clear();
      _historyController.add(_playbackHistory);
      _queueController.add(_queue);
      _recentVibeSeeds.clear();
    }

    if (initialQueue != null) {
      setQueue(initialQueue);
    } else if (!resetQueue) {
      _queue.removeWhere((t) => t.id == track.id);
      _queueController.add(_queue);
    }

    await _executePlay(track, addToHistory: true);
  }

  Future<void> _executePlay(Track track, {bool addToHistory = true}) async {
    if (addToHistory && _currentTrack != null && _currentTrack!.id != track.id) {
      _playbackHistory.add(_currentTrack!);
      _historyController.add(_playbackHistory);
    }

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

  /// Play the next song in the queue (Strictly the next item in Up Next)
  Future<void> playNext() async {
    if (_queue.isNotEmpty) {
      final nextTrack = _queue.removeAt(0);
      _queueController.add(_queue);
      await _executePlay(nextTrack, addToHistory: true);
    } else if (_currentTrack != null) {
      // Emergency queue replenishment if empty
      await _autoReplenishQueue();
      if (_queue.isNotEmpty) {
        final nextTrack = _queue.removeAt(0);
        _queueController.add(_queue);
        await _executePlay(nextTrack, addToHistory: true);
      }
    }
  }

  /// Play the previous song or rewind to 00:00
  Future<void> playPrevious() async {
    // If song has played for more than 3 seconds, standard music player behavior is to restart it
    if (_player.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    if (_playbackHistory.isNotEmpty) {
      final prevTrack = _playbackHistory.removeLast();
      _historyController.add(_playbackHistory);

      // Put current track back to front of upcoming queue so user doesn't lose their place
      if (_currentTrack != null) {
        _queue.insert(0, _currentTrack!);
        _queueController.add(_queue);
      }

      await _executePlay(prevTrack, addToHistory: false);
    } else {
      // Fallback: just restart current track
      await seek(Duration.zero);
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

  Future<void> play() async {
    await _player.play();
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
    _loopModeController.close();
    _isShuffleController.close();
    _queueController.close();
    _historyController.close();
    _player.dispose();
  }
}
