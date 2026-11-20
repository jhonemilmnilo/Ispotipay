import 'package:flutter/material.dart';
import '../models/download_album.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../services/audio_player_service.dart';
import '../services/database_service.dart';
import '../services/download_service.dart';
import '../services/music_explore_service.dart';
import 'app_theme.dart';
import 'mini_player_bar.dart';
import 'player_screen.dart';
import 'widgets/app_toast.dart';
import 'widgets/download_album_picker_sheet.dart';

class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  final bool isLocalFavorites;
  final bool isLocalDownloads;
  final bool isLocalAlbum;
  final String? albumId;

  const PlaylistScreen({
    super.key,
    required this.playlist,
    this.isLocalFavorites = false,
    this.isLocalDownloads = false,
    this.isLocalAlbum = false,
    this.albumId,
  });

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
  final List<DownloadAlbum> _downloadAlbums = [];
  int _downloadTabIndex = 0; // 0: All Songs, 1: Albums
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
      if (!_isLoadingMore && !_isLoading && _downloadTabIndex == 0) {
        _loadMoreTracks();
      }
    }
  }

  Future<void> _loadDownloadAlbums() async {
    final albums = await _dbService.getDownloadAlbums();
    if (mounted) {
      setState(() {
        _downloadAlbums.clear();
        _downloadAlbums.addAll(albums);
      });
    }
  }

  Future<void> _loadInitialTracks() async {
    if (widget.isLocalAlbum && widget.albumId != null) {
      final albumTracks = await _dbService.getTracksForAlbum(widget.albumId!);
      if (mounted) {
        setState(() {
          _tracks.clear();
          _tracks.addAll(albumTracks);
          _isLoading = false;
          _offset = albumTracks.length;
        });
      }
      return;
    }

    if (widget.isLocalFavorites) {
      final favs = await _dbService.getFavorites(limit: 50, offset: 0);
      if (mounted) {
        setState(() {
          _tracks.addAll(favs);
          _isLoading = false;
          _offset = favs.length;
        });
      }
      return;
    }

    if (widget.isLocalDownloads) {
      final downloads = await _dbService.getDownloadedTracks(limit: 50, offset: 0);
      final albums = await _dbService.getDownloadAlbums();
      if (mounted) {
        setState(() {
          _tracks.addAll(downloads);
          _downloadAlbums.addAll(albums);
          _isLoading = false;
          _offset = downloads.length;
        });
      }
      return;
    }

    final results = await _exploreService.searchTracks(widget.playlist.searchQuery, limit: 25);
    if (mounted) {
      // Cross-check with local downloads to pre-mark already downloaded songs
      final downloadedList = await _dbService.getDownloadedTracks(limit: 200);
      final downloadedMap = {for (final d in downloadedList) d.id: d};

      setState(() {
        final existingIds = <String>{};
        final existingTitles = <String>{};
        final cleanList = <Track>[];

        for (final t in results) {
          final normKey = '${t.title.toLowerCase().trim()}_${t.artist.toLowerCase().trim()}';
          if (!existingIds.contains(t.id) && !existingTitles.contains(normKey)) {
            existingIds.add(t.id);
            existingTitles.add(normKey);
            // Apply downloaded paths if available locally
            final matchedDownloaded = downloadedMap[t.id];
            cleanList.add(matchedDownloaded ?? t);
          }
        }

        _tracks.addAll(cleanList);
        _isLoading = false;
        _offset = cleanList.length;
      });
      // Suspend shimmer animation ticker once loaded to conserve CPU
      _shimmerController.stop();
    }
  }

  Future<void> _loadMoreTracks() async {
    if (widget.isLocalFavorites) {
      setState(() {
        _isLoadingMore = true;
      });
      final favs = await _dbService.getFavorites(limit: 25, offset: _offset);
      if (mounted) {
        setState(() {
          _tracks.addAll(favs);
          _offset += favs.length;
          _isLoadingMore = false;
        });
      }
      return;
    }

    if (widget.isLocalDownloads) {
      setState(() {
        _isLoadingMore = true;
      });
      final downloads = await _dbService.getDownloadedTracks(limit: 25, offset: _offset);
      if (mounted) {
        setState(() {
          _tracks.addAll(downloads);
          _offset += downloads.length;
          _isLoadingMore = false;
        });
      }
      return;
    }

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

                    // Controls for Local Album
                    if (widget.isLocalAlbum && _tracks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _playTrack(_tracks.first),
                            icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.background),
                            label: const Text('Play Album', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentLime,
                              foregroundColor: AppTheme.background,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              final shuffled = List<Track>.from(_tracks)..shuffle();
                              _audioService.playPlaylistTrack(
                                track: shuffled.first,
                                allPlaylistTracks: shuffled,
                                sourceTitle: widget.playlist.title,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PlayerScreen(track: shuffled.first)),
                              );
                            },
                            icon: const Icon(Icons.shuffle_rounded, color: AppTheme.accentLime, size: 18),
                            label: const Text('Shuffle', style: TextStyle(color: AppTheme.accentLime)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.accentLime),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Tab Selector for Local Downloads (All Songs vs Albums)
                    if (widget.isLocalDownloads) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _downloadTabIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _downloadTabIndex == 0 ? AppTheme.accentLime : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'All Songs (${_tracks.length})',
                                  style: TextStyle(
                                    color: _downloadTabIndex == 0 ? AppTheme.background : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() => _downloadTabIndex = 1);
                                _loadDownloadAlbums();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _downloadTabIndex == 1 ? AppTheme.accentLime : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Albums (${_downloadAlbums.length})',
                                  style: TextStyle(
                                    color: _downloadTabIndex == 1 ? AppTheme.background : AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Play All & Shuffle Buttons for All Downloaded Songs
                      if (_downloadTabIndex == 0 && _tracks.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _playTrack(_tracks.first),
                              icon: const Icon(Icons.play_arrow_rounded, color: AppTheme.background),
                              label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentLime,
                                foregroundColor: AppTheme.background,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                final shuffled = List<Track>.from(_tracks)..shuffle();
                                _audioService.playPlaylistTrack(
                                  track: shuffled.first,
                                  allPlaylistTracks: shuffled,
                                  sourceTitle: 'All Downloads',
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => PlayerScreen(track: shuffled.first)),
                                );
                              },
                              icon: const Icon(Icons.shuffle_rounded, color: AppTheme.accentLime, size: 18),
                              label: const Text('Shuffle', style: TextStyle(color: AppTheme.accentLime)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.accentLime),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Slivers Content: Switch between Songs List and Albums List
            if (widget.isLocalDownloads && _downloadTabIndex == 1) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'OFFLINE ALBUMS',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showCreateAlbumDialog,
                        icon: const Icon(Icons.add, color: AppTheme.accentLime, size: 18),
                        label: const Text(
                          '+ New Album',
                          style: TextStyle(color: AppTheme.accentLime, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_downloadAlbums.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      children: [
                        Icon(Icons.album_outlined, color: AppTheme.textSecondary.withValues(alpha: 0.5), size: 48),
                        const SizedBox(height: 12),
                        const Text(
                          'No Albums Created Yet',
                          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "+ New Album" or select an album when downloading to organize your offline songs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = _downloadAlbums[index];
                      return _buildAlbumTile(album);
                    },
                    childCount: _downloadAlbums.length,
                  ),
                ),
            ] else ...[
              // Songs List
              if (_isLoading)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildShimmerTile(),
                    childCount: 8,
                  ),
                )
              else if (_tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Center(
                      child: Text(
                        widget.isLocalAlbum ? 'No songs in this album yet.' : 'No tracks found.',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _tracks[index];
                      return _buildSongTile(track, index);
                    },
                    childCount: _tracks.length,
                  ),
                ),
            ],

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

  void _showCreateAlbumDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'New Album',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Enter album name (e.g. Hits, Chill)...',
            hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.divider)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentLime)),
          ),
          onSubmitted: (_) async {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              await _dbService.createDownloadAlbum(name);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadDownloadAlbums();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentLime,
              foregroundColor: AppTheme.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await _dbService.createDownloadAlbum(name);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadDownloadAlbums();
              }
            },
            child: const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlbumDialog(DownloadAlbum album) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Album?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Delete "${album.name}"? The songs will still remain safe in your "All Downloads" library.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _dbService.deleteDownloadAlbum(album.id);
              if (ctx.mounted) Navigator.pop(ctx);
              _loadDownloadAlbums();
              if (mounted) {
                AppToast.show(
                  context,
                  message: 'Deleted album "${album.name}"',
                  icon: Icons.delete_outline_rounded,
                  iconColor: Colors.redAccent,
                );
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumTile(DownloadAlbum album) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlaylistScreen(
              playlist: Playlist(
                id: album.id,
                title: album.name,
                description: '${album.trackCount} downloaded songs',
                searchQuery: '',
                thumbnailUrl: album.coverUrl,
              ),
              isLocalAlbum: true,
              albumId: album.id,
            ),
          ),
        ).then((_) {
          _loadInitialTracks();
          _loadDownloadAlbums();
        });
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: album.coverUrl != null && album.coverUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  album.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.album_rounded,
                    color: AppTheme.accentLime,
                    size: 26,
                  ),
                ),
              )
            : const Icon(
                Icons.album_rounded,
                color: AppTheme.accentLime,
                size: 26,
              ),
      ),
      title: Text(
        album.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        '${album.trackCount} ${album.trackCount == 1 ? 'song' : 'songs'}',
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary, size: 20),
            onPressed: () => _showDeleteAlbumDialog(album),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppTheme.textSecondary,
            size: 14,
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Track track, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F1524),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 36),
              const SizedBox(height: 12),
              Text(
                widget.isLocalAlbum ? 'Album Options' : 'Delete Downloaded Track?',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.isLocalAlbum
                    ? 'Remove "${track.title}" from this album or delete from device completely?'
                    : 'Remove "${track.title}" from offline storage?\nSynced lyrics and audio file will be deleted.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.divider),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textPrimary)),
                    ),
                  ),
                  if (widget.isLocalAlbum && widget.albumId != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.surfaceLight,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _dbService.removeTrackFromDownloadAlbum(widget.albumId!, track.id);
                          if (mounted) {
                            setState(() {
                              _tracks.removeAt(index);
                            });
                            AppToast.show(
                              context,
                              message: 'Removed from "${widget.playlist.title}"',
                              icon: Icons.playlist_remove_rounded,
                            );
                          }
                        },
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final success = await DownloadService().deleteDownloadedTrack(track);
                        if (success && mounted) {
                          setState(() {
                            _tracks.removeAt(index);
                          });
                          AppToast.show(
                            context,
                            message: 'Deleted "${track.title}" from downloads',
                            icon: Icons.delete_outline_rounded,
                            iconColor: Colors.redAccent,
                          );
                        }
                      },
                      child: const Text(
                        'Delete File',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongTile(Track track, int index) {
    return ListTile(
      onTap: () => _playTrack(track),
      onLongPress: (widget.isLocalDownloads || widget.isLocalAlbum)
          ? () => _showDeleteConfirmation(track, index)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: track.thumbnailUrl != null
            ? Image.network(
                track.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                cacheWidth: 96,
                cacheHeight: 96,
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
              if (track.isDownloaded) {
                AppToast.show(
                  context,
                  message: 'Already downloaded for offline',
                  icon: Icons.download_done_rounded,
                  iconColor: AppTheme.accentLime,
                );
                return;
              }

              final selectedAlbumId = await DownloadAlbumPickerSheet.show(context, track);
              if (selectedAlbumId == null || !mounted) return;

              AppToast.show(
                context,
                message: 'Downloading "${track.title}"...',
                icon: Icons.downloading_rounded,
                iconColor: AppTheme.primary,
              );

              final downloaded = await DownloadService().downloadTrack(
                track,
                albumId: selectedAlbumId == 'general' ? null : selectedAlbumId,
              );
              if (downloaded != null && mounted) {
                setState(() {
                  _tracks[index] = downloaded;
                });
                AppToast.show(
                  context,
                  message: 'Downloaded "${track.title}" + lyrics',
                  icon: Icons.download_done_rounded,
                  iconColor: AppTheme.accentLime,
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.textSecondary, size: 20),
            onPressed: () async {
              final isFav = await _dbService.toggleFavorite(track);
              if (mounted) {
                AppToast.show(
                  context,
                  message: isFav ? 'Added to Favorites' : 'Removed from Favorites',
                  icon: isFav ? Icons.favorite : Icons.favorite_border,
                  iconColor: isFav ? Colors.redAccent : AppTheme.textSecondary,
                );
              }
            },
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

