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

  void _initListeners() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Can auto-play next track in future
      }
    });
  }

  /// Play a track (from local file or remote stream)
  Future<void> playTrack(Track track) async {
    // 1. Instantly pause/stop previous audio and reset progress
    await _player.pause();
    _isPreloading = true;
    _isPreloadingController.add(true);

    _currentTrack = track;
    _currentTrackController.add(_currentTrack);

    // Record in local SQLite
    await _dbService.recordPlay(track);

    try {
      if (track.isDownloaded) {
        // Play local offline file
        await _player.setFilePath(track.audioPath!);
      } else {
        // 2. Resolve online stream URL via exact title, artist, and studio duration
        final streamUrl = await _exploreService.getAudioStreamUrl(
          track.id,
          title: track.title,
          artist: track.artist,
          targetDurationMs: track.durationMs,
        );
        if (streamUrl != null) {
          // Play progressive stream directly
          await _player.setUrl(streamUrl);
        } else {
          throw Exception('Could not resolve audio stream URL');
        }
      }
      _isPreloading = false;
      _isPreloadingController.add(false);
      await _player.play();
    } catch (e) {
      _isPreloading = false;
      _isPreloadingController.add(false);
      debugPrint('[AudioPlayerService] Playback error: $e');
    }
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
    _player.dispose();
  }
}

