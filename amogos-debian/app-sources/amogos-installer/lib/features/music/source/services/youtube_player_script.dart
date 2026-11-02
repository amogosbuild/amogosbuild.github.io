// Adapted from the user's AmogOS Music project.
import 'dart:convert';

import 'signature_decoder.dart';
import 'web_client.dart';

class YoutubePlayerScript {
  YoutubePlayerScript(this.web);
  final WebClient web;
  String? _source;
  DateTime? _expires;
  Future<void>? _loading;
  int? get timestamp => _source == null
      ? null
      : int.tryParse(
          RegExp(r'signatureTimestamp\s*[:=]\s*(\d+)')
                  .firstMatch(_source!)
                  ?.group(1) ??
              '',
        );

  Future<void> load(String videoId) async {
    if (_source != null && (_expires?.isAfter(DateTime.now()) ?? false)) {
      return;
    }
    final pending = _loading;
    if (pending != null) {
      await pending;
      return;
    }
    final task = _fetch(videoId);
    _loading = task;
    try {
      await task;
    } finally {
      _loading = null;
    }
  }

  Future<void> _fetch(String videoId) async {
    final html = await web.text(
      Uri.https('www.youtube.com', '/embed/$videoId', {'hl': 'en'}),
      headers: {'Cookie': 'SOCS=CAI'},
    );
    final match = RegExp(r'"(?:jsUrl|PLAYER_JS_URL|js)"\s*:\s*"([^"]+)"')
        .allMatches(html)
        .where((m) => m.group(1)!.contains('/s/player/'))
        .toList();
    if (match.isEmpty) {
      throw const SourceException('The YouTube player script is unavailable.');
    }
    final path = jsonDecode('"${match.first.group(1)}"') as String;
    final uri = Uri.parse('https://www.youtube.com').resolve(path);
    if (uri.scheme != 'https' ||
        !['www.youtube.com', 'music.youtube.com'].contains(uri.host)) {
      throw const SourceException('Unexpected YouTube player script.');
    }
    _source = await web.text(uri);
    _expires = DateTime.now().add(const Duration(minutes: 45));
  }

  Future<Uri?> formatUri(Map<String, dynamic> format, String videoId) async {
    if (format['url'] is String) {
      return Uri.tryParse(format['url'] as String);
    }
    final cipher = format['signatureCipher'] ?? format['cipher'];
    if (cipher is! String || cipher.isEmpty) {
      return null;
    }
    final values = Uri.splitQueryString(cipher);
    final url = values['url'];
    if (url == null) {
      return null;
    }
    var signature = values['sig'] ?? values['signature'];
    if (signature == null && values['s'] != null) {
      await load(videoId);
      signature = decodeSignature(_source!, values['s']!);
      if (signature == null) return null;
    }
    if (signature == null) {
      return null;
    }
    final uri = Uri.parse(url);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        values['sp'] ?? 'signature': signature,
      },
    );
  }
}
