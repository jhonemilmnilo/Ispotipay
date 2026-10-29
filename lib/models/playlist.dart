class Playlist {
  final String id;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String searchQuery;

  const Playlist({
    required this.id,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    required this.searchQuery,
  });
}
