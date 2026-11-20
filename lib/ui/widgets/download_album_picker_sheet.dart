import 'package:flutter/material.dart';
import '../../models/download_album.dart';
import '../../models/track.dart';
import '../../services/database_service.dart';
import '../app_theme.dart';

class DownloadAlbumPickerSheet extends StatefulWidget {
  final Track track;

  const DownloadAlbumPickerSheet({super.key, required this.track});

  static Future<String?> show(BuildContext context, Track track) {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DownloadAlbumPickerSheet(track: track),
    );
  }

  @override
  State<DownloadAlbumPickerSheet> createState() =>
      _DownloadAlbumPickerSheetState();
}

class _DownloadAlbumPickerSheetState extends State<DownloadAlbumPickerSheet> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _newAlbumController = TextEditingController();

  List<DownloadAlbum> _albums = [];
  bool _isLoading = true;
  bool _isCreatingAlbum = false;
  bool _isSavingNewAlbum = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  @override
  void dispose() {
    _newAlbumController.dispose();
    super.dispose();
  }

  Future<void> _loadAlbums() async {
    final albums = await _dbService.getDownloadAlbums();
    if (mounted) {
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
    }
  }

  Future<void> _createAndSelectAlbum() async {
    final name = _newAlbumController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _isSavingNewAlbum = true;
    });

    final newAlbum = await _dbService.createDownloadAlbum(name);
    if (mounted) {
      Navigator.pop(context, newAlbum.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.track.thumbnailUrl != null
                      ? Image.network(
                          widget.track.thumbnailUrl!,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildFallbackCover(),
                        )
                      : _buildFallbackCover(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save to Album',
                        style: TextStyle(
                          color: AppTheme.accentLime,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.track.artist,
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
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(color: AppTheme.divider, height: 1),

          // Action: Create New Album
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _isCreatingAlbum
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentLime.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _newAlbumController,
                            autofocus: true,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Enter album name (e.g. Chill, Workout)...',
                              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) => _createAndSelectAlbum(),
                          ),
                        ),
                        if (_isSavingNewAlbum)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentLime,
                            ),
                          )
                        else ...[
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isCreatingAlbum = false;
                                _newAlbumController.clear();
                              });
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _createAndSelectAlbum,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentLime,
                              foregroundColor: AppTheme.background,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : InkWell(
                    onTap: () {
                      setState(() {
                        _isCreatingAlbum = true;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add_circle_outline_rounded, color: AppTheme.accentLime, size: 20),
                          SizedBox(width: 10),
                          Text(
                            '+ Create New Album',
                            style: TextStyle(
                              color: AppTheme.accentLime,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Options List
          Flexible(
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: AppTheme.accentLime, strokeWidth: 2),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      // General Downloads option
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.download_done_rounded,
                            color: AppTheme.accentLime,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'General Downloads',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Saved in master offline library',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        onTap: () => Navigator.pop(context, 'general'),
                      ),

                      if (_albums.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Text(
                            'YOUR ALBUMS',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        ..._albums.map(
                          (album) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        album.coverUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.album_rounded,
                                          color: AppTheme.accentLime,
                                          size: 20,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.album_rounded,
                                      color: AppTheme.accentLime,
                                      size: 20,
                                    ),
                            ),
                            title: Text(
                              album.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${album.trackCount} ${album.trackCount == 1 ? 'song' : 'songs'}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: AppTheme.textSecondary,
                              size: 14,
                            ),
                            onTap: () => Navigator.pop(context, album.id),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCover() {
    return Container(
      width: 44,
      height: 44,
      color: AppTheme.surface,
      child: const Icon(Icons.music_note, color: AppTheme.textSecondary, size: 20),
    );
  }
}
