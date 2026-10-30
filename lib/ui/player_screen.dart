import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/lyric_line.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../services/lyrics_service.dart';
import '../services/music_explore_service.dart';
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
  final MusicExploreService _exploreService = MusicExploreService();
  final DatabaseService _dbService = DatabaseService();
  late AnimationController _shimmerController;

  Track? _activeTrack;
  List<LyricLine> _lyrics = [];
  bool _isLoadingLyrics = true;
  bool _isFavorite = false;

  List<Track> _upNextTracks = [];
  List<Track> _historyTracks = [];
  bool _isLoadingUpNext = false;
  bool _isLoadingMoreUpNext = false;

  StreamSubscription<Track?>? _trackSub;
  StreamSubscription<List<Track>>? _queueSub;
  StreamSubscription<List<Track>>? _historySub;

  @override
  void initState() {
    super.initState();
    _activeTrack = widget.track;
    _historyTracks = List.from(_audioService.playbackHistory);
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0.0, max: 1.0, period: const Duration(milliseconds: 1200));

    _loadLyrics(_activeTrack!);
    _checkFavoriteStatus(_activeTrack!);

    // If AudioPlayerService already has a populated queue, use it; otherwise generate fresh
    if (_audioService.queue.isNotEmpty) {
      _upNextTracks = List.from(_audioService.queue);
    } else {
      _loadUpNext(_activeTrack!);
    }

    // Listen to live track changes if a new track is selected or auto-played
    _trackSub = _audioService.currentTrackStream.listen((newTrack) {
      if (newTrack != null && newTrack.id != _activeTrack?.id) {
        if (mounted) {
          setState(() {
            _activeTrack = newTrack;
            _historyTracks = List.from(_audioService.playbackHistory);
            _lyrics = [];
            _isLoadingLyrics = true;
          });
          _loadLyrics(newTrack);
          _checkFavoriteStatus(newTrack);
        }
      }
    });

    // Listen to queue updates from AudioPlayerService
    _queueSub = _audioService.queueStream.listen((updatedQueue) {
      if (mounted) {
        setState(() {
          _upNextTracks = List.from(updatedQueue);
        });
      }
    });

    // Listen to history updates from AudioPlayerService
    _historySub = _audioService.historyStream.listen((updatedHistory) {
      if (mounted) {
        setState(() {
          _historyTracks = List.from(updatedHistory);
        });
      }
    });
  }

  @override
  void dispose() {
    _trackSub?.cancel();
    _queueSub?.cancel();
    _historySub?.cancel();
    _shimmerController.dispose();
    _exploreService.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus(Track track) async {
    final fav = await _dbService.isFavorite(track.id);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
      });
    }
  }

  Future<void> _loadUpNext(Track track) async {
    setState(() {
      _isLoadingUpNext = true;
    });

    final queue = await _exploreService.getUpNextQueue(track, limit: 25);
    if (mounted) {
      setState(() {
        _upNextTracks = queue;
        _isLoadingUpNext = false;
      });
      _audioService.setQueue(queue);
    }
  }

  Future<void> _loadMoreUpNext() async {
    if (_isLoadingMoreUpNext || _activeTrack == null) return;
    setState(() {
      _isLoadingMoreUpNext = true;
    });

    final more = await _exploreService.getUpNextQueue(_activeTrack!, limit: 20);
    if (mounted) {
      _audioService.appendToQueue(more);
      setState(() {
        _isLoadingMoreUpNext = false;
      });
    }
  }

  Widget _buildUnifiedQueueItem({
    required BuildContext ctx,
    required Track track,
    required bool isPlaying,
    required bool isHistory,
    required int listIndex,
  }) {
    if (isPlaying) {
      // Live Track: Centerpiece with rotating circular progress border around thumbnail!
      return StreamBuilder<Duration>(
        stream: _audioService.positionStream,
        builder: (context, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          return StreamBuilder<Duration?>(
            stream: _audioService.durationStream,
            builder: (context, durSnap) {
              final dur = durSnap.data ?? Duration.zero;
              final double progress = dur.inMilliseconds > 0
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.28),
                      const Color(0xFF0F1829),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentLime.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentLime.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Circular Progress Rotating Border wrapping the thumbnail
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.8,
                            backgroundColor: AppTheme.surfaceLight.withValues(alpha: 0.3),
                            color: AppTheme.accentLime,
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: track.thumbnailUrl != null
                                ? Image.network(
                                    track.thumbnailUrl!,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                    frameBuilder: (context, child, frame, wasSync) {
                                      if (wasSync || frame != null) return child;
                                      return _buildCustomThumbnail(
                                        title: track.title,
                                        artist: track.artist,
                                        size: 42,
                                      );
                                    },
                                    errorBuilder: (_, _, _) => _buildCustomThumbnail(
                                      title: track.title,
                                      artist: track.artist,
                                      size: 42,
                                    ),
                                  )
                                : _buildCustomThumbnail(
                                    title: track.title,
                                    artist: track.artist,
                                    size: 42,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.graphic_eq, color: AppTheme.accentLime, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'PLAYING NOW',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDuration(pos),
                      style: const TextStyle(
                        color: AppTheme.accentLime,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Drag handle for Current Playing Song!
                    ReorderableDragStartListener(
                      index: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.drag_handle_rounded,
                          color: AppTheme.accentLime,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    // Finished History Song or Upcoming Queue Song
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Opacity(
              opacity: isHistory ? 0.6 : 1.0,
              child: track.thumbnailUrl != null
                  ? Image.network(
                      track.thumbnailUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSync) {
                        if (wasSync || frame != null) return child;
                        return _buildCustomThumbnail(
                          title: track.title,
                          artist: track.artist,
                          size: 44,
                        );
                      },
                      errorBuilder: (_, _, _) => _buildCustomThumbnail(
                        title: track.title,
                        artist: track.artist,
                        size: 44,
                      ),
                    )
                  : _buildCustomThumbnail(
                      title: track.title,
                      artist: track.artist,
                      size: 44,
                    ),
            ),
          ),
          if (isHistory)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
        ],
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isHistory
              ? AppTheme.textSecondary
              : AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: isHistory ? FontWeight.normal : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        isHistory ? '${track.artist} • Played' : track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isHistory
              ? AppTheme.textSecondary.withValues(alpha: 0.7)
              : AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: isHistory
          ? const Icon(
              Icons.replay_rounded,
              color: AppTheme.textSecondary,
              size: 22,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 4),
                // Drag handle for reordering queue (relative to active timeline where 0 is currently playing)
                ReorderableDragStartListener(
                  index: listIndex - _historyTracks.length,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: const Icon(
                      Icons.drag_handle_rounded,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
      onTap: () {
        Navigator.pop(ctx);
        if (isHistory) {
          _audioService.playFromHistory(listIndex);
        } else {
          // Adjust for history count and current track
          final queueIndex = listIndex - _historyTracks.length - 1;
          _audioService.playFromQueue(queueIndex);
        }
      },
    );
  }

  void _showUpNextDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 260),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.94,
          snap: true,
          snapSizes: const [0.35, 0.65, 0.94],
          builder: (sheetContext, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0A0F1D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 25,
                    offset: Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // YouTube Music Style Grab Handle Pill
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppTheme.textSecondary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Drawer Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Up Next',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Playing from: Radio • Similar to ${_activeTrack?.artist ?? ''}',
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLime.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_upNextTracks.length} tracks',
                            style: const TextStyle(
                              color: AppTheme.accentLime,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.divider, height: 24),

                  // Unified Timeline Queue List: [Previous/History, Currently Playing, Upcoming Next with Drag & Drop]
                  Expanded(
                    child: _isLoadingUpNext
                        ? _buildUpNextShimmerList()
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo.metrics.pixels >=
                                  scrollInfo.metrics.maxScrollExtent - 200) {
                                _loadMoreUpNext();
                              }
                              return false;
                            },
                            child: ListView(
                              controller: scrollController,
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              children: [
                                // 1. Finished History Items (at the top)
                                for (int i = 0; i < _historyTracks.length; i++)
                                  _buildUnifiedQueueItem(
                                    ctx: ctx,
                                    track: _historyTracks[i],
                                    isPlaying: false,
                                    isHistory: true,
                                    listIndex: i,
                                  ),

                                // 2. Unified Draggable Active Timeline: [Currently Playing + Upcoming Queue]
                                Builder(
                                  builder: (context) {
                                    final activeList = <Track>[];
                                    if (_activeTrack != null) activeList.add(_activeTrack!);
                                    activeList.addAll(_upNextTracks);

                                    if (activeList.isEmpty) return const SizedBox.shrink();

                                    return ReorderableListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      buildDefaultDragHandles: false,
                                      itemCount: activeList.length,
                                      onReorderItem: (oldIdx, newIdx) async {
                                        setState(() {
                                          final moved = activeList.removeAt(oldIdx);
                                          activeList.insert(newIdx, moved);
                                          _activeTrack = activeList.first;
                                          _upNextTracks = activeList.sublist(1);
                                        });

                                        await _audioService.reorderActiveTimeline(oldIdx, newIdx);
                                      },
                                      itemBuilder: (context, activeIdx) {
                                        final track = activeList[activeIdx];
                                        final isCurrent = activeIdx == 0 && _activeTrack != null;
                                        final overallIndex = _historyTracks.length + activeIdx;

                                        return Container(
                                          key: ValueKey('active_${track.id}_$activeIdx'),
                                          child: _buildUnifiedQueueItem(
                                            ctx: ctx,
                                            track: track,
                                            isPlaying: isCurrent,
                                            isHistory: false,
                                            listIndex: overallIndex,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),

                                // 4. Shimmer loading footer when paginating
                                if (_isLoadingMoreUpNext) ...[
                                  _buildShimmerQueueTile(),
                                  _buildShimmerQueueTile(),
                                ],

                                if (_historyTracks.isEmpty &&
                                    _activeTrack == null &&
                                    _upNextTracks.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Text(
                                        'Queue is empty',
                                        style: TextStyle(color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _activeTrack?.title ?? widget.track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _activeTrack?.artist ?? widget.track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Divider(color: AppTheme.divider, height: 16),

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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Left: YouTube Music Style Up Next Queue Button
                          IconButton(
                            icon: const Icon(
                              Icons.queue_music,
                              color: AppTheme.textPrimary,
                              size: 26,
                            ),
                            tooltip: 'Up Next',
                            onPressed: () => _showUpNextDrawer(context),
                          ),

                          // Center Cluster: Previous, Play/Pause, Next
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Previous Song Button
                              IconButton(
                                iconSize: 38,
                                icon: const Icon(
                                  Icons.skip_previous_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                tooltip: 'Previous',
                                onPressed: () => _audioService.playPrevious(),
                              ),
                              const SizedBox(width: 8),

                              // Main Play / Pause Button
                              StreamBuilder<PlayerState>(
                                stream: _audioService.playerStateStream,
                                builder: (context, snapshot) {
                                  final isPlaying = snapshot.data?.playing ?? false;
                                  final processing = snapshot.data?.processingState;

                                  if (processing == ProcessingState.buffering ||
                                      processing == ProcessingState.loading) {
                                    return const SizedBox(
                                      width: 60,
                                      height: 60,
                                      child: Padding(
                                        padding: EdgeInsets.all(14.0),
                                        child: CircularProgressIndicator(color: AppTheme.accentLime),
                                      ),
                                    );
                                  }

                                  return IconButton(
                                    iconSize: 60,
                                    icon: Icon(
                                      isPlaying
                                          ? Icons.pause_circle_filled
                                          : Icons.play_circle_filled,
                                      color: AppTheme.accentLime,
                                    ),
                                    onPressed: () => _audioService.togglePlayPause(),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),

                              // Next Song Button (Strictly plays next track in Up Next queue)
                              IconButton(
                                iconSize: 38,
                                icon: const Icon(
                                  Icons.skip_next_rounded,
                                  color: AppTheme.textPrimary,
                                ),
                                tooltip: 'Next',
                                onPressed: () => _audioService.playNext(),
                              ),
                            ],
                          ),

                          // Right: Favorite Heart Toggle
                          IconButton(
                            icon: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.redAccent : AppTheme.textPrimary,
                              size: 24,
                            ),
                            tooltip: 'Favorite',
                            onPressed: () async {
                              if (_activeTrack != null) {
                                final isFav = await _dbService.toggleFavorite(_activeTrack!);
                                if (!context.mounted) return;
                                setState(() {
                                  _isFavorite = isFav;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(isFav
                                        ? 'Added to Favorites'
                                        : 'Removed from Favorites'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
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

  Widget _buildCustomThumbnail({
    required String title,
    required String artist,
    double size = 46,
  }) {
    // Deterministic accent shade based on title character
    final int charCode = title.isNotEmpty ? title.codeUnitAt(0) : 65;
    final List<Color> gradientColors = [
      const Color(0xFF1558C9),
      Color.lerp(const Color(0xFF030407), const Color(0xFF1558C9), (charCode % 5) / 10)!,
      const Color(0xFF0A0F1D),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(size * 0.16),
        border: Border.all(
          color: AppTheme.accentLime.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vinyl disc grooves illusion
          Container(
            width: size * 0.75,
            height: size * 0.75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
          ),
          // Center Cyber Lime Icon
          Icon(
            Icons.music_note_rounded,
            color: AppTheme.accentLime,
            size: size * 0.45,
          ),
        ],
      ),
    );
  }

  Widget _buildUpNextShimmerList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      itemBuilder: (_, _) => _buildShimmerQueueTile(),
    );
  }

  Widget _buildShimmerQueueTile() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.12 + (0.18 * (0.5 - (_shimmerController.value - 0.5).abs()));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: opacity),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 130,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: opacity * 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
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
