// Typed storage inventory, partition proposals, and installation events.
enum InstallMode { smart, erase, manual }

class Partition {
  const Partition({
    required this.path,
    required this.number,
    required this.start,
    required this.size,
    this.fs = '',
    this.os = '',
    this.mounts = const [],
    this.uuid = '',
    this.esp = false,
    this.bios = false,
    this.minimumSize,
    this.blockedReason = '',
  });
  final String path, fs, os, uuid, blockedReason;
  final int number, start, size;
  final List<String> mounts;
  final bool esp, bios;
  final int? minimumSize;
  int get end => start + size;
  factory Partition.fromJson(Map<String, dynamic> j) => Partition(
    path: j['path'],
    number: j['number'],
    start: j['start'],
    size: j['size'],
    fs: j['fs'] ?? '',
    os: j['os'] ?? '',
    uuid: j['uuid'] ?? '',
    mounts: List<String>.from(j['mounts'] ?? []),
    esp: j['esp'] == true,
    bios: j['bios'] == true,
    minimumSize: j['minimumSize'],
    blockedReason: j['blockedReason'] ?? '',
  );
}

class FreeSpace {
  const FreeSpace(this.start, this.size);
  final int start, size;
  factory FreeSpace.fromJson(Map<String, dynamic> j) =>
      FreeSpace(j['start'], j['size']);
}

class InstallDisk {
  const InstallDisk({
    required this.path,
    required this.model,
    required this.size,
    this.table = '',
    this.serial = '',
    this.partitions = const [],
    this.free = const [],
    this.blockedReason = '',
  });
  final String path, model, table, serial, blockedReason;
  final int size;
  final List<Partition> partitions;
  final List<FreeSpace> free;
  factory InstallDisk.fromJson(Map<String, dynamic> j) => InstallDisk(
    path: j['path'],
    model: j['model'],
    size: j['size'],
    table: j['table'] ?? '',
    serial: j['serial'] ?? '',
    partitions: [
      for (final p in j['partitions'] ?? [])
        Partition.fromJson(Map<String, dynamic>.from(p)),
    ],
    free: [
      for (final p in j['free'] ?? [])
        FreeSpace.fromJson(Map<String, dynamic>.from(p)),
    ],
    blockedReason: j['blockedReason'] ?? '',
  );
}

class HardwareDriver {
  const HardwareDriver(this.device, this.packages, this.note);
  final String device, note;
  final List<String> packages;
  factory HardwareDriver.fromJson(Map<String, dynamic> j) => HardwareDriver(
    j['device'],
    List<String>.from(j['packages'] ?? []),
    j['note'] ?? '',
  );
}

class Inventory {
  const Inventory({
    required this.disks,
    required this.drivers,
    required this.live,
    required this.uefi,
    required this.online,
  });
  final List<InstallDisk> disks;
  final List<HardwareDriver> drivers;
  final bool live, uefi, online;
  factory Inventory.fromJson(Map<String, dynamic> j) => Inventory(
    disks: [
      for (final d in j['disks'])
        InstallDisk.fromJson(Map<String, dynamic>.from(d)),
    ],
    drivers: [
      for (final d in j['drivers'] ?? [])
        HardwareDriver.fromJson(Map<String, dynamic>.from(d)),
    ],
    live: j['live'] == true,
    uefi: j['uefi'] == true,
    online: j['online'] == true,
  );
}

class InstallationPlan {
  const InstallationPlan({
    required this.token,
    required this.disk,
    required this.summary,
    required this.operations,
    required this.warnings,
    required this.rootBytes,
    this.preserved = const [],
    this.bootDescription = '',
    this.confirmation = '',
  });
  final String token, disk, summary, bootDescription, confirmation;
  final List<String> operations, warnings, preserved;
  final int rootBytes;
  factory InstallationPlan.fromJson(Map<String, dynamic> j) => InstallationPlan(
    token: j['token'],
    disk: j['disk'],
    summary: j['summary'],
    operations: List<String>.from(j['operations']),
    warnings: List<String>.from(j['warnings'] ?? []),
    preserved: List<String>.from(j['preserved'] ?? []),
    rootBytes: j['rootBytes'],
    bootDescription: j['bootDescription'] ?? '',
    confirmation: j['confirmation'] ?? '',
  );
}

class InstallEvent {
  const InstallEvent(
    this.stage,
    this.progress,
    this.message, {
    this.done = false,
    this.error = false,
    this.warning = false,
  });
  final String stage, message;
  final double progress;
  final bool done, error, warning;
  factory InstallEvent.fromJson(Map<String, dynamic> j) => InstallEvent(
    j['stage'] ?? 'install',
    (j['progress'] as num? ?? 0).toDouble(),
    j['message'] ?? '',
    done: j['done'] == true,
    error: j['error'] == true,
    warning: j['warning'] == true,
  );
}

String formatBytes(num bytes) {
  if (bytes >= 1073741824) {
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
  return '${(bytes / 1048576).toStringAsFixed(0)} MB';
}
