// Sources exposes existing APT repositories, the official Flathub remote, and AppImageHub.
import 'package:flutter/material.dart';

import '../../app/store_theme.dart';
import '../../core/controllers/store_controller.dart';
import '../../core/models/store_models.dart';
import '../widgets/store_widgets.dart';
import '../details/transaction_review.dart';

class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key, required this.controller});
  final StoreController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final flathub = c.flatpakSources
        .where((v) => v['id'] == 'flathub')
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.only(bottom: 35),
      children: [
        Text(
          'Good things come from good sources.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 9),
        Text(
          'Choose where you discover software. Every app keeps its source visible.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        if (c.loadingSources) const LinearProgressIndicator(minHeight: 2),
        if (c.error != null) ...[
          StoreNotice(c.error!, onRetry: c.loadSources),
          const SizedBox(height: 16),
        ],
        const SectionHeading('APT repositories'),
        const SizedBox(height: 15),
        for (final repo in c.repositories)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor(context),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 21,
                  vertical: 10,
                ),
                leading: Icon(
                  Icons.inventory_2_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(
                  repo['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    repo['trusted'] == true
                        ? 'Signed repository · Debian packages'
                        : 'Repository trust needs attention',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                trailing: TextButton(
                  onPressed: () {
                    c.repo = repo['id'];
                    c.source = 'deb';
                    c.selectPage(StorePage.home);
                  },
                  child: const Text('Browse'),
                ),
              ),
            ),
          ),
        if (!c.loadingSources && c.repositories.isEmpty)
          const StoreNotice(
            'No APT repository indexes are available. Check for system updates to refresh them.',
          ),
        const SizedBox(height: 28),
        const SectionHeading('Flatpak', color: Color(0xff25c985)),
        const SizedBox(height: 15),
        if (!c.flatpakAvailable)
          _SourceCard(
            title: 'Flatpak needs to be installed',
            subtitle: 'Install Flatpak before adding apps from Flathub.',
            icon: Icons.apps_rounded,
            trailing: FilledButton(
              onPressed: () => reviewTransaction(
                context,
                c,
                title: 'Flatpak',
                source: 'deb',
                operation: 'install',
                request: {
                  'source': 'deb',
                  'id': 'flatpak',
                  'operation': 'install',
                },
              ),
              child: const Text('Install Flatpak'),
            ),
          )
        else
          _SourceCard(
            title: 'Flathub',
            subtitle:
                'Desktop apps with bundled runtimes and sandbox permissions.',
            icon: Icons.apps_rounded,
            trailing: Switch(
              value: flathub?['enabled'] == true,
              onChanged: (value) async {
                try {
                  await c.service.request('flatpak-source', {'enabled': value});
                  await c.loadSources();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(StoreController.clean(e))),
                    );
                  }
                }
              },
            ),
          ),
        const SizedBox(height: 28),
        const SectionHeading('AppImage', color: Color(0xfff4d53d)),
        const SizedBox(height: 15),
        const _SourceCard(
          title: 'AppImageHub',
          subtitle: 'Portable applications installed for your user account.',
          icon: Icons.rocket_launch_rounded,
          trailing: Icon(Icons.check_circle_rounded, color: Color(0xff25c985)),
        ),
      ],
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final Widget trailing;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(21),
    decoration: BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(width: 17),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        trailing,
      ],
    ),
  );
}
