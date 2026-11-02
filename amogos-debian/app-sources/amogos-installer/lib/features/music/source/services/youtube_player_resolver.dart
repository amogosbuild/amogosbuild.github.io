// Adapted from the user's AmogOS Music project.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';
import 'web_client.dart';
import 'youtube_clients.dart';
import 'youtube_hls.dart';
import 'youtube_player_script.dart';

class YoutubeClientAttempt {
  const YoutubeClientAttempt(this.client, this.status);
  final String client, status;
}

class YoutubePlayerResolver {
  YoutubePlayerResolver(
    this.web, {
    this.session,
    List<YoutubeClientProfile>? clients,
    this.onAttempt,
    this.legacyFallback = true,
  }) : clients = clients ?? youtubePlaybackClients,
       script = YoutubePlayerScript(web),
       hls = YoutubeHls(web);
  final WebClient web;
  final Future<Map<String, String?>> Function()? session;
  final List<YoutubeClientProfile> clients;
  final void Function(YoutubeClientAttempt)? onAttempt;
  final bool legacyFallback;
  final YoutubePlayerScript script;
  final YoutubeHls hls;
  final YoutubeExplode _legacy = YoutubeExplode();
  final _cache = <String, AudioStream>{};
  final _pending = <String, Future<AudioStream>>{};
  String? _preferred;

