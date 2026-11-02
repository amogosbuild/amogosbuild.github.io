// Per-app format choices include only verified available sources and separate APT repositories.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../widgets/store_widgets.dart';
import 'transaction_review.dart';

Future<void> showPackage(
  BuildContext context,
  StoreController c,
  StorePackage package,
) => showDialog<void>(
  context: context,
  builder: (context) => PackageDetails(controller: c, initial: package),
);

class PackageDetails extends StatefulWidget {
  const PackageDetails({
    super.key,
    required this.controller,
    required this.initial,
  });
  final StoreController controller;
  final StorePackage initial;
  @override
  State<PackageDetails> createState() => _PackageDetailsState();
}

class _PackageDetailsState extends State<PackageDetails> {
  late StorePackage selected;
  late List<StorePackage> variants;
  int? download;
  bool finding = true, detailLoading = true, busy = false;
  String? error;
  String? sourceNote;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    selected = widget.initial;
    variants = [selected];
    widget.controller.addListener(controllerChanged);
    unawaited(loadDetails(selected));
    unawaited(loadVariants());
  }

  void controllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(controllerChanged);
    super.dispose();
  }

  Future<void> loadVariants() async {
    try {
      final data = await widget.controller.service.request(
        'alternatives',
        widget.initial.request,
      );
      if (!mounted) return;
      setState(() {
        sourceNote = (data['warnings'] as List? ?? []).isNotEmpty
            ? 'Some sources could not be checked. Available choices are shown.'
            : null;
        final values = [
          for (final v in data['items'] ?? [])
            StorePackage(Map<String, dynamic>.from(v)),
        ];
        variants = values.isEmpty ? [selected] : values;
        if (!variants.any((v) => v.key == selected.key)) {
          variants.insert(0, selected);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => sourceNote =
              'Some sources could not be checked. Available choices are shown.',
        );
      }
    }
    if (mounted) setState(() => finding = false);
  }

  Future<void> loadDetails(StorePackage value) async {
    final current = ++generation;
    setState(() {
      selected = value;
      detailLoading = true;
      error = null;
      download = null;
    });
    try {
      final data = await widget.controller.service.request(
        'details',
        value.request,
      );
      if (!mounted || current != generation) return;
      setState(() {
        selected = StorePackage(data);
        if (selected.source == 'deb' && data['aptChoices'] is List) {
          variants = [
            for (final item in data['aptChoices'])
              StorePackage(Map<String, dynamic>.from(item)),
            ...variants.where((item) => item.source != 'deb'),
          ];
        }
        download = selected.downloads.firstOrNull?['number'] as int?;
      });
    } catch (e) {
      if (mounted && current == generation) {
        setState(() => error = StoreController.clean(e));
      }
    }
    if (mounted && current == generation) setState(() => detailLoading = false);
  }

  Future<void> operate(String operation) async {
    setState(() => busy = true);
    final build = selected.downloads
        .where((v) => v['number'] == download)
        .firstOrNull;
    final request = {
      ...selected.request,
      'operation': operation,
      if (build != null) ...{
        'download': build['number'],
        'filename': build['name'],
        'version': build['version'],
        'size': build['size'],
      },
    };
    final accepted = await reviewTransaction(
      context,
      widget.controller,
      title: selected.name,
      source: selected.source,
      operation: operation,
      request: request,
    );
    if (mounted) {
      setState(() => busy = false);
      if (accepted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formats = variants.map((v) => v.source).toSet().toList();
    final repos = variants.where((v) => v.source == 'deb').toList();
    final repoKeys = repos.map((v) => v.repo).toSet().toList();
    final images = variants.where((v) => v.source == 'appimage').toList();
    final unavailable =
        selected.source == 'appimage' &&
        selected.downloads.isEmpty &&
        !selected.installed;
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 790,
          maxHeight: MediaQuery.sizeOf(context).height - 64,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(27, 19, 13, 10),
              child: Row(
                children: [
                  SourceBadge(selected.source),
                  const Spacer(),
                  if (finding)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close app details',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(30, 8, 30, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PackageIcon(
                          selected,
                          size: MediaQuery.sizeOf(context).width < 600
                              ? 52
                              : 83,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected.name,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                selected.summary,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                selected.version.isEmpty
                                    ? selected.id
                                    : 'Version ${selected.version}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AdaptiveFields(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('format-${selected.source}'),
                            initialValue: selected.source,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Install from',
                            ),
                            items: [
                              for (final source in formats)
                                DropdownMenuItem(
                                  value: source,
                                  child: Text(sourceLabels[source] ?? source),
                                ),
                            ],
                            onChanged: busy
                                ? null
                                : (value) {
                                    if (value != null &&
                                        value != selected.source) {
                                      loadDetails(
                                        variants.firstWhere(
                                          (v) => v.source == value,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                        if (selected.source == 'deb' &&
                            repoKeys.length > 1) ...[
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey('repo-${selected.repo}'),
                              initialValue: selected.repo,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Repository',
                              ),
                              items: [
                                for (final repo in repoKeys)
                                  DropdownMenuItem(
                                    value: repo,
                                    child: Text(
                                      repo.replaceAll('|', ' · '),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        loadDetails(
                                          repos.firstWhere(
                                            (v) => v.repo == value,
                                          ),
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      finding
                          ? 'Checking which formats are available for this app…'
                          : sourceNote ?? 'Only available formats are shown.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    if (detailLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 13),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (selected.source == 'flatpak' &&
                        !widget.controller.flatpakAvailable) ...[
                      const SizedBox(height: 15),
                      const StoreNotice(
                        'Flatpak needs to be installed before you can install this app.',
                      ),
                      const SizedBox(height: 9),
                      OutlinedButton.icon(
                        onPressed:
                            busy ||
                                widget.controller.queue.any(
                                  (j) =>
                                      (j.active || j.pending) &&
                                      j.source == 'deb' &&
                                      j.request['id'] == 'flatpak',
                                )
                            ? null
                            : () async {
                                setState(() => busy = true);
                                await reviewTransaction(
                                  context,
                                  widget.controller,
                                  title: 'Flatpak',
                                  source: 'deb',
                                  operation: 'install',
                                  request: {
                                    'source': 'deb',
                                    'id': 'flatpak',
                                    'operation': 'install',
                                  },
                                );
                                if (mounted) setState(() => busy = false);
                              },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Install Flatpak'),
                      ),
                    ] else if (selected.source == 'flatpak' &&
                        !widget.controller.loadingSources &&
                        !widget.controller.flathubEnabled) ...[
                      const SizedBox(height: 15),
                      const StoreNotice(
                        'Enable Flathub in Sources before installing this app.',
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.controller.selectPage(StorePage.sources);
                        },
                        child: const Text('Open Sources'),
                      ),
                    ],
                    if (selected.source == 'appimage' && images.length > 1) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('appimage-listing-${selected.key}'),
                        initialValue: selected.key,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'AppImage listing',
                        ),
                        items: [
                          for (final image in images)
                            DropdownMenuItem(
                              value: image.key,
                              child: Text(
                                '${image.name}${image.version.isEmpty ? '' : ' · ${image.version}'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy || detailLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  unawaited(
                                    loadDetails(
                                      images.firstWhere(
                                        (image) => image.key == value,
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                    if (selected.source == 'appimage' &&
                        selected.downloads.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: ValueKey('download-${selected.id}-$download'),
                        initialValue: download,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'AppImage build',
                        ),
                        items: [
                          for (final d in selected.downloads)
                            DropdownMenuItem(
                              value: d['number'] as int,
                              child: Text(
                                d['name'],
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: busy
                            ? null
                            : (value) => setState(() => download = value),
                      ),
                    ],
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: StoreNotice(error!),
                      ),
                    if (unavailable && !detailLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: StoreNotice(
                          'This entry currently has no compatible x86-64 AppImage download.',
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'About this app',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 11),
                    SelectableText(
                      selected.description.isEmpty
                          ? selected.summary
                          : selected.description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (selected.id == 'com.thebrokenrail.MCPIReborn')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () =>
                              widget.controller.service.request('open-url', {
                                'url': 'https://gitea.thebrokenrail.com/minecraft-pi-reborn/minecraft-pi-reborn/releases/latest',
                              }),
                          icon: const Icon(Icons.open_in_new_rounded, size: 15),
                          label: const Text('Latest upstream release'),
                        ),
                      ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 22,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Source: ${selected.repo.replaceAll('|', ' · ')}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        if (selected.license.isNotEmpty)
                          Text(
                            'License: ${selected.license}',
                            style: TextStyle(
                              fontSize: 10,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    if (selected.screenshots.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          selected.screenshots.first,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(22),
              child: OverflowBar(
                spacing: 10,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  if (selected.installed && !selected.runtime)
                    TextButton.icon(
                      onPressed: busy ? null : () => operate('remove'),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                    ),

                  if (selected.installed && !selected.runtime)
                    OutlinedButton(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                await widget.controller.service.request(
                                  'launch',
                                  selected.request,
                                );
                              } catch (e) {
                                if (mounted) {
                                  setState(
                                    () => error = StoreController.clean(e),
                                  );
                                }
                              }
                            },
                      child: const Text('Open'),
                    ),

                  if (!selected.installed || selected.updatable)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xff19cc70),
                        foregroundColor: const Color(0xff052b16),
                      ),
                      onPressed:
                          busy ||
                              detailLoading ||
                              unavailable ||
                              (selected.source == 'flatpak' &&
                                  (!widget.controller.flatpakAvailable ||
                                      !widget.controller.flathubEnabled))
                          ? null
                          : () => operate(
                              selected.installed ? 'update' : 'install',
                            ),
                      icon: busy
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        selected.installed
                            ? 'Update'
                            : widget.controller.preview
                            ? 'Install preview'
                            : 'Install',
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
