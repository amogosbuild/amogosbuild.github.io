// Linux uses the fixed helper and Windows offers a clearly labelled non-destructive preview.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/store_models.dart';

class StoreService {
  StoreService({required this.preview});
  final bool preview;
  List<StorePackage> samples = [];
  static const privileged = {
    'apt-plan',
    'apt-apply',
    'refresh',
    'flatpak-plan',
    'flatpak-apply',
    'flatpak-source',
  };
  Future<void> initialize() async {
    if (samples.isNotEmpty) return;
    if (preview) {
      final raw = jsonDecode(
        await rootBundle.loadString('assets/catalog/preview.json'),
      ) as Map;
      samples = [
        for (final item in raw['items'])
          StorePackage(Map<String, dynamic>.from(item)),
      ];
    }
  }

  Process? _browseProcess;
  int _browseGeneration = 0;
  Future<Process> _start(String action, Map<String, dynamic> body) async {
    final browsing = action == 'catalog' || action == 'installed';
    final generation = browsing ? ++_browseGeneration : 0;
    if (browsing) _browseProcess?.kill();
    final process =
        await (privileged.contains(action) &&
                !({'flatpak-plan', 'flatpak-apply'}.contains(action) &&
                    body['scope'] == 'user')
            ? Process.start('pkexec', [
                '/usr/libexec/amogos-store-helper',
                action,
              ])
            : Process.start('/usr/bin/python3', [
                '-I',
                '/usr/lib/amogos-store/backend/cli.py',
                action,
              ]));
    if (browsing) {
      if (generation != _browseGeneration) {
        process.kill();
      } else {
        _browseProcess = process;
      }
    }
    return process;
  }

  Future<String> _errorTail(Stream<List<int>> stream) async {
    var tail = '';
    await for (final text in stream.transform(utf8.decoder)) {
      tail += text;
      if (tail.length > 65536) tail = tail.substring(tail.length - 65536);
    }
    return tail;
  }

