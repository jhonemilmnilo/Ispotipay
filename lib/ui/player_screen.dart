import 'dart:async';
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

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();
  final LyricsService _lyricsService = LyricsService();
  late AnimationController _shimmerController;

  Track? _activeTrack;
  List<LyricLine> _lyrics = [];
  bool _isLoadingLyrics = true;

  StreamSubscription<Track?>? _trackSub;

  @override
  void initState() {
    super.initState();
    _activeTrack = widget.track;
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0.0, max: 1.0, period: const Duration(milliseconds: 1200));

    _loadLyrics(_activeTrack!);

    // Listen to live track changes if a new track is selected
    _trackSub = _audioService.currentTrackStream.listen((newTrack) {
      if (newTrack != null && newTrack.id != _activeTrack?.id) {
        if (mounted) {
          setState(() {
            _activeTrack = newTrack;
            _lyrics = [];
            _isLoadingLyrics = true;
          });
          _loadLyrics(newTrack);
        }
      }
    });
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadLyrics(Track track) async {
    final lyrics = await _lyricsService.getLyrics(track);
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
            // Top Section: Track Info (Centered, No Thumbnail)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Text(
                    _activeTrack?.title ?? widget.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _activeTrack?.artist ?? widget.track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: AppTheme.divider, height: 24),

            // Middle Section: Strict Center-Locked Sliding Teleprompter Lyrics
            Expanded(
              child: StreamBuilder<bool>(
                stream: _audioService.isPreloadingStream,
                initialData: _audioService.isPreloading,
                builder: (context, preloadSnap) {
                  final isPreloading = preloadSnap.data ?? false;

                  if (isPreloading || _isLoadingLyrics) {
                    return _buildLyricsSkeleton();
                  }

                  if (_lyrics.isEmpty) {
                    return const Center(
                      child: Text(
                        'No lyrics found for this song',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return LayoutBuilder(
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

                            final targetOffset = (activeIndex * slotHeight);

                            return Stack(
                              children: [
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
                  );
                },
              ),
            ),

            // Bottom Section: Seekbar & Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: StreamBuilder<bool>(
                stream: _audioService.isPreloadingStream,
                initialData: _audioService.isPreloading,
                builder: (context, preloadSnap) {
                  final isPreloading = preloadSnap.data ?? false;

                  if (isPreloading) {
                    return _buildControlsSkeleton();
                  }

                  return Column(
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricsSkeleton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.15 + (0.25 * (0.5 - (_shimmerController.value - 0.5).abs()));
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 140,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: opacity * 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 240,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.accentLime.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 180,
                height: 18,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: opacity * 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsSkeleton() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('00:00', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              Text('--:--', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 56,
          height: 56,
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: CircularProgressIndicator(color: AppTheme.accentLime, strokeWidth: 3),
          ),
        ),
      ],
    );
  }
}
