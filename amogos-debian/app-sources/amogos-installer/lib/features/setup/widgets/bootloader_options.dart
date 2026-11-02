// Bootloader selection offers firmware-compatible automatic and custom destinations.
import 'package:flutter/material.dart';

import '../../../core/controllers/install_controller.dart';
import '../../../core/models/install_models.dart';
import 'setup_widgets.dart';

class BootloaderOptions extends StatelessWidget {
  const BootloaderOptions({super.key, required this.controller});
  final InstallController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = Theme.of(context).colorScheme;
    final uefi = c.inventory!.uefi;
    final disks = c.inventory!.disks
        .where((d) => d.blockedReason.isEmpty)
        .toList();
    final target = disks
        .where((d) => d.path == (c.bootDisk ?? c.disk?.path))
        .firstOrNull;
    final candidates =
        target?.partitions
            .where(
              (p) =>
                  p.mounts.isEmpty && (uefi ? p.esp && p.fs == 'vfat' : p.bios),
            )
            .toList() ??
        <Partition>[];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose your bootloader',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 7),
          Text(
            'Choose how AmogOS 2 Pro starts, and where its boot files belong.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            key: ValueKey('loader-${c.bootloader}'),
            initialValue: c.bootloader,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bootloader',
              prefixIcon: Icon(Icons.power_settings_new_rounded),
            ),
            items: [
              const DropdownMenuItem(
                value: 'grub',
                child: Text(
                  'GRUB · recommended for multi-boot',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DropdownMenuItem(
                value: 'systemd-boot',
                enabled: uefi,
                child: Text(
                  uefi
                      ? 'systemd-boot · simple UEFI boot menu'
                      : 'systemd-boot · requires UEFI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const DropdownMenuItem(
                value: 'none',
                child: Text(
                  'Keep my existing bootloader · advanced',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (v) => c.change(() {
              c.bootloader = v!;
              c.proposal = null;
            }),
          ),
          const SizedBox(height: 15),
          if (c.bootloader == 'none')
            Text(
              'AmogOS 2 Pro will be installed without writing a bootloader or firmware entry. Add it to your existing boot menu before restarting.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            )
          else ...[
            SegmentedButton<String>(
              direction: MediaQuery.sizeOf(context).width < 760
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: const [
                ButtonSegment(
                  value: 'auto',
                  icon: Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text('Let the installer choose'),
                ),
                ButtonSegment(
                  value: 'custom',
                  icon: Icon(Icons.tune_rounded, size: 16),
                  label: Text('Choose a destination'),
                ),
              ],
              selected: {c.bootPlacement},
              onSelectionChanged: (v) => c.change(() {
                c.bootPlacement = v.first;
                c.bootDisk ??= c.disk?.path;
                c.bootPartition = null;
                c.manualEsp = null;
                c.proposal = null;
              }),
            ),
            const SizedBox(height: 13),
            if (c.bootPlacement == 'auto')
              Text(
                uefi
                    ? 'Reuse a suitable EFI system partition on the installation drive, or create one as part of the reviewed layout.'
                    : 'Install GRUB to the installation drive’s boot sector and use or create its reserved BIOS boot partition.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              )
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('boot-disk-${target?.path}'),
                initialValue: target?.path,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Boot disk'),
                items: [
                  for (final disk in disks)
                    DropdownMenuItem(
                      value: disk.path,
                      child: Text(
                        '${disk.model} · ${disk.path}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => c.change(() {
                  c.bootDisk = v;
                  c.bootPartition = null;
                  c.proposal = null;
                }),
              ),
              const SizedBox(height: 14),
              if (uefi || target?.table != 'dos')
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'boot-partition-${target?.path}-${c.bootPartition}',
                  ),
                  initialValue: c.bootPartition ?? 'auto',
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: uefi
                        ? 'EFI system partition'
                        : 'Reserved BIOS boot partition',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'auto',
                      child: Text(
                        target?.path == c.disk?.path
                            ? 'Choose or create the appropriate boot partition'
                            : 'Choose the existing boot partition on this disk',
                      ),
                    ),
                    for (final p in candidates)
                      DropdownMenuItem(
                        value: p.path,
                        child: Text(
                          '${p.path} · ${formatBytes(p.size)} · ${uefi ? 'preserve EFI files' : 'BIOS boot area'}',
                        ),
                      ),
                  ],
                  onChanged: (v) => c.change(() {
                    c.bootPartition = v == 'auto' ? null : v;
                    c.proposal = null;
                  }),
                ),
              const SizedBox(height: 10),
              Text(
                uefi
                    ? 'EFI files can go on another drive’s existing FAT EFI partition. Existing partitions on that other drive are not formatted.'
                    : 'Legacy GRUB uses a disk boot sector and, on GPT, a reserved BIOS boot partition. It does not use an ordinary filesystem partition’s boot sector.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
            if (c.bootloader == 'systemd-boot')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'An existing ESP needs at least 512 MiB total and 256 MiB free. A new one uses 1 GiB. Other Linux installations need compatible boot entries on that ESP.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
