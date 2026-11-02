// One controller coordinates browsing, source choices, and a serial installation queue.
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/store_models.dart';
import '../services/store_service.dart';

class StoreController extends ChangeNotifier {
  StoreController({required this.service, Random? random})
    : shopperRoll = (random ?? Random.secure()).nextDouble();
  final StoreService service;
  final double shopperRoll;
  StorePage page = StorePage.home;
  final darkTheme = ValueNotifier(true);
  bool get dark => darkTheme.value;
  set dark(bool value) => darkTheme.value = value;
  bool loading = true,
      loadingSources = true,
      queueRunning = false,
      hasMore = false;
  String query = '', source = 'all', repo = '', category = '', name = 'friend';
  String? error;
  List<StorePackage> packages = [], essentials = [];
  StorePackage? featured;
  List<Map<String, dynamic>> repositories = [],
      flatpakSources = [],
      warnings = [];
  Map<String, dynamic> updates = {};
  final Map<String, Set<String>> updateSelections = {};
  final List<StoreJob> queue = [];
  Timer? _searchTimer;
  int _generation = 0, catalogPage = 0;
  bool _disposed = false;
  Future<void>? _initialization;
  bool flatpakAvailable = true;
  bool get flathubEnabled =>
      flatpakSources.any((r) => r['id'] == 'flathub' && r['enabled'] == true);
  int get waitingCount => queue.where((j) => j.pending || j.active).length;
  StoreJob? get currentJob => queue.where((j) => j.active).firstOrNull;
  bool get preview => service.preview;
  String get shopper {
    if (shopperRoll < .02) return 'rareshopper.png';
    if (shopperRoll < .10) return 'semirareshopper.png';
    return dark ? 'shopper-darkmode.png' : 'shopper-lightmode.png';
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    await service.initialize();
    await loadSources();
    await Future.wait([loadCatalog(), loadEssentials()]);
  }

  Future<void> loadSources() async {
    loadingSources = true;
    changed();
    try {
      final data = await service.request('sources');
      name = (data['name'] as String? ?? 'friend').split(' ').first;
      flatpakAvailable = data['flatpakInstalled'] != false;
      repositories = [
        for (final v in data['repositories'] ?? [])
          Map<String, dynamic>.from(v),
      ];
      flatpakSources = [
        for (final v in data['flatpak'] ?? []) Map<String, dynamic>.from(v),
      ];
    } catch (e) {
      error = clean(e);
    }
    loadingSources = false;
    changed();
  }

  Future<void> loadEssentials() async {
    const ids = [
      'org.videolan.VLC',
      'com.valvesoftware.Steam',
      'com.heroicgameslauncher.hgl',
      'com.discordapp.Discord',
      'com.thebrokenrail.MCPIReborn',
    ];
    final result = <StorePackage?>[];
    for (final id in ids) {
      try {
        result.add(
          StorePackage(
            await service.request('details', {'id': id, 'source': 'flatpak'}),
          ),
        );
      } catch (_) {
        result.add(null);
      }
    }
    featured = result.first;
    essentials = result.skip(1).whereType<StorePackage>().toList();
    changed();
  }

  void selectPage(StorePage value) {
    page = value;
    ++_generation;
    if (value == StorePage.home || value == StorePage.installed) category = '';
    if (value == StorePage.installed) {
      source = 'all';
      repo = '';
    }
    error = null;
    changed();
    if (value == StorePage.updates) {
      loadUpdates();
    } else if (value == StorePage.sources) {
      loadSources();
    } else {
      loadCatalog();
    }
  }

