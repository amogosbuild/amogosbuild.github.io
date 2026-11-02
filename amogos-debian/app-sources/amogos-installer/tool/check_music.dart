// Optional live source check exercises the exact installer playlist and audio resolution.
import 'dart:io';

import 'package:amogos_installer/features/music/source/services/innertube.dart';
import 'package:amogos_installer/features/music/source/services/web_client.dart';

Future<void> main() async {
  final web = WebClient();
  final inner = InnerTube(web);
  try {
    final data = await inner.call('browse', {
      'browseId': 'VLPLtDV_xTX8E0uQaRGRL4B3Sp1GCKNCHH3J',
    });
    final tracks = parseInnerTubeSongs(data);
    if (tracks.isEmpty) {
      throw StateError('Installer playlist returned no tracks.');
    }
    stdout.writeln(
      'Playlist: ${tracks.length} tracks, first: ${tracks.first.title}',
    );
    final audio = await inner.resolve(tracks.first);
    stdout.writeln(
      'Validated playable audio: ${audio.clientLabel}, ${audio.extension}, ${audio.uri.host}',
    );
  } finally {
    inner.close();
    web.close();
  }
}
