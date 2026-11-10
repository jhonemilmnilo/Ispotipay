import 'dart:async';
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
import 'playlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final MusicExploreService _exploreService = MusicExploreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _playlistScrollController = ScrollController();
  final ScrollController _topMusicScrollController = ScrollController();
  late AnimationController _shimmerController;

  Timer? _debounceTimer;
  StreamSubscription<void>? _librarySubscription;

  final List<Track> _topMusic = [];
  final List<Track> _recommended = [];
  final List<Playlist> _topPlaylists = [];
  final List<Playlist> _artistAlbums = [];
  List<Track> _recents = [];
  List<Track> _favorites = [];
  List<Track> _downloads = [];
  List<Track> _mostPlayed = [];
  final List<Track> _allMusic = [];

  bool _isLoadingTop = true;
  bool _isLoadingMoreTop = false;
  bool _isLoadingRecommended = true;
  bool _isLoadingPlaylists = true;
  bool _isLoadingMorePlaylists = false;
  bool _isLoadingAll = true;
  bool _isLoadingMoreAll = false;
  bool _isSearching = false;
  List<Track> _searchResults = [];
  List<Track> _lyricResults = [];
  List<Playlist> _searchMatchedAlbums = [];
  List<String> _suggestions = [];
  final FocusNode _searchFocusNode = FocusNode();
  int _playlistOffset = 0;
  int _topMusicOffset = 0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: 0.0, max: 1.0, period: const Duration(milliseconds: 1200));

    _scrollController.addListener(_onScroll);
    _playlistScrollController.addListener(_onPlaylistScroll);
    _topMusicScrollController.addListener(_onTopMusicScroll);

    // Real-time library updates listener (Favorites & Downloads counter parity)
    _librarySubscription = _dbService.libraryUpdatesStream.listen((_) {
      if (mounted) {
        _loadLocalLibrary();
      }
    });

    _loadAllSections();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _librarySubscription?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _playlistScrollController.dispose();
    _topMusicScrollController.dispose();
    _shimmerController.dispose();
    _exploreService.dispose();
    super.dispose();
  }

  void _onTopMusicScroll() {
    if (_topMusicScrollController.position.pixels >=
        _topMusicScrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMoreTop) {
        _loadMoreTopMusic();
      }
    }
  }

  Future<void> _loadMoreTopMusic() async {
    setState(() {
      _isLoadingMoreTop = true;
    });

    final newTracks = await _exploreService.getTopMusic(
      offset: _topMusicOffset,
      limit: 15,
    );

    if (mounted) {
      setState(() {
        final existingIds = _topMusic.map((t) => t.id).toSet();
        for (final t in newTracks) {
          if (!existingIds.contains(t.id)) {
            _topMusic.add(t);
          }
        }
        _topMusicOffset += newTracks.length;
        _isLoadingMoreTop = false;
      });
    }
  }

  void _onPlaylistScroll() {
    if (_playlistScrollController.position.pixels >=
        _playlistScrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMorePlaylists) {
        _loadMorePlaylists();
      }
    }
  }

  Future<void> _loadMorePlaylists() async {
    setState(() {
      _isLoadingMorePlaylists = true;
    });

    final newPlaylists = _exploreService.getTopPlaylists(
      offset: _playlistOffset,
      limit: 15,
    );

    if (mounted) {
      setState(() {
        // Enforce strict deduplication so no playlist is ever repeated
        final existingIds = _topPlaylists.map((p) => p.id).toSet();
        for (final p in newPlaylists) {
          if (!existingIds.contains(p.id)) {
            _topPlaylists.add(p);
          }
        }
        _playlistOffset += newPlaylists.length;
        _isLoadingMorePlaylists = false;
      });
    }
  }

  void _onScroll() {
    // Infinite scroll trigger: when user is 300px away from the bottom
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMoreAll && !_isSearching) {
        _loadMoreAllMusic();
      }
    }
  }

  Future<void> _loadMoreAllMusic() async {
    setState(() {
      _isLoadingMoreAll = true;
    });

    final newBatch = await _exploreService.fetchNextAllMusicBatch(batchSize: 25);
    if (mounted) {
      setState(() {
        // Prevent duplicate IDs
        final existingIds = _allMusic.map((t) => t.id).toSet();
        for (final track in newBatch) {
          if (!existingIds.contains(track.id)) {
            _allMusic.add(track);
          }
        }
        _isLoadingMoreAll = false;
      });
    }
  }

  Future<void> _loadLocalLibrary() async {
    final recents = await _dbService.getRecents(limit: 15);
    final favs = await _dbService.getFavorites(limit: 25);
    final downloads = await _dbService.getDownloadedTracks(limit: 50);
    final mostPlayed = await _dbService.getMostPlayed(limit: 10);

    if (mounted) {
      setState(() {
        _recents = recents;
        _favorites = favs;
        _downloads = downloads;
        _mostPlayed = mostPlayed;
      });
    }
  }

  Future<void> _loadAllSections() async {
    // 1. Load local SQLite data
    await _loadLocalLibrary();

    // 2. Load online Top & All Music
    _fetchOnlineMusic();
  }

  Future<void> _fetchOnlineMusic() async {
    _topMusicOffset = 0;
    final top = await _exploreService.getTopMusic(offset: 0, limit: 15);
    final recommended = await _exploreService.getRecommendedTracks(limit: 20);
    final all = await _exploreService.fetchNextAllMusicBatch(batchSize: 25);
    final playlists = _exploreService.getTopPlaylists(offset: 0, limit: 15);
    final artistAlbums = _exploreService.getArtistAlbums();

    if (mounted) {
      setState(() {
        _topMusic.clear();
        _topMusic.addAll(top);
        _topMusicOffset = top.length;

        _recommended.clear();
        _recommended.addAll(recommended);
        _isLoadingRecommended = false;

        _topPlaylists.clear();
        _topPlaylists.addAll(playlists);
        _playlistOffset = playlists.length;
        _isLoadingPlaylists = false;

        _artistAlbums.clear();
        _artistAlbums.addAll(artistAlbums);

        // Strictly preserve and append initial All Music
        _allMusic.clear();
        _allMusic.addAll(all);

        _isLoadingTop = false;
        _isLoadingAll = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _lyricResults = [];
        _searchMatchedAlbums = [];
        _suggestions = [];
      });
      return;
    }

    // Instant query suggestions
    setState(() {
      _suggestions = _exploreService.getSearchSuggestions(query);
    });

    // 400ms Debounce rule for network search
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final futures = await Future.wait([
        _exploreService.searchTracks(query),
        _exploreService.searchArtistsAndAlbums(query),
        _exploreService.searchTracksByLyrics(query),
      ]);

      final tracks = futures[0] as List<Track>;
      final albums = futures[1] as List<Playlist>;
      final lyricTracks = futures[2] as List<Track>;

      // Deduplicate lyricTracks if already present in direct track results
      final trackIds = tracks.map((t) => t.id).toSet();
      final trackNames = tracks.map((t) => '${t.title.toLowerCase()}_${t.artist.toLowerCase()}').toSet();
      final cleanLyricMatches = lyricTracks.where((lt) {
        final key = '${lt.title.toLowerCase()}_${lt.artist.toLowerCase()}';
        return !trackIds.contains(lt.id) && !trackNames.contains(key);
      }).toList();

      if (mounted) {
        setState(() {
          _isSearching = true;
          _searchResults = tracks;
          _searchMatchedAlbums = albums;
          _lyricResults = cleanLyricMatches;
        });
      }
    });
  }

  void _applySuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchFocusNode.unfocus();
    _onSearchChanged(suggestion);
  }

  void _playTrack(Track track) async {
    await AudioPlayerService().playTrack(track, resetQueue: true);
    _loadAllSections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1. Header & Sticky Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'IsPo',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'TiPay',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Top Bar Action Pills: Favorites & Downloads
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Favorites Pill Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PlaylistScreen(
                                      playlist: Playlist(
                                        id: 'local_favorites',
                                        title: 'Liked Songs & Favorites',
                                        description: 'Your saved favorite tracks',
                                        searchQuery: '',
                                      ),
                                      isLocalFavorites: true,
                                    ),
                                  ),
                                ).then((_) => _loadLocalLibrary());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _favorites.isNotEmpty
                                        ? Colors.redAccent.withValues(alpha: 0.5)
                                        : AppTheme.divider,
                                    width: 1.1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _favorites.isNotEmpty ? Icons.favorite : Icons.favorite_border,
                                      color: _favorites.isNotEmpty ? Colors.redAccent : AppTheme.textSecondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_favorites.length}',
                                      style: TextStyle(
                                        color: _favorites.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Downloads Pill Button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PlaylistScreen(
                                      playlist: Playlist(
                                        id: 'local_downloads',
                                        title: 'Downloaded Songs',
                                        description: 'Offline audio with synced lyrics',
                                        searchQuery: '',
                                      ),
                                      isLocalDownloads: true,
                                    ),
                                  ),
                                ).then((_) => _loadLocalLibrary());
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _downloads.isNotEmpty
                                        ? AppTheme.accentLime.withValues(alpha: 0.5)
                                        : AppTheme.divider,
                                    width: 1.1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _downloads.isNotEmpty ? Icons.download_done_rounded : Icons.download_rounded,
                                      color: _downloads.isNotEmpty ? AppTheme.accentLime : AppTheme.textSecondary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_downloads.length}',
                                      style: TextStyle(
                                        color: _downloads.isNotEmpty ? AppTheme.textPrimary : AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(),
                  ],
                ),
              ),
            ),

            if (_isSearching) ...[
              // Search Results View: Artists & Albums Section if available
              if (_searchMatchedAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: Text(
                      'Artists & Albums (${_searchMatchedAlbums.length})',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 190,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _searchMatchedAlbums.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final album = _searchMatchedAlbums[index];
                        final isArtist = album.id.startsWith('artist_');

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlaylistScreen(playlist: album),
                              ),
                            ).then((_) => _loadLocalLibrary());
                          },
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isArtist
                                    ? AppTheme.accentLime.withValues(alpha: 0.3)
                                    : AppTheme.primary.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(isArtist ? 45 : 8),
                                      child: album.thumbnailUrl != null
                                          ? Image.network(
                                              album.thumbnailUrl!,
                                              width: 90,
                                              height: 90,
                                              fit: BoxFit.cover,
                                              cacheWidth: 180,
                                              cacheHeight: 180,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                width: 90,
                                                height: 90,
                                                color: AppTheme.surfaceLight,
                                                child: Icon(
                                                  isArtist ? Icons.person : Icons.album,
                                                  color: AppTheme.textSecondary,
                                                  size: 32,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 90,
                                              height: 90,
                                              color: AppTheme.surfaceLight,
                                              child: Icon(
                                                isArtist ? Icons.person : Icons.album,
                                                color: AppTheme.textSecondary,
                                                size: 32,
                                              ),
                                            ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isArtist ? 'ARTIST' : 'ALBUM',
                                          style: TextStyle(
                                            color: isArtist ? AppTheme.accentLime : AppTheme.textPrimary,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        album.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        album.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],

              // Songs Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Songs (${_searchResults.length})',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _searchResults[index];
                    return _buildSongListTile(track);
                  },
                  childCount: _searchResults.length,
                ),
              ),

              // Matching Lyrics Section
              if (_lyricResults.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Row(
                      children: const [
                        Icon(Icons.lyrics_rounded, color: AppTheme.accentLime, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Matches In Lyrics',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _lyricResults[index];
                      return _buildSongListTile(track, isLyricMatch: true);
                    },
                    childCount: _lyricResults.length,
                  ),
                ),
              ],
            ] else ...[
              // 2. Top Music Section (Horizontal Carousel with Infinite Scroll)
              SliverToBoxAdapter(
                child: _buildSectionHeader('Top Music', icon: Icons.trending_up),
              ),
              SliverToBoxAdapter(
                child: _buildTopMusicCarousel(),
              ),

              // Recommended For You Section (Spotify / YT Music Taste-based, max 20)
              if (_recommended.isNotEmpty || _isLoadingRecommended) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader(
                    'Recommended For You',
                    icon: Icons.auto_awesome,
                    iconColor: AppTheme.accentLime,
                    badge: '${_recommended.length}/20',
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalCarousel(
                    tracks: _recommended,
                    isLoading: _isLoadingRecommended,
                    cardWidth: 145,
                    cardHeight: 215,
                  ),
                ),
              ],

              // 3. Recent Played Section (Horizontal Carousel, Max 15)
              if (_recents.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Recently Played', badge: '${_recents.length}/15'),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalCarousel(
                    tracks: _recents,
                    isLoading: false,
                    cardWidth: 140,
                    cardHeight: 205,
                  ),
                ),
              ],

              // 4. Favorites Section (Horizontal Carousel)
              if (_favorites.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Your Favorites', icon: Icons.favorite, iconColor: Colors.redAccent),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalCarousel(
                    tracks: _favorites,
                    isLoading: false,
                    cardWidth: 140,
                    cardHeight: 205,
                  ),
                ),
              ],

              // 5. Most Played Section (Horizontal Carousel, Max 10)
              if (_mostPlayed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Most Played', badge: 'Top ${_mostPlayed.length}'),
                ),
                SliverToBoxAdapter(
                  child: _buildHorizontalCarousel(
                    tracks: _mostPlayed,
                    isLoading: false,
                    cardWidth: 130,
                    cardHeight: 205,
                    showPlayCount: false,
                  ),
                ),
              ],

              // Top Playlists Section (Horizontal Carousel)
              if (_topPlaylists.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Top Playlists', icon: Icons.queue_music),
                ),
                SliverToBoxAdapter(
                  child: _buildPlaylistsCarousel(),
                ),
              ],

              // Featured Artist Albums & Discographies (Horizontal Carousel)
              if (_artistAlbums.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionHeader('Artist Spotlights & Albums', icon: Icons.album_rounded),
                ),
                SliverToBoxAdapter(
                  child: _buildArtistAlbumsCarousel(),
                ),
              ],

              // 6. All Music Section (Vertical List at the bottom)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: const [
                      Icon(Icons.library_music, color: AppTheme.accentLime, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'All Music',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _isLoadingAll
                  ? SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildShimmerSongTile(),
                        childCount: 6,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _allMusic[index];
                          return _buildSongListTile(track);
                        },
                        childCount: _allMusic.length,
                        addAutomaticKeepAlives: false,
                        addRepaintBoundaries: true,
                      ),
                    ),
              if (_isLoadingMoreAll)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accentLime,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      bottomNavigationBar: MiniPlayerBar(
        onTap: () {
          final current = AudioPlayerService().currentTrack;
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

  Widget _buildSearchBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search songs, lyrics, artists, albums...',
              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: AppTheme.accentLime),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty && _searchController.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AppTheme.surfaceLight,
                    side: BorderSide(
                      color: AppTheme.accentLime.withValues(alpha: 0.35),
                      width: 0.9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      suggestion,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _applySuggestion(suggestion),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Color? iconColor, String? badge}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? AppTheme.accentLime, size: 18),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCarousel({
    required List<Track> tracks,
    required bool isLoading,
    required double cardWidth,
    required double cardHeight,
    bool showPlayCount = false,
  }) {
    if (isLoading) {
      return SizedBox(
        height: cardHeight,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    if (tracks.isEmpty) {
      return SizedBox(
        height: cardHeight,
        child: const Center(
          child: Text(
            'No songs yet',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return GestureDetector(
            onTap: () {
              _playTrack(track);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              );
            },
            child: Container(
              width: cardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: track.thumbnailUrl != null
                          ? Image.network(
                              track.thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 280,
                              cacheHeight: 280,
                              frameBuilder: (context, child, frame, wasSync) {
                                if (wasSync || frame != null) return child;
                                return _buildFallbackThumbnail(
                                  title: track.title,
                                  artist: track.artist,
                                );
                              },
                              errorBuilder: (_, _, _) => _buildFallbackThumbnail(
                                title: track.title,
                                artist: track.artist,
                              ),
                            )
                          : _buildFallbackThumbnail(
                              title: track.title,
                              artist: track.artist,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (showPlayCount)
                        Text(
                          '${track.playCount}x',
                          style: const TextStyle(
                            color: AppTheme.accentLime,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopMusicCarousel() {
    if (_isLoadingTop) {
      return SizedBox(
        height: 220,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          itemBuilder: (context, index) => _buildShimmerCard(),
        ),
      );
    }

    if (_topMusic.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text(
            'No top music found',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        controller: _topMusicScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _topMusic.length + (_isLoadingMoreTop ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _topMusic.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppTheme.accentLime, strokeWidth: 2),
                ),
              ),
            );
          }

          final track = _topMusic[index];
          return GestureDetector(
            onTap: () {
              _playTrack(track);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
              );
            },
            child: Container(
              width: 150,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: track.thumbnailUrl != null
                          ? Image.network(
                              track.thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 280,
                              cacheHeight: 280,
                              frameBuilder: (context, child, frame, wasSync) {
                                if (wasSync || frame != null) return child;
                                return _buildFallbackThumbnail(
                                  title: track.title,
                                  artist: track.artist,
                                );
                              },
                              errorBuilder: (_, _, _) => _buildFallbackThumbnail(
                                title: track.title,
                                artist: track.artist,
                              ),
                            )
                          : _buildFallbackThumbnail(
                              title: track.title,
                              artist: track.artist,
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylistsCarousel() {
    if (_isLoadingPlaylists) {
      return SizedBox(
        height: 205,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          itemBuilder: (context, index) => _buildShimmerCard(),
        ),
      );
    }

    return SizedBox(
      height: 205,
      child: ListView.builder(
        controller: _playlistScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _topPlaylists.length + (_isLoadingMorePlaylists ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _topPlaylists.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: AppTheme.accentLime, strokeWidth: 2),
                ),
              ),
            );
          }

          final playlist = _topPlaylists[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: playlist)),
              ).then((_) {
                // Refresh only local recents and favorites when coming back
                _loadLocalLibrary();
              });
            },
            child: Container(
              width: 130,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: playlist.thumbnailUrl != null
                          ? Image.network(
                              playlist.thumbnailUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 260,
                              cacheHeight: 260,
                              errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
                            )
                          : _buildFallbackThumbnail(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    playlist.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildArtistAlbumsCarousel() {
    return SizedBox(
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _artistAlbums.length,
        itemBuilder: (context, index) {
          final album = _artistAlbums[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PlaylistScreen(playlist: album)),
              ).then((_) {
                _loadLocalLibrary();
              });
            },
            child: Container(
              width: 140,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: album.thumbnailUrl != null
                              ? Image.network(
                                  album.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
                                )
                              : _buildFallbackThumbnail(),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppTheme.accentLime.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.album, size: 10, color: AppTheme.accentLime),
                            SizedBox(width: 3),
                            Text(
                              'ALBUM',
                              style: TextStyle(
                                color: AppTheme.accentLime,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongListTile(Track track, {bool isLyricMatch = false}) {
    return ListTile(
      onTap: () {
        _playTrack(track);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PlayerScreen(track: track)),
        );
      },
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
                frameBuilder: (context, child, frame, wasSync) {
                  if (wasSync || frame != null) return child;
                  return _buildFallbackThumbnail(
                    title: track.title,
                    artist: track.artist,
                    size: 48,
                  );
                },
                errorBuilder: (_, _, _) => _buildFallbackThumbnail(
                  title: track.title,
                  artist: track.artist,
                  size: 48,
                ),
              )
            : _buildFallbackThumbnail(
                title: track.title,
                artist: track.artist,
                size: 48,
              ),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              track.title,
              maxLines: isLyricMatch ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          if (isLyricMatch)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppTheme.accentLime.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lyrics, size: 9, color: AppTheme.accentLime),
                  SizedBox(width: 3),
                  Text(
                    'LYRICS',
                    style: TextStyle(
                      color: AppTheme.accentLime,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Song already downloaded')),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading "${track.title}" + lyrics...')),
              );
              final downloaded = await DownloadService().downloadTrack(track);
              if (downloaded != null && mounted) {
                _loadAllSections();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppTheme.surfaceLight,
                    content: Text(
                      'Downloaded with lyrics! Ready for offline.',
                      style: TextStyle(color: AppTheme.accentLime),
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppTheme.textSecondary, size: 20),
            onPressed: () async {
              final isFav = await _dbService.toggleFavorite(track);
              _loadAllSections();
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
        ],
      ),
    );
  }

  Widget _buildFallbackThumbnail({
    String? title,
    String? artist,
    double size = double.infinity,
  }) {
    final int charCode = (title != null && title.isNotEmpty) ? title.codeUnitAt(0) : 65;
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
        borderRadius: BorderRadius.circular(size == double.infinity ? 10 : (size * 0.16)),
        border: Border.all(
          color: AppTheme.accentLime.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size == double.infinity ? 80 : (size * 0.75),
            height: size == double.infinity ? 80 : (size * 0.75),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
          ),
          Container(
            width: size == double.infinity ? 50 : (size * 0.5),
            height: size == double.infinity ? 50 : (size * 0.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.8,
              ),
            ),
          ),
          Icon(
            Icons.music_note_rounded,
            color: AppTheme.accentLime,
            size: size == double.infinity ? 36 : (size * 0.45),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.12 + (0.18 * (0.5 - (_shimmerController.value - 0.5).abs()));
        return Container(
          width: 130,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight.withValues(alpha: opacity * 3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: opacity * 3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 65,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: opacity * 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerSongTile() {
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
