import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_player_service.dart';

class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayerService _playerService = AudioPlayerService();

  AudioPlayerHandler() {
    _initAudioServiceSync();
  }

  void _initAudioServiceSync() {
    // 1. Sync Track metadata to system notification & lock screen
    _playerService.currentTrackStream.listen((track) {
      if (track != null) {
        mediaItem.add(
          MediaItem(
            id: track.id,
            album: (track.album != null && track.album!.isNotEmpty)
                ? track.album!
                : 'Ispotipay',
            title: track.title,
            artist: track.artist,
            duration: track.durationMs > 0
                ? Duration(milliseconds: track.durationMs)
                : null,
            artUri:
                (track.thumbnailUrl != null && track.thumbnailUrl!.isNotEmpty)
                    ? Uri.tryParse(track.thumbnailUrl!)
                    : null,
          ),
        );
      }
    });

    // 2. Sync Player state & controls to system notification & lock screen
    _playerService.player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    _playerService.player.playerStateStream.listen((state) {
      _broadcastState();
    });
  }

  void _broadcastState() {
    final player = _playerService.player;
    final isPlaying = player.playing;
    final processingState = player.processingState;

    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: audioProcessingState,
        playing: isPlaying,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> play() => _playerService.resume();

  @override
  Future<void> pause() => _playerService.pause();

  @override
  Future<void> stop() => _playerService.pause();

  @override
  Future<void> skipToNext() => _playerService.playNext();

  @override
  Future<void> skipToPrevious() => _playerService.playPrevious();

  @override
  Future<void> seek(Duration position) => _playerService.seek(position);
}
