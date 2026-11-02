// Storage choices expose detected systems, safe alongside candidates, and explicit manual assignments.
import 'package:flutter/material.dart';

import '../../../core/controllers/install_controller.dart';
import '../../../core/models/install_models.dart';
import '../widgets/setup_widgets.dart';
import '../widgets/bootloader_options.dart';

class StoragePage extends StatelessWidget {
  const StoragePage({super.key, required this.controller});
  final InstallController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller,
        t = Theme.of(context),
        colors = t.colorScheme,
        d = c.disk;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            eyebrow: 'Room for a new beginning',
            title: 'A home for AmogOS 2 Pro.',
            description: 'Keep your existing systems, start fresh, or take the controls yourself.',
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Installation drive',
                  style: t.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: c.busy ? null : c.refreshHardware,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Rescan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.busy)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (c.inventory?.disks.isEmpty ?? true)
            SurfaceCard(
              child: Column(
                children: [
                  const Icon(Icons.storage_rounded, size: 38),
                  const SizedBox(height: 12),
                  const Text('No installation drives are available.'),
                  const SizedBox(height: 8),
                  Text(
                    'Boot the live AmogOS 2 Pro image and connect an unlocked installation drive.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(d?.path),
              initialValue: d?.path,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.storage_rounded),
              ),
              items: [
                for (final disk in c.inventory!.disks)
                  DropdownMenuItem(
                    value: disk.path,
                    child: Text(
                      '${disk.model} · ${formatBytes(disk.size)} · ${disk.path}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => c.selectDisk(
                c.inventory!.disks.firstWhere((disk) => disk.path == v),
              ),
            ),
            const SizedBox(height: 14),
            if (d != null)
              SurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.dns_outlined, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.table.isEmpty
                                ? 'Unpartitioned drive'
                                : '${d.table.toUpperCase()} partition table',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          icon: c.inventory!.uefi
                              ? Icons.memory_rounded
                              : Icons.settings_input_component_rounded,
                          text: c.inventory!.uefi ? 'UEFI' : 'Legacy BIOS',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 18,
                        child: Row(
                          children: [
                            for (final p in d.partitions)
                              Expanded(
                                flex: (p.size / d.size * 1000).round().clamp(
                                  8,
                                  1000,
                                ),
                                child: Container(color: _partitionColor(p)),
                              ),
                            for (final free in d.free)
                              Expanded(
                                flex: (free.size / d.size * 1000).round().clamp(
                                  8,
                                  1000,
                                ),
                                child: Container(color: colors.outlineVariant),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        for (final p in d.partitions)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _partitionColor(p),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${p.os.isNotEmpty ? p.os : p.fs} · ${formatBytes(p.size)}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        if (d.free.isNotEmpty)
                          Text(
                            'Free space · ${formatBytes(d.free.fold<int>(0, (a, b) => a + b.size))}',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (d.blockedReason.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          d.blockedReason,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<InstallMode>(
                direction: MediaQuery.sizeOf(context).width < 720
                    ? Axis.vertical
                    : Axis.horizontal,
                segments: const [
                  ButtonSegment(
                    value: InstallMode.smart,
                    icon: Icon(Icons.auto_awesome_rounded, size: 17),
                    label: Text('Smart install'),
                  ),
                  ButtonSegment(
                    value: InstallMode.erase,
                    icon: Icon(Icons.cleaning_services_outlined, size: 17),
                    label: Text('Erase drive'),
                  ),
                  ButtonSegment(
                    value: InstallMode.manual,
                    icon: Icon(Icons.tune_rounded, size: 17),
                    label: Text('Manual'),
                  ),
                ],
                selected: {c.mode},
                onSelectionChanged: (v) => c.change(() {
                  c.mode = v.first;
                  c.proposal = null;
                }),
              ),
            ),
            const SizedBox(height: 18),
            if (d != null)
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.mode == InstallMode.smart) ...[
                      Text(
                        'Make room. Keep what matters.',
                        style: t.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'We detect existing Windows and Linux systems and keep their partitions and boot entries. Choose free space or a supported partition to shrink.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _spaceChoice(
                        context,
                        'auto',
                        'Find the best available space',
                        'Prefer unallocated space; otherwise use an eligible shrink candidate.',
                      ),
                      for (final free in d.free.where(
                        (f) => f.size >= 24 * 1073741824,
                      ))
                        _spaceChoice(
                          context,
                          'free:${free.start}',
                          'Use ${formatBytes(free.size)} of unallocated space',
                          'No existing filesystem will be resized.',
                        ),
                      for (final p in d.partitions.where(
                        (p) =>
                            p.minimumSize != null &&
                            p.size - p.minimumSize! >= 24 * 1073741824 &&
                            p.blockedReason.isEmpty,
                      ))
                        _spaceChoice(
                          context,
                          'shrink:${p.path}',
                          'Install alongside ${p.os.isEmpty ? p.fs : p.os}',
                          'Shrink ${p.path}; keep at least ${formatBytes(p.minimumSize!)} for the existing system.',
                        ),
                      for (final p in d.partitions.where(
                        (p) => p.blockedReason.isNotEmpty,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${p.path}: ${p.blockedReason}',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ] else if (c.mode == InstallMode.erase) ...[
                      Icon(Icons.warning_amber_rounded, color: colors.error),
                      const SizedBox(height: 8),
                      Text(
                        'A completely fresh start.',
                        style: t.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Everything on ${d.path} will be permanently erased, including all existing operating systems and files. We’ll create new partitions for AmogOS 2 Pro.',
                        style: TextStyle(fontSize: 12, color: colors.error),
                      ),
                    ] else ...[
                      Text(
                        'Your partitions. Your choice.',
                        style: t.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Assign an existing partition for AmogOS 2 Pro, or create one in free space. Only the chosen root partition is formatted; existing EFI files are preserved.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: c.manualRoot,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'AmogOS 2 Pro root partition (/)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'new',
                            child: Text(
                              'Create a new ext4 partition in unallocated space',
                            ),
                          ),
                          for (final p in d.partitions.where(
                            (p) =>
                                !p.esp &&
                                p.mounts.isEmpty &&
                                p.size >= 24 * 1073741824 &&
                                p.fs != 'crypto_LUKS' &&
                                p.fs != 'BitLocker',
                          ))
                            DropdownMenuItem(
                              value: p.path,
                              child: Text(
                                '${p.path} · ${formatBytes(p.size)} · ${p.os.isEmpty ? p.fs : p.os} (format)',
                              ),
                            ),
                        ],
                        onChanged: (v) => c.change(() => c.manualRoot = v),
                      ),
                      const SizedBox(height: 16),
                      if (c.manualRoot == 'new')
                        DropdownButtonFormField<int>(
                          initialValue: c.freeStart,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unallocated region',
                          ),
                          items: [
                            for (final free in d.free.where(
                              (f) => f.size >= 24 * 1073741824,
                            ))
                              DropdownMenuItem(
                                value: free.start,
                                child: Text(
                                  '${formatBytes(free.size)} · offset ${formatBytes(free.start)}',
                                ),
                              ),
                          ],
                          onChanged: (v) => c.change(() => c.freeStart = v),
                        ),
                    ],
                    if (c.mode != InstallMode.erase &&
                        (c.mode != InstallMode.manual ||
                            c.manualRoot == 'new')) ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text(
                            'Space for AmogOS 2 Pro',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${c.rootGiB.round()} GB',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: c.rootGiB
                            .clamp(24, (d.size / 1073741824).clamp(25, 2048))
                            .toDouble(),
                        min: 24,
                        max: (d.size / 1073741824).clamp(25, 2048).toDouble(),
                        onChanged: (v) => c.change(() => c.rootGiB = v),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 18),
            BootloaderOptions(controller: c),
            const SizedBox(height: 18),
            SurfaceCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: c.drivers,
                    onChanged: (v) => c.change(() => c.drivers = v),
                    title: const Text(
                      'Set up recommended drivers',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Detect graphics, Wi-Fi, and firmware, including supported NVIDIA GPUs.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                  for (final driver in c.inventory!.drivers)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: colors.primary,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              driver.device,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 25),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: c.upgrade,
                    onChanged: (v) => c.change(() => c.upgrade = v),
                    title: const Text(
                      'Online installation: update all system packages',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      c.inventory!.online
                          ? 'Refresh all repositories, perform a full upgrade, and verify the result. Internet required.'
                          : 'Currently offline. Updates need an internet connection.',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _spaceChoice(
    BuildContext context,
    String id,
    String title,
    String subtitle,
  ) {
    final c = controller;
    final selected = c.shrinkPartition != null
        ? 'shrink:${c.shrinkPartition}'
        : c.freeStart != null
        ? 'free:${c.freeStart}'
        : 'auto';
    return RadioListTile<String>(
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: id,
      groupValue: selected,
      onChanged: (v) => c.change(() {
        c.shrinkPartition = null;
        c.freeStart = null;
        if (v!.startsWith('free:')) c.freeStart = int.parse(v.substring(5));
        if (v.startsWith('shrink:')) c.shrinkPartition = v.substring(7);
      }),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    );
  }

  Color _partitionColor(Partition p) => p.esp
      ? const Color(0xFFA7A1B4)
      : p.fs == 'ntfs'
      ? const Color(0xFF79B7E9)
      : const Color(0xFFB49ADF);
}