  Future<AudioStream> resolve(Track track, {bool fresh = false}) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(track.sourceId)) {
      throw const SourceException(
        'This YouTube track has an invalid identifier.',
      );
    }
    final cached = _cache[track.id];
    if (!fresh && cached != null && !cached.expiresSoon) {
      return cached;
    }
    final key = '${track.id}:${fresh ? 'fresh' : 'normal'}';
    final pending = _pending[key];
    if (pending != null) {
      return pending;
    }
    final request = _resolve(track);
    _pending[key] = request;
    try {
      final audio = await request;
      final saved = AudioStream(
        audio.uri,
        extension: audio.extension,
        headers: audio.headers,
        hls: audio.hls,
        length: audio.length,
        clientLabel: audio.clientLabel,
        expiresAt:
            expiry(audio.uri) ??
            DateTime.now().add(const Duration(minutes: 10)),
        renew: () => resolve(track, fresh: true),
      );
      if (_cache.length >= 64) {
        _cache.remove(_cache.keys.first);
      }
      _cache[track.id] = saved;
      return saved;
    } finally {
      _pending.remove(key);
    }
  }

  static DateTime? expiry(Uri uri) {
    var timestamp = uri.queryParameters['expire'];
    final segments = uri.pathSegments;
    final index = segments.indexOf('expire');
    if (timestamp == null && index >= 0 && index + 1 < segments.length) {
      timestamp = segments[index + 1];
    }
    final seconds = int.tryParse(timestamp ?? '');
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  void _attempt(YoutubeClientProfile client, String status) =>
      onAttempt?.call(YoutubeClientAttempt(client.label, status));

  Future<Map<String, dynamic>> _player(
    YoutubeClientProfile client,
    Track track,
    Map<String, String?> context,
  ) async {
    if (client.signatureTimestamp) {
      try {
        await script.load(track.sourceId).timeout(const Duration(seconds: 10));
      } catch (_) {}
    }
    final headers = client.headers();
    if (client.name == 'WEB_REMIX' && context['version'] != null) {
      headers['X-Youtube-Client-Version'] = context['version']!;
    }
    final body = client.body(
      track.sourceId,
      visitor: context['visitor'],
      timestamp: script.timestamp,
      webRemixVersion: context['version'],
    );
    for (var retry = 0; retry < 2; retry++) {
      try {
        return await web
            .postJson(
              Uri.https(client.host, '/youtubei/v1/player', {
                'prettyPrint': 'false',
              }),
              body,
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
      } on SourceException catch (error) {
        if (retry == 1 ||
            !(error.statusCode == 429 || (error.statusCode ?? 0) >= 500)) {
          rethrow;
        }
      } on TimeoutException {
        if (retry == 1) {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    throw const SourceException('YouTube is temporarily unavailable.');
  }

  Future<AudioStream?> _validate(AudioStream audio) async {
    if (audio.uri.scheme != 'https' ||
        !(audio.uri.host == 'googlevideo.com' ||
            audio.uri.host.endsWith('.googlevideo.com'))) {
      return null;
    }
    var length = audio.length;
    final positions = <int>[0];
    for (var i = 0; i < positions.length; i++) {
      final position = positions[i];
      final request = http.Request('GET', audio.uri)
        ..headers.addAll(audio.headers)
        ..headers['Range'] = 'bytes=$position-$position';
      final response = await web.client
          .send(request)
          .timeout(const Duration(seconds: 10));
      final contentRange = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$')
          .firstMatch(response.headers['content-range'] ?? '');
      final valid =
          response.statusCode == 206 &&
          response.contentLength == 1 &&
          contentRange != null &&
          int.parse(contentRange.group(1)!) == position &&
          int.parse(contentRange.group(2)!) == position;
      await response.stream.listen((_) {}).cancel();
      if (!valid) {
        return null;
      }
      final total = int.parse(contentRange.group(3)!);
      if (length != null && length != total) {
        return null;
      }
      length = total;
      if (i == 0 && length > 1) {
        if (length > 1048576) {
          positions.add(length ~/ 2);
        }
        positions.add(length - 1);
      }
    }
    return AudioStream(
      audio.uri,
      extension: audio.extension,
      headers: audio.headers,
      length: length,
      clientLabel: audio.clientLabel,
    );
  }

  Future<AudioStream> _resolve(Track track) async {
    var context = <String, String?>{};
    try {
      context = await session?.call() ?? {};
    } catch (_) {}
    final ordered = [...clients]
      ..sort(
        (a, b) => a.key == _preferred
            ? -1
            : b.key == _preferred
            ? 1
            : clients.indexOf(a).compareTo(clients.indexOf(b)),
      );
    final timer = Stopwatch()..start();
    for (final client in ordered) {
      if (timer.elapsed > const Duration(seconds: 90)) {
        break;
      }
      try {
        final response = await _player(client, track, context);
        final data = response['streamingData'] as Map<String, dynamic>? ?? {};
        final formats =
            (data['adaptiveFormats'] as List? ?? [])
                .where(
                  (dynamic f) =>
                      f is Map &&
                      f['mimeType'].toString().startsWith('audio/mp4') &&
                      f['drmFamilies'] == null,
                )
                .toList()
              ..sort(
                (dynamic a, dynamic b) => (b['bitrate'] as num? ?? 0).compareTo(
                  a['bitrate'] as num? ?? 0,
                ),
              );
        for (final dynamic format in formats.take(4)) {
          try {
            final uri = await script.formatUri(
              format as Map<String, dynamic>,
              track.sourceId,
            );
            if (uri == null) {
              continue;
            }
            final length = int.tryParse(
              (format['contentLength'] ?? uri.queryParameters['clen'] ?? '')
                  .toString(),
            );
            for (final headers in [
              <String, String>{},
              {'User-Agent': client.agent},
            ]) {
              final audio = await _validate(
                AudioStream(
                  uri,
                  extension: 'm4a',
                  length: length,
                  headers: headers,
                  clientLabel: client.label,
                ),
              );
              if (audio != null) {
                _preferred = client.key;
                _attempt(client, 'PLAYABLE');
                return audio;
              }
            }
          } catch (_) {
            continue;
          }
        }
        final manifest = data['hlsManifestUrl'];
        if (manifest is String) {
          try {
            final audio = await hls.resolve(Uri.parse(manifest));
            if (audio != null) {
              _preferred = client.key;
              _attempt(client, 'PLAYABLE_HLS');
              return AudioStream(
                audio.uri,
                extension: audio.extension,
                hls: true,
                headers: audio.headers,
                clientLabel: client.label,
              );
            }
          } catch (_) {}
        }
        final status =
            response['playabilityStatus']?['status'] as String? ?? 'ERROR';
        final described = formats.any(
          (dynamic format) =>
              format['url'] != null ||
              format['signatureCipher'] != null ||
              format['cipher'] != null,
        );
        _attempt(
          client,
          status != 'OK'
              ? status
              : data['serverAbrStreamingUrl'] != null && !described
              ? 'SABR_ONLY'
              : formats.isNotEmpty
              ? 'MEDIA_REJECTED'
              : 'NO_AUDIO',
        );
      } catch (_) {
        _attempt(client, 'REQUEST_FAILED');
      }
    }
    if (legacyFallback) {
      try {
        final manifest = await _legacy.videos.streamsClient
            .getManifest(track.sourceId)
            .timeout(const Duration(seconds: 20));
        final formats =
            manifest.audioOnly.where((s) => s.container.name == 'mp4').toList()
              ..sort(
                (a, b) =>
                    b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
              );
        for (final stream in formats.take(3)) {
          final audio = await _validate(
            AudioStream(
              stream.url,
              extension: 'm4a',
              length: stream.size.totalBytes,
              clientLabel: 'Legacy decoder',
            ),
          );
          if (audio != null) {
            return audio;
          }
        }
      } catch (_) {}
    }
    throw const SourceException(
      'YouTube could not provide complete audio for this track. It may require sign-in or be unavailable in your region.',
    );
  }

  void close() {
    _cache.clear();
    _legacy.close();
  }
}
