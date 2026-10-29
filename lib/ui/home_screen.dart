import 'dart:async';
import 'package:flutter/material.dart';
import '../models/track.dart';
import '../services/database_service.dart';
import '../services/music_explore_service.dart';
import 'app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  final MusicExploreService _exploreService = MusicExploreService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounceTimer;

  List<Track> _topMusic = [];
  List<Track> _recents = [];
  List<Track> _favorites = [];
  List<Track> _mostPlayed = [];
  List<Track> _allMusic = [];

  bool _isLoadingTop = true;
  bool _isLoadingAll = true;
  bool _isSearching = false;
  List<Track> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadAllSections();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _exploreService.dispose();
    super.dispose();
  }

  Future<void> _loadAllSections() async {
    // 1. Load local SQLite data
    final recents = await _dbService.getRecents(limit: 15);
    final favs = await _dbService.getFavorites(limit: 25);
    final mostPlayed = await _dbService.getMostPlayed(limit: 10);

    if (mounted) {
      setState(() {
        _recents = recents;
        _favorites = favs;
        _mostPlayed = mostPlayed;
      });
    }

    // 2. Load online Top & All Music
    _fetchOnlineMusic();
  }

  Future<void> _fetchOnlineMusic() async {
    final top = await _exploreService.getTopMusic(limit: 15);
    final all = await _exploreService.searchTracks('Popular Music Hits');

    if (mounted) {
      setState(() {
        _topMusic = top;
        _allMusic = all;
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
      });
      return;
    }

    // 400ms Debounce rule
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final results = await _exploreService.searchTracks(query);
      if (mounted) {
        setState(() {
          _isSearching = true;
          _searchResults = results;
        });
      }
    });
  }

  void _playTrack(Track track) async {
    await _dbService.recordPlay(track);
    _loadAllSections();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.surfaceLight,
          content: Text(
            'Playing: ${track.title}',
            style: const TextStyle(color: AppTheme.accentLime),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
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
                                text: 'ispoti',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'pay',
                                style: TextStyle(
                                  color: AppTheme.accentLime,
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: const Text(
                            'FREE & NO ADS',
                            style: TextStyle(
                              color: AppTheme.accentLime,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
              // Search Results View
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Search Results (${_searchResults.length})',
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
            ] else ...[
              // 2. Top Music Section (Horizontal Carousel)
              SliverToBoxAdapter(
                child: _buildSectionHeader('Top Music', icon: Icons.trending_up),
              ),
              SliverToBoxAdapter(
                child: _buildHorizontalCarousel(
                  tracks: _topMusic,
                  isLoading: _isLoadingTop,
                  cardWidth: 150,
                  cardHeight: 200,
                ),
              ),

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
                    cardHeight: 180,
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
                    cardHeight: 180,
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
                    cardWidth: 140,
                    cardHeight: 180,
                    showPlayCount: true,
                  ),
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
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: AppTheme.accentLime),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _allMusic[index];
                          return _buildSongListTile(track);
                        },
                        childCount: _allMusic.length,
                      ),
                    ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search songs, artists, albums...',
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
            onTap: () => _playTrack(track),
            child: Container(
              width: cardWidth,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: track.thumbnailUrl != null
                          ? Image.network(
                              track.thumbnailUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => _buildFallbackThumbnail(),
                            )
                          : _buildFallbackThumbnail(),
                    ),
                  ),
                  const SizedBox(height: 8),
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

  Widget _buildSongListTile(Track track) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: track.thumbnailUrl != null
              ? Image.network(
                  track.thumbnailUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildFallbackThumbnail(size: 48),
                )
              : _buildFallbackThumbnail(size: 48),
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
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: AppTheme.accentLime, size: 28),
              onPressed: () => _playTrack(track),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail({double size = double.infinity}) {
    return Container(
      width: size,
      height: size,
      color: AppTheme.surfaceLight,
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary),
    );
  }
}
