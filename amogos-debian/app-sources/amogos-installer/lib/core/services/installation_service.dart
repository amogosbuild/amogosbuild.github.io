// Structured helper transport keeps credentials on stdin and privileged work outside Flutter.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/install_models.dart';

class InstallationService {
  InstallationService({required this.preview});
  final bool preview;

  Future<Process> _start(String action) =>
      Process.start('pkexec', ['/usr/libexec/amogos-installer-helper', action]);

  Future<String> _errors(Stream<List<int>> stream) =>
      stream.transform(utf8.decoder).fold<String>('', (tail, chunk) {
        final text = tail + chunk;
        return text.length > 65536 ? text.substring(text.length - 65536) : text;
      });

  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, dynamic> body,
  ) async {
    final process = await _start(action);
    process.stdin.writeln(jsonEncode(body));
    await process.stdin.close();
    final errors = _errors(process.stderr);
    final output = await process.stdout.transform(utf8.decoder).join();
    final code = await process.exitCode;
    final error = await errors;
    if (code != 0) {
      try {
        throw StateError((jsonDecode(output) as Map)['message'] ?? error);
      } on FormatException {
        throw StateError(
          error.isEmpty
              ? 'Authorization was cancelled or the installer helper is unavailable.'
              : error,
        );
      }
    }
    return Map<String, dynamic>.from(jsonDecode(output));
  }

  Future<Inventory> probe() async => Inventory.fromJson(
    preview ? _sampleInventory : await _request('probe', {}),
  );

  Future<InstallationPlan> plan(Map<String, dynamic> body) async {
    if (!preview) {
      return InstallationPlan.fromJson(await _request('plan', body));
    }
    return InstallationPlan(
      token: 'preview-plan',
      disk: body['disk'],
      summary: body['mode'] == 'erase'
          ? 'Replace the selected drive with AmogOS 2 Pro'
          : body['mode'] == 'manual'
          ? 'Install using your selected partitions'
          : 'Install AmogOS 2 Pro alongside your existing systems',
      operations: [
        if (body['mode'] == 'erase')
          'Erase the selected drive and create a GPT partition table'
        else
          'Keep Windows Boot Manager and Debian unchanged',
        'Prepare ${formatBytes(body['rootBytes'])} for AmogOS 2 Pro',
        'Copy the system and configure your account',
        body['bootloader'] == 'none'
            ? 'Keep your existing bootloader for manual configuration'
            : 'Install ${body['bootloader'] == 'systemd-boot' ? 'systemd-boot' : 'GRUB'} at the reviewed boot destination',
      ],
      warnings: ['This is a design preview. No disks will be changed.'],
      rootBytes: body['rootBytes'],
      bootDescription: body['bootloader'] == 'none'
          ? 'Keep your existing bootloader'
          : '${body['bootloader'] == 'systemd-boot' ? 'systemd-boot' : 'GRUB'} · ${body['bootPlacement'] == 'custom' ? body['bootPartition'] ?? body['bootDisk'] : 'Automatic placement'}',
      confirmation:
          (body['bootPlacement'] == 'custom' &&
              body['bootloader'] != 'none' &&
              body['bootDisk'] != body['disk'])
          ? '${(body['disk'] as String).split('/').last} + ${(body['bootDisk'] as String).split('/').last}'
          : (body['disk'] as String).split('/').last,
      preserved: body['mode'] == 'erase'
          ? []
          : ['Windows 11', 'Debian GNU/Linux'],
    );
  }

  Stream<InstallEvent> install(Map<String, dynamic> body) async* {
    if (preview) {
      final stages = [
        ('prepare', 'Preparing your new home'),
        ('partition', 'Preparing the selected partitions'),
        ('copy', 'Unpacking AmogOS 2 Pro'),
        ('configure', 'Making it yours'),
        ('drivers', 'Setting up hardware support'),
        ('bootloader', 'Adding your boot menu'),
        ('finish', 'A few finishing touches'),
      ];
      yield* Stream<InstallEvent>.periodic(const Duration(milliseconds: 650), (
        i,
      ) {
        if (i == 140) {
          return const InstallEvent(
            'complete',
            1,
            'Preview complete. No disks were changed.',
            done: true,
          );
        }
        final stage =
            stages[(i * stages.length ~/ 140).clamp(0, stages.length - 1)];
        return InstallEvent(stage.$1, i / 140, stage.$2);
      }).take(141);
      return;
    }
    final process = await _start('install');
    process.stdin.writeln(jsonEncode(body));
    await process.stdin.close();
    final errors = _errors(process.stderr);
    var completed = false, failed = false;
    await for (final line
        in process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final event = InstallEvent.fromJson(
        Map<String, dynamic>.from(jsonDecode(line)),
      );
      completed |= event.done;
      failed |= event.error;
      yield event;
    }
    final code = await process.exitCode;
    final error = await errors;
    if (!completed && !failed) {
      yield InstallEvent(
        'error',
        0,
        error.isNotEmpty
            ? error
            : 'Installation stopped unexpectedly (exit $code).',
        error: true,
      );
    }
  }

  Future<void> reboot() async {
    if (!preview) await Process.run('systemctl', ['reboot']);
  }
}

const _sampleInventory = <String, dynamic>{
  'live': true,
  'uefi': true,
  'online': true,
  'drivers': [
    {
      'device': 'NVIDIA GeForce RTX 4060',
      'packages': ['nvidia-driver', 'linux-headers-amd64'],
      'note': 'Recommended Debian driver',
    },
    {
      'device': 'Intel Wi-Fi 6 AX200',
      'packages': ['firmware-iwlwifi'],
      'note': 'Wi-Fi firmware detected',
    },
  ],
  'disks': [
    {
      'path': '/dev/nvme0n1',
      'model': 'Samsung SSD 980 PRO',
      'size': 1099511627776,
      'table': 'gpt',
      'serial': 'PREVIEW-ONLY',
      'partitions': [
        {
          'path': '/dev/nvme0n1p1',
          'number': 1,
          'start': 1048576,
          'size': 536870912,
          'fs': 'vfat',
          'os': 'Windows Boot Manager',
          'esp': true,
        },
        {
          'path': '/dev/nvme0n1p2',
          'number': 2,
          'start': 537919488,
          'size': 644245094400,
          'fs': 'ntfs',
          'os': 'Windows 11',
          'minimumSize': 322122547200,
        },
        {
          'path': '/dev/nvme0n1p3',
          'number': 3,
          'start': 644783013888,
          'size': 257698037760,
          'fs': 'ext4',
          'os': 'Debian GNU/Linux',
          'minimumSize': 107374182400,
        },
      ],
      'free': [
        {'start': 902481051648, 'size': 197029527552},
      ],
    },
  ],
};
