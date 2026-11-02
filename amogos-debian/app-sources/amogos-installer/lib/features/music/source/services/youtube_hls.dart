// Adapted from the user's AmogOS Music project.
import 'package:http/http.dart' as http;

import '../models/track.dart';
import 'web_client.dart';

class YoutubeHls {
  YoutubeHls(this.web);
  final WebClient web;

  Future<AudioStream?> resolve(Uri uri) async {
    var playlist = await web.text(uri);
    for (
      var depth = 0;
      depth < 3 && playlist.contains('#EXT-X-STREAM-INF');
      depth++
    ) {
      final lines = playlist.split('\n').map((l) => l.trim()).toList();
      final audioGroups = lines.where(
        (l) => l.startsWith('#EXT-X-MEDIA:') && l.contains('TYPE=AUDIO'),
      );
      Uri? selected;
      for (final line in audioGroups) {
        final path = RegExp(r'URI="([^"]+)"').firstMatch(line)?.group(1);
        if (path != null) {
          selected = uri.resolve(path);
          break;
        }
      }
      if (selected == null) {
        final variants = <Map<String, dynamic>>[];
        for (var i = 0; i + 1 < lines.length; i++) {
          if (!lines[i].startsWith('#EXT-X-STREAM-INF:')) {
            continue;
          }
          final codecs =
              RegExp(r'CODECS="([^"]+)"').firstMatch(lines[i])?.group(1) ?? '';
          if (!codecs.contains('mp4a')) {
            continue;
          }
          variants.add({
            'uri': uri.resolve(lines[i + 1]),
            'audio': !RegExp(r'avc|hvc|hev|vp0|av01').hasMatch(codecs),
            'bandwidth':
                int.tryParse(
                  RegExp(r'(?:^|[:,])BANDWIDTH=(\d+)')
                          .firstMatch(lines[i])
                          ?.group(1) ??
                      '',
                ) ??
                999999,
          });
        }
        variants.sort(
          (a, b) => a['audio'] == b['audio']
              ? (a['bandwidth'] as int).compareTo(b['bandwidth'] as int)
              : a['audio'] == true
              ? -1
              : 1,
        );
        if (variants.isEmpty) {
          return null;
        }
        selected = variants.first['uri'] as Uri;
      }
      uri = selected;
      playlist = await web.text(uri);
    }
    if (!playlist.startsWith('#EXTM3U') ||
        !playlist.contains('#EXT-X-ENDLIST') ||
        playlist.contains('#EXT-X-MAP') ||
        playlist.contains('#EXT-X-BYTERANGE') ||
        playlist
            .split('\n')
            .any(
              (l) => l.startsWith('#EXT-X-KEY:') && !l.contains('METHOD=NONE'),
            )) {
      return null;
    }
    final segments = playlist
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();
    if (segments.isEmpty) {
      return null;
    }
    for (final segment in {segments.first, segments.last}) {
      final request = http.Request('GET', uri.resolve(segment))
        ..headers['Range'] = 'bytes=0-31';
      final response = await web.client
          .send(request)
          .timeout(const Duration(seconds: 12));
      await response.stream.listen((_) {}).cancel();
      if (response.statusCode != 200 && response.statusCode != 206) {
        return null;
      }
    }
    return AudioStream(
      uri,
      extension: 'aac',
      hls: true,
      clientLabel: 'YouTube HLS',
    );
  }
}
