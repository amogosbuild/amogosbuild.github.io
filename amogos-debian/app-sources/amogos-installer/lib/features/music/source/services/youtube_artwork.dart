// Adapted from the user's AmogOS Music project.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

bool isYouTubeArtwork(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.endsWith('.ytimg.com') ||
      host.endsWith('.googleusercontent.com') ||
      host.endsWith('.ggpht.com');
}

List<String> youtubeArtworkCandidates(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !isYouTubeArtwork(url)) return [url];
  if (uri.host.endsWith('.ytimg.com') &&
      uri.pathSegments.length >= 3 &&
      ['vi', 'vi_webp'].contains(uri.pathSegments.first)) {
    final extension = uri.pathSegments.first == 'vi_webp' ? 'webp' : 'jpg';
    return {
      for (final name in ['maxresdefault', 'sddefault', 'hqdefault'])
        Uri(
          scheme: uri.scheme,
          host: uri.host,
          path:
              '/${uri.pathSegments[0]}/${uri.pathSegments[1]}/$name.$extension',
        ).toString(),
      url,
    }.toList();
  }
  return {
    url.replaceFirst(RegExp(r'=(?:w\d+|s\d+)[^?]*'), '=s0'),
    url,
  }.toList();
}

String bestYouTubeThumbnail(Iterable<dynamic> thumbnails) {
  final valid = thumbnails
      .where(
        (dynamic value) =>
            value is Map &&
            value['url'] is String &&
            (value['url'] as String).isNotEmpty,
      )
      .toList();
  num area(dynamic value) =>
      (value['width'] as num? ?? 0) * (value['height'] as num? ?? 0);
  valid.sort((dynamic a, dynamic b) => area(b).compareTo(area(a)));
  return valid.isEmpty ? '' : valid.first['url'] as String;
}

final _imageClient = http.Client();
final _imageBytes = <String, Uint8List>{};
final _pendingImages = <String, Future<Uint8List>>{};
int _cachedBytes = 0;
Future<Uint8List> fetchYouTubeArtwork(String url, {http.Client? client}) async {
  if (client != null) return _fetch(url, client);
  final cached = _imageBytes.remove(url);
  if (cached != null) {
    _imageBytes[url] = cached;
    return cached;
  }
  final pending = _pendingImages[url];
  if (pending != null) return pending;
  final task = _fetch(url, _imageClient);
  _pendingImages[url] = task;
  try {
    final bytes = await task;
    if (bytes.length <= 16 * 1024 * 1024) {
      _imageBytes[url] = bytes;
      _cachedBytes += bytes.length;
      while (_cachedBytes > 16 * 1024 * 1024 || _imageBytes.length > 64) {
        _cachedBytes -= _imageBytes.remove(_imageBytes.keys.first)!.length;
      }
    }
    return bytes;
  } finally {
    _pendingImages.remove(url);
  }
}

Future<Uint8List> _fetch(String url, http.Client client) async {
  Object? lastError;
  for (final candidate in youtubeArtworkCandidates(url)) {
    try {
      final response = await client
          .get(Uri.parse(candidate))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty &&
          (response.headers['content-type'] ?? '').startsWith('image/')) {
        return response.bodyBytes;
      }
      lastError = StateError('Artwork returned HTTP ${response.statusCode}');
    } on Object catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? StateError('Artwork is unavailable');
}
