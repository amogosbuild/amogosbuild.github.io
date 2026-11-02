// Adapted from the user's AmogOS Music project.
import '../models/track.dart';
import '../models/artist_credit.dart';
import 'innertube.dart';
import 'youtube_artwork.dart';

List<Track> parseRadioTracks(Map<String, dynamic> data) {
  final tracks = <Track>[...parseInnerTubeSongs(data)];
  final seen = tracks.map((t) => t.id).toSet();
  for (final dynamic item in findNodes(data, 'playlistPanelVideoRenderer')) {
    final id = item['videoId'] as String? ?? '';
    if (id.isEmpty || !seen.add('youtube:$id')) continue;
    String text(dynamic field) =>
        field?['simpleText'] as String? ?? runsText(field);
    final byline =
        (item['longBylineText']?['runs'] ??
                item['shortBylineText']?['runs'] ??
                [])
            as List;
    final artists = byline
        .where(
          (dynamic run) =>
              (run['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
                  .toString()
                  .startsWith('UC'),
        )
        .toList();
    final title = text(item['title']);
    final albums = byline
        .where(
          (dynamic run) =>
              (run['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
                  .toString()
                  .startsWith('MPRE'),
        )
        .toList();
    if (title.isEmpty) continue;
    final length = text(item['lengthText']);
    final duration = RegExp(r'^\d+:\d{2}(:\d{2})?$').hasMatch(length)
        ? length.split(':').fold<int>(0, (n, p) => n * 60 + int.parse(p))
        : 0;
    tracks.add(
      Track(
        id: 'youtube:$id',
        sourceId: id,
        title: title,
        source: MusicSource.youtube,
        artist: artists.isEmpty
            ? text(item['shortBylineText'])
            : artists.map((dynamic run) => run['text']).join(', '),
        artistCredits: artists
            .map(
              (dynamic run) => ArtistCredit(
                name: run['text'] as String,
                sourceId:
                    run['navigationEndpoint']['browseEndpoint']['browseId']
                        as String,
              ),
            )
            .toList(),
        albumId: albums.isEmpty
            ? ''
            : albums.first['navigationEndpoint']['browseEndpoint']['browseId']
                  as String,
        album: albums.isEmpty ? '' : albums.first['text'] as String? ?? '',
        artistId: artists.isEmpty
            ? ''
            : artists.first['navigationEndpoint']['browseEndpoint']['browseId']
                  as String,
        artwork: bestYouTubeThumbnail(
          item['thumbnail']?['thumbnails'] as List? ?? [],
        ),
        duration: duration,
        url: 'https://music.youtube.com/watch?v=$id',
      ),
    );
  }
  return tracks;
}
