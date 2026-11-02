// Adapted from the user's AmogOS Music project.
import '../models/track.dart';
import 'web_client.dart';
import 'youtube_player_resolver.dart';
import 'youtube_artwork.dart';
import '../models/artist_credit.dart';
import 'youtube_clients.dart';

Iterable<dynamic> findNodes(dynamic value, String key) sync* {
  if (value is Map) {
    if (value.containsKey(key)) {
      yield value[key];
    }
    for (final child in value.values) {
      yield* findNodes(child, key);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* findNodes(child, key);
    }
  }
}

String runsText(dynamic value) => ((value?['runs'] ?? []) as List)
    .map((dynamic run) => run['text'] ?? '')
    .join();

List<Track> parseInnerTubeSongs(Map<String, dynamic> response) {
  final tracks = <Track>[];
  final seen = <String>{};
  for (final dynamic item in findNodes(
    response,
    'musicResponsiveListItemRenderer',
  )) {
    final endpoints = findNodes(
      item,
      'watchEndpoint',
    ).where((dynamic e) => e['videoId'] != null);
    final dynamic directId =
        item['playlistItemData']?['videoId'] ??
        item['navigationEndpoint']?['watchEndpoint']?['videoId'];
    if (endpoints.isEmpty && directId == null) {
      continue;
    }
    final id = (directId ?? endpoints.first['videoId']) as String;
    if (item['playlistItemData']?['isPlayable'] == false) continue;
    if (!seen.add(id)) {
      continue;
    }
    final columns = (item['flexColumns'] as List? ?? [])
        .map(
          (dynamic c) =>
              c['musicResponsiveListItemFlexColumnRenderer']?['text'],
        )
        .toList();
    if (columns.isEmpty) {
      continue;
    }
    final secondary = columns.length > 1
        ? (columns[1]?['runs'] as List? ?? [])
        : <dynamic>[];
    final artists = secondary.where(
      (dynamic r) =>
          (r['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
              .toString()
              .startsWith('UC'),
    );
    final albums = columns
        .expand((dynamic column) => (column?['runs'] as List? ?? []))
        .where(
          (dynamic run) =>
              (run['navigationEndpoint']?['browseEndpoint']?['browseId'] ?? '')
                  .toString()
                  .startsWith('MPRE'),
        );
    final artist = artists.isNotEmpty
        ? artists.map((dynamic r) => r['text']).join(', ')
        : secondary
              .where(
                (dynamic r) => ![' • ', 'Song', 'Video'].contains(r['text']),
              )
              .map((dynamic r) => r['text'])
              .take(1)
              .join();
    final fixed = (item['fixedColumns'] as List? ?? []).map(
      (dynamic column) => runsText(
        column['musicResponsiveListItemFixedColumnRenderer']?['text'],
      ),
    );
    final durations = [
      ...secondary.map((dynamic r) => r['text'].toString()),
      ...fixed,
    ].where((t) => RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(t));
    final seconds = durations.isEmpty
        ? 0
        : durations.first
              .split(':')
              .fold<int>(0, (total, n) => total * 60 + int.parse(n));
    final thumbs = findNodes(item['thumbnail'], 'thumbnails').toList();
    tracks.add(
      Track(
        id: 'youtube:$id',
        sourceId: id,
        title: runsText(columns.first),
        artist: artist.isEmpty ? 'Unknown artist' : artist,
        album: albums.isEmpty ? '' : albums.first['text'] as String? ?? '',
        albumId: albums.isEmpty
            ? ''
            : albums.first['navigationEndpoint']['browseEndpoint']['browseId']
                  as String,
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
        source: MusicSource.youtube,
        artistId: artists.isEmpty
            ? ''
            : artists.first['navigationEndpoint']['browseEndpoint']['browseId']
                  as String,
        duration: seconds,
        artwork: thumbs.isEmpty || (thumbs.first as List).isEmpty
            ? ''
            : bestYouTubeThumbnail(thumbs.first as List),
        url: 'https://music.youtube.com/watch?v=$id',
      ),
    );
  }
  return tracks;
}

class InnerTube {
  InnerTube(this.web);
  final WebClient web;
  late final YoutubePlayerResolver player = YoutubePlayerResolver(
    web,
    session: _playerSession,
  );
  String? _version, _visitor;
  DateTime? _expires;

  Future<void> _session() async {
    if (_version != null && (_expires?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    final page = await web.text(
      Uri.parse('https://music.youtube.com/'),
      headers: {'Cookie': 'SOCS=CAI'},
    );
    _version = RegExp(r'"INNERTUBE_CLIENT_VERSION"\s*:\s*"([^"]+)"')
        .firstMatch(page)
        ?.group(1);
    _visitor = RegExp(r'"VISITOR_DATA"\s*:\s*"([^"]+)"')
        .firstMatch(page)
        ?.group(1);
    _version ??= '1.20260707.12.00';
    _expires = DateTime.now().add(const Duration(minutes: 30));
  }

  Future<List<Track>> search(String query, {bool videos = false}) async {
    final data = await call('search', {
      'query': query,
      'params': videos
          ? 'EgWKAQIQAWoKEAkQChAFEAMQBA=='
          : 'EgWKAQIIAWoKEAkQChAFEAMQBA==',
    });
    return parseInnerTubeSongs(data).take(30).toList();
  }

  Future<Map<String, dynamic>> call(
    String endpoint,
    Map<String, dynamic> body, {
    YoutubeClientProfile? profile,
  }) async {
    await _session();
    final result = await web.postJson(
      Uri.parse(
        'https://music.youtube.com/youtubei/v1/$endpoint?prettyPrint=false',
      ),
      {
        'context': {
          'client': {
            'clientName': profile?.name ?? 'WEB_REMIX',
            'clientVersion': profile?.version ?? _version,
            if (profile != null) ...profile.device,
            if (profile?.contextAgent == true) 'userAgent': profile!.agent,
            'hl': 'en',
            'gl': 'GB',
            if (_visitor != null) 'visitorData': _visitor,
          },
        },
        ...body,
      },
      headers: {
        'Origin': 'https://music.youtube.com',
        'Referer': 'https://music.youtube.com/',
        'X-Youtube-Client-Name': '67',
        'X-Youtube-Client-Version': _version!,
        if (profile != null) ...profile.headers(),
      },
    );
    final visitor = result['responseContext']?['visitorData'];
    if (visitor is String && visitor.isNotEmpty) {
      _visitor = visitor;
    }
    return result;
  }

  Future<Map<String, String?>> _playerSession() async {
    await _session();
    return {'version': _version, 'visitor': _visitor};
  }

  Future<AudioStream> resolve(Track track, {bool fresh = false}) =>
      player.resolve(track, fresh: fresh);

  void close() => player.close();
}
