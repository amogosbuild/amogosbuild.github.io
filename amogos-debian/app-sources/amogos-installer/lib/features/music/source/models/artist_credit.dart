// Adapted from the user's AmogOS Music project.
class ArtistCredit {
  const ArtistCredit({required this.name, required this.sourceId});
  final String name, sourceId;
  Map<String, dynamic> toJson() => {'name': name, 'sourceId': sourceId};
  factory ArtistCredit.fromJson(Map<String, dynamic> data) => ArtistCredit(
    name: data['name'] as String? ?? '',
    sourceId: data['sourceId'] as String? ?? '',
  );
}
