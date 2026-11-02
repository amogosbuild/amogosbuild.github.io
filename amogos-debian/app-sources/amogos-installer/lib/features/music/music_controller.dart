// Persistent InnerTube playback survives wizard navigation and pauses independently of installation.
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'source/models/track.dart';
import 'source/services/innertube.dart';
import 'source/services/web_client.dart';
import 'source/services/youtube_queue.dart';

class MusicController extends ChangeNotifier {
  MusicController() {
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => _poll());
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'control') return;
      switch (call.arguments) {
        case 'next':
          await next();
        case 'previous':
          await previous();
        case 'pause':
          if (playing) await toggle();
        case 'play':
          if (!playing) await toggle();
        case 'stop':
          await setEnabled(false);
      }
    });
  }
  static const playlistId = 'PLtDV_xTX8E0uQaRGRL4B3Sp1GCKNCHH3J';
  final _web = WebClient();
  late final inner = InnerTube(_web);
  MethodChannel get _channel => MethodChannel(
    Platform.isWindows ? 'amogos.windows_audio' : 'amogos.audio',
  );
  final List<Track> queue = [];
  List<Track> results = [];
  bool enabled = true,
      playing = false,
      loading = false,
      searching = false,
      shuffle = false;
  int index = -1, repeat = 1, _revision = 0;
  double volume = .45;
  Duration position = Duration.zero, duration = Duration.zero;
  String? error;
  bool _polling = false, _disposed = false;
  Timer? _timer;
  Track? get current =>
      index >= 0 && index < queue.length ? queue[index] : null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadInstallerPlaylist() => loadPlaylist(playlistId);

  Future<void> loadPlaylist(String input) async {
    final uri = Uri.tryParse(input);
    final id =
        uri?.queryParameters['list'] ?? input.replaceFirst(RegExp(r'^VL'), '');
    if (!RegExp(r'^[A-Za-z0-9_-]{10,120}$').hasMatch(id)) {
      error = 'Paste a valid YouTube playlist link.';
      _notify();
      return;
    }
    loading = true;
    error = null;
    _notify();
    try {
      final data = await inner.call('browse', {'browseId': 'VL$id'});
      var tracks = parseInnerTubeSongs(data);
      if (tracks.isEmpty) {
        tracks = parseRadioTracks(
          await inner.call('next', {'playlistId': id, 'isAudioOnly': true}),
        );
      }
      if (tracks.isEmpty) {
        throw const SourceException(
          'The playlist has no available songs. You can search for a song instead.',
        );
      }
      queue
        ..clear()
        ..addAll(tracks);
      index = -1;
      playing = false;
      position = Duration.zero;
    } catch (e) {
      error =
          'Music is unavailable right now. Check your connection and try again. $e';
    }
    loading = false;
    _notify();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    searching = true;
    error = null;
    _notify();
    try {
      results = await inner.search(query.trim());
    } catch (_) {
      error =
          'Search could not connect. Installation can continue without music.';
    }
    searching = false;
    _notify();
  }

  void add(Track track) {
    if (!queue.any((t) => t.id == track.id)) queue.add(track);
    _notify();
  }

  Future<void> playAt(int value) async {
    if (value < 0 || value >= queue.length) return;
    enabled = true;
    index = value;
    loading = true;
    error = null;
    playing = false;
    position = Duration.zero;
    duration = Duration(seconds: queue[value].duration);
    final revision = ++_revision;
    _notify();
    try {
      final audio = await inner.resolve(queue[value]);
      if (revision != _revision || !enabled || _disposed) return;
      await _channel.invokeMethod('load', {
        'uri': audio.uri.toString(),
        'headers': audio.headers,
      });
      if (Platform.isWindows) {
        await _channel.invokeMethod('metadata', {
          'title': queue[value].title,
          'artist': queue[value].artist,
          'album': 'AmogOS Installer Music',
        });
      }
      await _channel.invokeMethod('volume', volume);
      await _channel.invokeMethod('play');
      if (revision == _revision) playing = true;
    } catch (e) {
      if (revision == _revision) {
        error = e is MissingPluginException
            ? 'Audio playback is available in the desktop app.'
            : 'This song could not play. Try another track. $e';
      }
    } finally {
      if (revision == _revision) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> toggle() async {
    if (!enabled) {
      enabled = true;
      _notify();
    }
    if (current == null) {
      if (queue.isEmpty) await loadInstallerPlaylist();
      if (queue.isNotEmpty) await playAt(0);
      return;
    }
    try {
      await _channel.invokeMethod(playing ? 'pause' : 'play');
      playing = !playing;
    } catch (_) {
      error = 'Audio could not be started. Try selecting the track again.';
    }
    _notify();
  }

  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) {
      _revision++;
      loading = false;
      playing = false;
      try {
        await _channel.invokeMethod('pause');
      } catch (_) {}
    }
    _notify();
  }

  Future<void> next({bool automatic = false}) async {
    if (queue.isEmpty || !enabled) return;
    if (automatic && repeat == 2) {
      await playAt(index);
      return;
    }
    if (automatic && index == queue.length - 1 && repeat == 0 && !shuffle) {
      playing = false;
      _notify();
      return;
    }
    final nextIndex = shuffle && queue.length > 1
        ? (index + 1 + Random().nextInt(queue.length - 1)) % queue.length
        : (index + 1) % queue.length;
    await playAt(nextIndex);
  }

  Future<void> previous() async {
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (queue.isNotEmpty) {
      await playAt((index - 1 + queue.length) % queue.length);
    }
  }

  Future<void> seek(Duration value) async {
    try {
      await _channel.invokeMethod('seek', value.inMilliseconds);
      position = value;
    } catch (_) {}
    _notify();
  }

  Future<void> setVolume(double value) async {
    volume = value;
    try {
      await _channel.invokeMethod('volume', value);
    } catch (_) {}
    _notify();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _notify();
  }

  void cycleRepeat() {
    repeat = (repeat + 1) % 3;
    _notify();
  }

  void removeAt(int at) {
    if (at == index) return;
    queue.removeAt(at);
    if (at < index) index--;
    _notify();
  }

  Future<void> _poll() async {
    if (_disposed || _polling || current == null || loading || !enabled) return;
    _polling = true;
    try {
      final state = await _channel.invokeMapMethod<String, dynamic>('state');
      if (state == null || _disposed) return;
      position = Duration(
        milliseconds: (state['position'] as num? ?? 0).toInt(),
      );
      final length = (state['duration'] as num? ?? 0).toInt();
      if (length > 0) duration = Duration(milliseconds: length);
      if (state['error'] is String) {
        error = state['error'];
        playing = false;
      }
      if (state['completed'] == true) {
        await next(automatic: true);
      }
      _notify();
    } catch (_) {
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    _channel.invokeMethod('dispose').catchError((_) => null);
    inner.close();
    _web.close();
    super.dispose();
  }
}
