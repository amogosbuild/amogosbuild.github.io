// Installation state connects the wizard to validated plans and actual helper progress.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/install_models.dart';
import '../services/installation_service.dart';

class InstallController extends ChangeNotifier {
  InstallController({required this.preview})
    : service = InstallationService(preview: preview);
  final bool preview;
  final InstallationService service;
  static const steps = [
    'Welcome',
    'Location',
    'Keyboard',
    'Storage',
    'Your account',
    'Review',
    'Install',
  ];
  int step = 0;
  final darkTheme = ValueNotifier(false);
  bool get dark => darkTheme.value;
  set dark(bool value) => darkTheme.value = value;
  bool busy = false, drivers = true, upgrade = false, autoLogin = false;
  String locale = 'en_GB.UTF-8', timezone = 'Europe/London', keyboard = 'gb';
  String fullName = '',
      username = '',
      hostname = 'amogos',
      password = '',
      passwordAgain = '';
  String? error;
  InstallMode mode = InstallMode.smart;
  Inventory? inventory;
  InstallDisk? disk;
  String? shrinkPartition, manualRoot, manualEsp;
  String bootloader = 'grub', bootPlacement = 'auto';
  String? bootDisk, bootPartition;
  int? freeStart;
  double rootGiB = 80;
  InstallationPlan? proposal;
  InstallEvent event = const InstallEvent(
    'prepare',
    0,
    'Preparing your new home',
  );
  final List<InstallEvent> events = [];
  StreamSubscription<InstallEvent>? _subscription;
  bool get installing => step == 6 && !event.done && !event.error;
  bool get complete => event.done;
  double get progress => step < 6 ? step / 6 : event.progress;
  String get stageText => step == 6 ? event.message : steps[step];
  bool get accountValid =>
      fullName.trim().isNotEmpty &&
      RegExp(r'^[a-z_][a-z0-9_-]{0,31}$').hasMatch(username) &&
      RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$').hasMatch(hostname) &&
      password.length >= 8 &&
      password == passwordAgain;
  void change(VoidCallback update) {
    update();
    error = null;
    notifyListeners();
  }

  void toggleTheme() => change(() => dark = !dark);
  void back() {
    if (step > 0 && step < 6 && !busy) change(() => step--);
  }

  void selectDisk(InstallDisk value) => change(() {
    disk = value;
    manualRoot = null;
    manualEsp = null;
    freeStart = null;
    shrinkPartition = null;
    proposal = null;
  });

  Future<void> refreshHardware() async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      inventory = await service.probe();
      if (inventory!.disks.isNotEmpty) {
        disk = inventory!.disks.firstWhere(
          (d) => d.blockedReason.isEmpty,
          orElse: () => inventory!.disks.first,
        );
        rootGiB = rootGiB
            .clamp(24.0, (disk!.size / 1073741824 - 2).clamp(24.0, 2048.0))
            .toDouble();
      } else {
        disk = null;
      }
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
    }
    busy = false;
    notifyListeners();
  }

  Map<String, dynamic> get options => {
    'mode': mode.name,
    'disk': disk?.path,
    'rootBytes': (rootGiB * 1073741824).round(),
    'shrinkPartition': shrinkPartition,
    'freeStart': freeStart,
    'manualRoot': manualRoot,
    'manualEsp': manualEsp,
    'drivers': drivers,
    'upgrade': upgrade,
    'bootloader': bootloader,
    'bootPlacement': bootPlacement,
    'bootDisk': bootDisk ?? disk?.path,
    'bootPartition': bootPartition,
  };

  Future<void> next() async {
    if (busy || step >= 6) return;
    if (step == 3 &&
        (disk == null ||
            disk!.blockedReason.isNotEmpty ||
            inventory?.live != true)) {
      change(
        () => error = 'Choose an available installation drive from the live AmogOS 2 Pro session.',
      );
      return;
    }
    if (step == 4 && !accountValid) {
      change(
        () => error = 'Enter your name, a valid username and computer name, and matching passwords of at least 8 characters.',
      );
      return;
    }
    if (step == 3) {
      busy = true;
      error = null;
      notifyListeners();
      try {
        proposal = await service.plan(options);
      } catch (e) {
        error = e.toString().replaceFirst('Bad state: ', '');
      }
      busy = false;
      if (error != null) {
        notifyListeners();
        return;
      }
    }
    change(() => step++);
    if (step == 3 && inventory == null) await refreshHardware();
  }

  Future<void> begin(String confirmation) async {
    if (proposal == null || !accountValid || busy || step != 5) return;
    change(() {
      step = 6;
      events.clear();
    });
    _subscription = service
        .install({
          'token': proposal!.token,
          'confirmation': confirmation,
          'account': {
            'name': fullName.trim(),
            'username': username,
            'hostname': hostname,
            'password': password,
            'autoLogin': autoLogin,
          },
          'locale': locale,
          'timezone': timezone,
          'keyboard': keyboard,
        })
        .listen(
          (value) {
            event = value;
            if (events.isEmpty ||
                events.last.stage != value.stage ||
                value.warning ||
                value.error) {
              events.add(value);
            }
            if (value.done || value.error) {
              password = '';
              passwordAgain = '';
            }
            notifyListeners();
          },
          onError: (Object e) {
            event = InstallEvent(
              'error',
              event.progress,
              e.toString(),
              error: true,
            );
            password = '';
            passwordAgain = '';
            notifyListeners();
          },
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    darkTheme.dispose();
    password = '';
    passwordAgain = '';
    super.dispose();
  }
}
