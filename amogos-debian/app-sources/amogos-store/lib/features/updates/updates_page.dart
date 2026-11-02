// Each package format has its own selectable updates and dependency review.
import 'package:flutter/material.dart';

import '../../app/store_theme.dart';
import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../details/transaction_review.dart';
import '../widgets/store_widgets.dart';
import 'update_review.dart';

class UpdatesPage extends StatelessWidget {
  const UpdatesPage({super.key, required this.controller});
  final StoreController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      key: const ValueKey('updates-list'),
      padding: const EdgeInsets.only(bottom: 35),
      children: [
        Text(
          'Keep your world fresh.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 9),
        const Text('Choose which system packages and applications to update.'),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: c.loading ? null : c.loadUpdates,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check for updates'),
            ),
            TextButton(
              onPressed: c.loading
                  ? null
                  : () => c.enqueue(
                      StoreJob(
                        title: 'Refresh package indexes',
                        source: 'refresh',
                        operation: 'refresh',
                        request: {},
                        review: {},
                      ),
                    ),
              child: const Text('Refresh APT indexes'),
            ),
            OutlinedButton.icon(
              onPressed: c.waitingCount > 0
                  ? null
                  : () => reviewTransaction(
                      context,
                      c,
                      title: 'Interrupted package installation',
                      source: 'deb',
                      operation: 'repair-system',
                      request: {'operation': 'repair-system', 'source': 'deb'},
                    ),
              icon: const Icon(Icons.build_outlined),
              label: const Text('Repair interrupted installation'),
            ),
          ],
        ),
        if (c.loading) const LinearProgressIndicator(minHeight: 2),
        if (c.error != null) StoreNotice(c.error!, onRetry: c.loadUpdates),
        for (final warning in c.updates['warnings'] ?? [])
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: StoreNotice(
              '${sourceLabels[warning['source']] ?? warning['source']}: ${warning['message']}',
            ),
          ),
        for (final source in ['deb', 'flatpak', 'appimage']) ...[
          const SizedBox(height: 22),
          _UpdateSection(controller: c, source: source),
        ],
        if ((c.updates['system'] as Map? ?? {})['rebootRequired'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: StoreNotice(
              'Restart your computer to finish applying installed system updates.',
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'APT includes the kernel, drivers and security fixes. Flatpak includes applications and runtimes in your user account and system. AppImage updates cover applications installed through this store.',
          style: TextStyle(fontSize: 11, height: 1.6),
        ),
      ],
    );
  }
}

class _UpdateSection extends StatelessWidget {
  const _UpdateSection({required this.controller, required this.source});
  final StoreController controller;
  final String source;
  @override
  Widget build(BuildContext context) {
    final c = controller, items = c.updateItems(source);
    final selected = c.updateSelections[source] ?? <String>{};
    return Material(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${sourceLabels[source]} updates',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              items.isEmpty
                  ? (c.loading ? 'Checking…' : 'No updates available.')
                  : '${items.length} updates available',
            ),
            if (items.isNotEmpty) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Select all'),
                value: selected.length == items.length,
                onChanged: c.loading
                    ? null
                    : (value) => c.selectAllUpdates(source, value == true),
              ),
              for (final item in items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(StoreController.updateKey(item)),
                  onChanged: c.loading
                      ? null
                      : (value) => c.selectUpdate(
                          source,
                          StoreController.updateKey(item),
                          value == true,
                        ),
                  title: Text(
                    item['name'] ?? item['id'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '${item['fromVersion'] ?? item['installedVersion'] ?? 'Installed'} → ${item['version'] ?? 'Latest'}${source == 'flatpak' ? '\n${item['scope'] == 'user' ? 'This user' : 'System'} · ${item['runtime'] == true ? 'Runtime' : 'Application'}' : ''}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: c.loading || selected.isEmpty
                      ? null
                      : () => reviewSelectedUpdates(context, c, source),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text('Review selected (${selected.length})'),
                ),
                if (source == 'deb')
                  TextButton(
                    onPressed: c.loading || items.isEmpty
                        ? null
                        : () => reviewTransaction(
                            context,
                            c,
                            title: 'AmogOS 2 Pro system updates',
                            source: 'deb',
                            operation: 'upgrade-system',
                            request: {
                              'operation': 'upgrade-system',
                              'source': 'deb',
                            },
                          ),
                    child: const Text('Review system updates'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
