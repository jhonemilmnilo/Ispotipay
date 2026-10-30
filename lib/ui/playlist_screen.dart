import 'package:flutter/material.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/music_explore_service.dart';
import 'app_theme.dart';
import 'mini_player_bar.dart';
import 'player_screen.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;

  const PlaylistScreen({super.key, required this.playlist});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> with SingleTickerProviderStateMixin {
  final MusicExploreService _exploreService = MusicExploreService();
  final DatabaseService _dbService = DatabaseService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _shimmerController;

  final List<Track> _tracks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0.0, max: 1.0, period: const Duration(milliseconds: 1200));

    _scrollController.addListener(_onScroll);
    _loadInitialTracks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _shimmerController.dispose();
    _exploreService.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && !_isLoading) {
        _loadMoreTracks();
      }
    }
  }

  Future<void> _loadInitialTracks() async {
    final results = await _exploreService.searchTracks(widget.playlist.searchQuery, limit: 25);
    if (mounted) {
      setState(() {
        final existingIds = <String>{};
        final existingTitles = <String>{};
        final cleanList = <Track>[];

        for (final t in results) {
          final normKey = '${t.title.toLowerCase().trim()}_${t.artist.toLowerCase().trim()}';
          if (!existingIds.contains(t.id) && !existingTitles.contains(normKey)) {
            existingIds.add(t.id);
            existingTitles.add(normKey);
            cleanList.add(t);
          }
        }

        _tracks.addAll(cleanList);
        _isLoading = false;
        _offset = cleanList.length;
      });
    }
  }

  Future<void> _loadMoreTracks() async {
    setState(() {
      _isLoadingMore = true;
    });

    final results = await _exploreService.searchTracks(
      '${widget.playlist.searchQuery} ${_offset ~/ 25}',
      limit: 25,
    );

    if (mounted) {
      setState(() {
        final existingIds = _tracks.map((t) => t.id).toSet();
        final existingTitles = _tracks
            .map((t) => '${t.title.toLowerCase().trim()}_${t.artist.toLowerCase().trim()}')
            .toSet();

        for (final t in results) {
          final normKey = '${t.title.toLowerCase().trim()}_${t.artist.toLowerCase().trim()}';
          if (!existingIds.contains(t.id) && !existingTitles.contains(normKey)) {
            existingIds.add(t.id);
            existingTitles.add(normKey);
            _tracks.add(t);
          }
        }
        _offset += results.length;
        _isLoadingMore = false;
      });
    }
  }

  void _playTrack(Track track) {
    _audioService.playPlaylistTrack(
      track: track,
      allPlaylistTracks: List.from(_tracks),
      sourceTitle: widget.playlist.title,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.playlist.title,
          style: const TextStyle(fontSize: 18, color: AppTheme.textPrimary),
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header: Playlist Artwork & Details
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: widget.playlist.thumbnailUrl != null
                          ? Image.network(
                              widget.playlist.thumbnailUrl!,
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                            )
                          : Container(width: 180, height: 180, color: AppTheme.surfaceLight),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.playlist.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.playlist.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // Songs List
            if (_isLoading)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildShimmerTile(),
                  childCount: 8,
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _tracks[index];
                    return _buildSongTile(track);
                  },
                  childCount: _tracks.length,
                ),
              ),

            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: AppTheme.accentLime, strokeWidth: 2),
                    ),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: MiniPlayerBar(
        onTap: () {
          final current = _audioService.currentTrack;
          if (current != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlayerScreen(track: current)),
            );
          }
        },
      ),
    );
  }

  Widget _buildSongTile(Track track) {
    return ListTile(
      onTap: () => _playTrack(track),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.thumbnailUrl != null
            ? Image.network(
                track.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              )
            : Container(width: 48, height: 48, color: AppTheme.surfaceLight),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              track.isDownloaded ? Icons.download_done : Icons.download_outlined,
              color: track.isDownloaded ? AppTheme.accentLime : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () async {
              if (track.isDownloaded) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading "${track.title}" + lyrics...')),
              );
              final downloaded = await DownloadService().downloadTrack(track);
              if (downloaded != null && mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Downloaded with lyrics! Ready for offline.'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.textSecondary, size: 20),
            onPressed: () async {
              final isFav = await _dbService.toggleFavorite(track);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isFav ? 'Added to Favorites' : 'Removed from Favorites'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_circle_fill, color: AppTheme.accentLime, size: 28),
            onPressed: () => _playTrack(track),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerTile() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.12 + (0.18 * (0.5 - (_shimmerController.value - 0.5).abs()));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: opacity * 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: opacity * 3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 90,
                      height: 11,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight.withValues(alpha: opacity * 2),
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
}

