import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/lyrics_service.dart';
import 'app_theme.dart';

class PlayerScreen extends StatefulWidget {
  final Track track;

  const PlayerScreen({super.key, required this.track});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _lyricsScrollController = ScrollController();

  List<LyricLine> _lyrics = [];
  bool _isLoadingLyrics = true;

  @override
  void initState() {
    super.initState();
    _loadLyrics();
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics() async {
    final lyrics = await _lyricsService.getLyrics(widget.track);
    if (mounted) {
      setState(() {
        _lyrics = lyrics;
        _isLoadingLyrics = false;
      });
    }
  }

  int _findActiveLineIndex(Duration currentPosition) {
    if (_lyrics.isEmpty) return 0;
    int index = 0;
    for (int i = 0; i < _lyrics.length; i++) {
      if (currentPosition >= _lyrics[i].timestamp) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.textPrimary, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Now Playing',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Track Info & Artwork
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.track.thumbnailUrl != null
                        ? Image.network(
                            widget.track.thumbnailUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackArt(),
                          )
                        : _fallbackArt(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppTheme.divider, height: 24),

            // Middle Section: Strict Center-Locked Sliding Teleprompter Lyrics
            Expanded(
              child: _isLoadingLyrics
                  ? const Center(
                      child: CircularProgressIndicator(color: AppTheme.accentLime),
                    )
                  : _lyrics.isEmpty
                      ? const Center(
                          child: Text(
                            'No lyrics found for this song',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final halfHeight = constraints.maxHeight / 2;
                            const slotHeight = 64.0;

                            return ShaderMask(
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black,
                                    Colors.black,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.35, 0.65, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.dstIn,
                              child: StreamBuilder<Duration>(
                                stream: _audioService.positionStream,
                                builder: (context, snapshot) {
                                  final currentPosition = snapshot.data ?? Duration.zero;
                                  final activeIndex = _findActiveLineIndex(currentPosition);

                                  // Exactly anchor the sliding container so activeIndex is strictly centered
                                  final targetOffset = (activeIndex * slotHeight);

                                  return Stack(
                                    children: [
                                      // Soft center slot indicator line/glow
                                      Positioned(
                                        top: halfHeight - (slotHeight / 2),
                                        left: 40,
                                        right: 40,
                                        height: slotHeight,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: AppTheme.accentLime.withValues(alpha: 0.15),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // The sliding lyrics canvas
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic,
                                        top: halfHeight - (slotHeight / 2) - targetOffset,
                                        left: 0,
                                        right: 0,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(_lyrics.length, (index) {
                                            final line = _lyrics[index];
                                            final isCurrent = index == activeIndex;

                                            return SizedBox(
                                              height: slotHeight,
                                              child: Center(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    if (line.timestamp > Duration.zero) {
                                                      _audioService.seek(line.timestamp);
                                                    }
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                                    child: AnimatedDefaultTextStyle(
                                                      duration: const Duration(milliseconds: 250),
                                                      curve: Curves.easeOut,
                                                      textAlign: TextAlign.center,
                                                      style: TextStyle(
                                                        color: isCurrent
                                                            ? AppTheme.accentLime
                                                            : AppTheme.textSecondary.withValues(alpha: 0.25),
                                                        fontSize: isCurrent ? 22 : 16,
                                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                                        letterSpacing: -0.3,
                                                      ),
                                                      child: Text(
                                                        line.text.isEmpty ? '♪' : line.text,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),

            // Bottom Section: Seekbar & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  StreamBuilder<Duration>(
                    stream: _audioService.positionStream,
                    builder: (context, posSnap) {
                      final pos = posSnap.data ?? Duration.zero;
                      return StreamBuilder<Duration?>(
                        stream: _audioService.durationStream,
                        builder: (context, durSnap) {
                          final dur = durSnap.data ?? Duration.zero;
                          final double maxSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
                          final double currentSec = pos.inSeconds.toDouble().clamp(0.0, maxSec);

                          return Column(
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppTheme.accentLime,
                                  inactiveTrackColor: AppTheme.surfaceLight,
                                  thumbColor: AppTheme.accentLime,
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: currentSec,
                                  min: 0.0,
                                  max: maxSec,
                                  onChanged: (val) {
                                    _audioService.seek(Duration(seconds: val.toInt()));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(dur),
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Controls Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StreamBuilder<PlayerState>(
                        stream: _audioService.playerStateStream,
                        builder: (context, snapshot) {
                          final isPlaying = snapshot.data?.playing ?? false;
                          final processing = snapshot.data?.processingState;

                          if (processing == ProcessingState.buffering ||
                              processing == ProcessingState.loading) {
                            return const SizedBox(
                              width: 56,
                              height: 56,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(color: AppTheme.accentLime),
                              ),
                            );
                          }

                          return IconButton(
                            iconSize: 56,
                            icon: Icon(
                              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              color: AppTheme.accentLime,
                            ),
                            onPressed: () => _audioService.togglePlayPause(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackArt() {
    return Container(
      width: 64,
      height: 64,
      color: AppTheme.surfaceLight,
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
    );
  }
}