  Future<Map<String, dynamic>> request(
    String action, [
    Map<String, dynamic> body = const {},
  ]) async {
    if (preview) {
      if (action == 'open-url') {
        final url = Uri.tryParse(body['url']?.toString() ?? '');
        if (url?.scheme == 'https' && url!.host.isNotEmpty) {
          await Process.start('explorer.exe', [url.toString()]);
        }
      }
      return _preview(action, body);
    }
    final process = await _start(action, body);
    process.stdin.write(jsonEncode(body));
    await process.stdin.close();
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = _errorTail(process.stderr);
    final values = await Future.wait([output, errors]);
    final code = await process.exitCode;
    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(values[0]));
    } on FormatException {
      data = null;
    }
    if (code != 0 || data == null || data['error'] == true) {
      throw StateError(
        data?['message'] ??
            (values[1].trim().isEmpty
                ? 'Authentication was cancelled or the source is unavailable.'
                : values[1].trim()),
      );
    }
    return data;
  }

  Stream<Map<String, dynamic>> execute(
    String action,
    Map<String, dynamic> body,
  ) async* {
    if (preview) {
      for (var i = 0; i <= 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        yield {
          'message': i == 20
              ? 'Preview finished. No packages were changed.'
              : 'Previewing package installation…',
          'progress': i / 20,
          'done': i == 20,
        };
      }
      return;
    }
    final process = await _start(action, body);
    process.stdin.write(jsonEncode(body));
    await process.stdin.close();
    final errors = _errorTail(process.stderr);
    var done = false, failed = false;
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final data = Map<String, dynamic>.from(jsonDecode(line));
      done |= data['done'] == true;
      failed |= data['error'] == true;
      yield data;
    }
    final code = await process.exitCode;
    final error = await errors;
    if (!done && !failed) {
      throw StateError(
        error.isEmpty
            ? 'The operation ended before completion (exit $code).'
            : error.trim(),
      );
    }
  }

  Map<String, dynamic> _preview(String action, Map<String, dynamic> body) {
    if (action == 'sources') {
      final keys = <String>{
        for (final p in samples.where((p) => p.source == 'deb'))
          ...List<String>.from(p.data['repositories'] ?? [p.repo]),
      };
      return {
        'name': Platform.environment['USERNAME'] ?? 'Bob',
        'repositories': [
          for (final key in keys)
            {
              'id': key,
              'name': key.replaceAll('|', ' · '),
              'source': 'deb',
              'trusted': true,
              'enabled': true,
            },
        ],
        'flatpak': [
          {
            'id': 'flathub',
            'name': 'Flathub',
            'enabled': true,
            'url': 'https://dl.flathub.org/repo/',
          },
        ],
      };
    }
    if (action == 'catalog' || action == 'installed') {
      final query = (body['query'] as String? ?? '').toLowerCase();
      final source = body['source'] ?? 'all', category = body['category'] ?? '';
      final items = samples
          .where(
            (p) =>
                (source == 'all' || p.source == source) &&
                (action != 'installed' || p.installed) &&
                (query.isEmpty ||
                    '${p.name} ${p.summary}'.toLowerCase().contains(query)) &&
                (category == '' || p.categories.contains(category)) &&
                ((body['repo'] ?? '') == '' ||
                    p.repo == body['repo'] ||
                    List<String>.from(p.data['repositories'] ?? [])
                        .contains(body['repo'])),
          )
          .toList();
      return {
        'items': [for (final p in items) p.data],
        'warnings': [],
        'totals': {'preview': items.length},
        'page': 0,
      };
    }
    if (action == 'details') {
      return samples
          .firstWhere((p) => p.id == body['id'] && p.source == body['source'])
          .data;
    }
    if (action == 'alternatives') {
      final current = samples.firstWhere(
        (p) => p.id == body['id'] && p.source == body['source'],
      );
      final alias = current.data['alias'] ?? current.iconId;
      return {
        'items': [
          for (final p in samples.where(
            (p) => (p.data['alias'] ?? p.iconId) == alias,
          ))
            p.data,
        ],
        'warnings': [],
      };
    }
    if (action == 'updates') {
      return {
        'system': {
          'items': [
            {
              'id': 'linux-image-amd64',
              'action': 'update',
              'fromVersion': 'Included kernel',
              'version': 'Available kernel',
            },
            {
              'id': 'ca-certificates',
              'action': 'update',
              'fromVersion': 'Included certificate bundle',
              'version': 'Available certificate bundle',
            },
          ],
          'downloadBytes': 146800640,
          'spaceBytes': 325058560,
          'rebootRequired': false,
        },
        'flatpak': [
          {
            'id': 'org.videolan.VLC',
            'name': 'VLC',
            'fromVersion': '3.0.20',
            'version': '3.0.21',
            'scope': 'system',
            'reference': 'app/org.videolan.VLC/x86_64/stable',
          },
        ],
        'appimage': [
          {
            'id': '1231861',
            'name': 'VLC AppImage',
            'fromVersion': '3.0.11',
            'version': '3.0.21',
            'download': 1,
            'size': 123000000,
          },
        ],
      };
    }
    if (action.endsWith('-plan')) {
      return {
        'source':
            body['source'] ?? (action.startsWith('apt') ? 'deb' : 'flatpak'),
        'id': body['id'],
        'operation': body['operation'],
        'token': 'preview-token',
        'fingerprint': 'preview',
        'commit': 'preview',
        'reference': body['reference'],
        'commits': {
          for (final v in body['packages'] ?? []) v.toString(): 'preview',
        },
        'summary': body['operation'] == 'upgrade-system'
            ? 'Update AmogOS 2 Pro'
            : '${body['operation']} ${body['id']}',
        'changes': [
          {
            'id': body['id'] ?? 'System packages',
            'action': body['operation'],
            'version': 'Preview',
          },
        ],
        'downloadBytes': 0,
        'spaceBytes': 0,
      };
    }
    return {};
  }
}