  void search(String text) {
    query = text;
    error = null;
    if (page == StorePage.updates || page == StorePage.sources) {
      page = StorePage.home;
    }
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 420), loadCatalog);
    changed();
  }

  void filterSource(String value) {
    source = value;
    repo = '';
    loadCatalog();
  }

  void filterRepo(String value) {
    repo = value;
    if (value.isNotEmpty) source = 'deb';
    loadCatalog();
  }

  void filterCategory(String value) {
    category = value;
    loadCatalog();
  }

  void toggleTheme() {
    dark = !dark;
    changed();
  }

  Future<void> loadCatalog({bool more = false, int? targetPage}) async {
    final generation = ++_generation;
    loading = true;
    error = null;
    final requestedPage = targetPage ?? (more ? catalogPage + 1 : 0);
    changed();
    try {
      final data = await service.request(
        page == StorePage.installed ? 'installed' : 'catalog',
        {
          'query': query,
          'source': source,
          'repo': repo,
          'category': category,
          'page': requestedPage,
          'fresh': page == StorePage.fresh,
        },
      );
      if (generation != _generation) return;
      catalogPage = requestedPage;
      final incoming = [
        for (final v in data['items'] ?? [])
          StorePackage(Map<String, dynamic>.from(v)),
      ];
      packages = incoming;
      warnings = [
        for (final v in data['warnings'] ?? []) Map<String, dynamic>.from(v),
      ];
      final totals = Map<String, dynamic>.from(data['totals'] ?? {});
      hasMore =
          !preview &&
          (data['hasMore'] as bool? ??
              totals.values.any((v) => (v as num) > (catalogPage + 1) * 24));
    } catch (e) {
      if (generation == _generation) error = clean(e);
    }
    if (generation == _generation) {
      loading = false;
      changed();
    }
  }

  Future<void> loadUpdates() async {
    loading = true;
    error = null;
    changed();
    try {
      updates = await service.request('updates');
      for (final source in ['deb', 'flatpak', 'appimage']) {
        final keys = updateItems(source).map(updateKey).toSet();
        updateSelections
            .putIfAbsent(source, () => {})
            .retainWhere(keys.contains);
      }
    } catch (e) {
      error = clean(e);
    }
    loading = false;
    changed();
  }

  List<Map<String, dynamic>> updateItems(String source) => [
    for (final v
        in (source == 'deb'
                ? (updates['system'] as Map? ?? {})['items']
                : updates[source]) ??
            [])
      {...Map<String, dynamic>.from(v), 'source': source},
  ];

  static String updateKey(Map<String, dynamic> item) =>
      '${item['source']}:${item['scope'] ?? 'system'}:${item['reference'] ?? item['id']}';

  void selectUpdate(String source, String key, bool selected) {
    final values = updateSelections.putIfAbsent(source, () => {});
    selected ? values.add(key) : values.remove(key);
    changed();
  }

  void selectAllUpdates(String source, bool selected) {
    updateSelections[source] = selected
        ? updateItems(source).map(updateKey).toSet()
        : {};
    changed();
  }

  Future<void> enqueue(StoreJob job) async {
    if (queue.any(
      (j) =>
          (j.pending || j.active) &&
          j.request['id'] == job.request['id'] &&
          j.source == job.source &&
          j.request['scope'] == job.request['scope'] &&
          j.request['reference'] == job.request['reference'] &&
          j.request['packages'].toString() ==
              job.request['packages'].toString() &&
          j.operation == job.operation,
    )) {
      throw StateError('This package is already in the queue.');
    }
    queue.add(job);
    while (queue.length > 30) {
      final index = queue.indexWhere(
        (value) => !value.pending && !value.active,
      );
      if (index < 0) break;
      queue.removeAt(index);
    }
    changed();
    unawaited(_runQueue());
  }

  void removeQueued(StoreJob job) {
    if (job.pending) {
      job.status = JobStatus.removed;
      job.message = 'Removed from queue';
      changed();
    }
  }

  Future<void> _runQueue() async {
    if (queueRunning) return;
    queueRunning = true;
    while (!_disposed) {
      final job = queue.where((j) => j.pending).firstOrNull;
      if (job == null) break;
      job.status = JobStatus.preparing;
      job.message = 'Checking the selected source';
      changed();
      try {
        var body = job.request;
        String action;
        if (job.source == 'deb' || job.source == 'flatpak') {
          final prefix = job.source == 'deb' ? 'apt' : 'flatpak';
          final fresh = await service.request('$prefix-plan', job.request);
          final approved = <String, dynamic>{
            for (final v in job.review['changes'] ?? []) v['id'] as String: v,
          };
          final unchanged = job.source == 'deb'
              ? (fresh['changes'] as List).every((v) {
                  final old = approved[v['id']];
                  return old != null &&
                      old['version'] == v['version'] &&
                      old['action'] == v['action'] &&
                      old['fromVersion'] == v['fromVersion'];
                })
              : sameFlatpakReview(job.review, fresh);
          if (!unchanged) {
            throw StateError(
              'This package changed while queued. Review it again before installing.',
            );
          }
          action = '$prefix-apply';
          body = {
            'token': fresh['token'],
            if (job.source == 'flatpak')
              'scope': job.request['scope'] ?? 'system',
          };
        } else if (job.source == 'refresh') {
          action = 'refresh';
        } else {
          action = job.operation == 'remove'
              ? 'appimage-remove'
              : 'appimage-install';
        }
        job.status = JobStatus.running;
        changed();
        await for (final event in service.execute(action, body)) {
          job.message = event['message'] ?? 'Installing';
          if (event['progress'] != null) {
            job.progress = (event['progress'] as num).toDouble().clamp(0, 1);
          }
          job.log.add(job.message);
          if (job.log.length > 500) job.log.removeAt(0);
          if (event['error'] == true) throw StateError(job.message);
          changed();
        }
        job.status = JobStatus.completed;
        job.progress = 1;
      } catch (e) {
        job.status = JobStatus.failed;
        job.message = clean(e);
        job.log.add(job.message);
      }
      changed();
    }
    queueRunning = false;
    if (!_disposed) {
      unawaited(loadSources());
      if (page != StorePage.updates && page != StorePage.sources) {
        unawaited(loadCatalog());
      }
      unawaited(loadEssentials());
      if (page == StorePage.updates) unawaited(loadUpdates());
    }
  }

  static bool sameFlatpakReview(
    Map<String, dynamic> old,
    Map<String, dynamic> fresh,
  ) {
    const fields = ['commit', 'reference', 'scope', 'origin', 'remoteUrl'];
    if (fresh['operation'] != 'update-selected') {
      return fields.every((key) => old[key] == fresh[key]);
    }
    if (!mapEquals(
      Map<String, dynamic>.from(old['commits'] ?? {}),
      Map<String, dynamic>.from(fresh['commits'] ?? {}),
    )) {
      return false;
    }
    final previous = {
      for (final item in old['items'] ?? []) item['reference']: item,
    };
    return (fresh['items'] as List? ?? []).every(
      (item) =>
          previous[item['reference']] != null &&
          fields.every((key) => previous[item['reference']][key] == item[key]),
    );
  }

  static String clean(Object value) =>
      value.toString().replaceFirst('Bad state: ', '');
  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    darkTheme.dispose();
    super.dispose();
  }
}
