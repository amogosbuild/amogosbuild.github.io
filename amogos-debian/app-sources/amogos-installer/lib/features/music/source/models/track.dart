// Adapted from the user's AmogOS Music project.
import 'artist_credit.dart';

enum MusicSource { youtube, soundcloud, local, jiosaavn, kugou }

extension MusicSourceLabel on MusicSource {
  String get label => [
    'YouTube Music',
    'SoundCloud',
    'Local files',
    'JioSaavn',
    'KuGou',
  ][index];
  String get key =>
      ['youtube', 'soundcloud', 'local', 'jiosaavn', 'kugou'][index];
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.source,
    required this.sourceId,
    this.artwork = '',
    this.duration = 0,
    this.album = '',
    this.albumId = '',
    this.artistCredits = const [],
    this.codec = '',
    this.metadataVersion = 0,
    this.url = '',
    this.localPath,
    this.fileId = '',
    this.extension = 'mp3',
    this.liked = false,
    this.downloaded = false,
    this.updated = 0,
    this.artistId = '',
  });

  final String id,
      title,
      artist,
      sourceId,
      artwork,
      url,
      fileId,
      extension,
      artistId,
      album,
      albumId,
      codec;
  final MusicSource source;
  final List<ArtistCredit> artistCredits;
  final int duration, updated, metadataVersion;
  final String? localPath;
  final bool liked, downloaded;

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    source: MusicSource.values.firstWhere(
      (s) => s.key == json['source'],
      orElse: () => MusicSource.local,
    ),
    sourceId: json['sourceId'] as String? ?? '',
    artwork: json['artwork'] as String? ?? '',
    duration: (json['duration'] as num?)?.toInt() ?? 0,
    album: json['album'] as String? ?? '',
    albumId: json['albumId'] as String? ?? '',
    artistCredits: (json['artistCredits'] as List? ?? [])
        .map(
          (dynamic credit) =>
              ArtistCredit.fromJson(Map<String, dynamic>.from(credit as Map)),
        )
        .toList(),
    codec: json['codec'] as String? ?? '',
    metadataVersion: json['metadataVersion'] as int? ?? 0,
    url: json['url'] as String? ?? '',
    localPath: json['localPath'] as String?,
    fileId: json['fileId'] as String? ?? '',
    extension: json['extension'] as String? ?? 'mp3',
    liked: json['liked'] == true,
    downloaded: json['downloaded'] == true,
    updated: (json['updated'] as num?)?.toInt() ?? 0,
    artistId: json['artistId'] as String? ?? '',
  );

  Map<String, dynamic> toJson({bool portable = false}) => {
    'id': id,
    'title': title,
    'artist': artist,
    'source': source.key,
    'sourceId': sourceId,
    'artwork': portable && Uri.tryParse(artwork)?.scheme == 'file'
        ? ''
        : artwork,
    'duration': duration,
    'album': album,
    'albumId': albumId,
    'artistCredits': artistCredits.map((credit) => credit.toJson()).toList(),
    'codec': codec,
    'metadataVersion': portable && source == MusicSource.local
        ? 0
        : metadataVersion,
    'url': url,
    if (!portable) 'localPath': localPath,
    'fileId': fileId,
    'extension': extension,
    'liked': liked,
    'downloaded': downloaded,
    'updated': updated,
    'artistId': artistId,
  };

  Track copyWith({
    String? localPath,
    String? title,
    String? artist,
    String? artwork,
    String? album,
    String? albumId,
    List<ArtistCredit>? artistCredits,
    String? artistId,
    String? codec,
    int? duration,
    int? metadataVersion,
    String? fileId,
    String? extension,
    bool? liked,
    bool? downloaded,
    int? updated,
  }) => Track(
    id: id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    source: source,
    sourceId: sourceId,
    artwork: artwork ?? this.artwork,
    duration: duration ?? this.duration,
    album: album ?? this.album,
    albumId: albumId ?? this.albumId,
    artistCredits: artistCredits ?? this.artistCredits,
    codec: codec ?? this.codec,
    metadataVersion: metadataVersion ?? this.metadataVersion,
    url: url,
    localPath: localPath ?? this.localPath,
    fileId: fileId ?? this.fileId,
    extension: extension ?? this.extension,
    liked: liked ?? this.liked,
    downloaded: downloaded ?? this.downloaded,
    updated: updated ?? this.updated,
    artistId: artistId ?? this.artistId,
  );
}

class AudioStream {
  const AudioStream(
    this.uri, {
    required this.extension,
    this.headers = const {},
    this.hls = false,
    this.length,
    this.clientLabel = '',
    this.expiresAt,
    this.renew,
  });
  final Uri uri;
  final String extension;
  final Map<String, String> headers;
  final bool hls;
  final int? length;
  final String clientLabel;
  final DateTime? expiresAt;
  final Future<AudioStream> Function()? renew;
  bool get expiresSoon =>
      expiresAt != null &&
      expiresAt!.isBefore(DateTime.now().add(const Duration(seconds: 60)));
}
