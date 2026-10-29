import 'dart:async';
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
    _currentTrack = track;
    _currentTrackController.add(_currentTrack);

    // Record in local SQLite
    await _dbService.recordPlay(track);

    try {
      if (track.isDownloaded) {
        // Play local offline file
        await _player.setFilePath(track.audioPath!);
      } else {
        // Resolve online stream URL via youtube_explode
        final streamUrl = await _exploreService.getAudioStreamUrl(track.id);
        if (streamUrl != null) {
          await _player.setUrl(streamUrl);
        } else {
          throw Exception('Could not resolve audio stream URL');
        }
      }
      await _player.play();
    } catch (_) {
      // Gracefully handle playback failures
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
    _player.dispose();
  }
}
