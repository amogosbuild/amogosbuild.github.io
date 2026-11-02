// Review and typed confirmation show the exact validated disk operations before execution.
import 'package:flutter/material.dart';

import '../../../core/controllers/install_controller.dart';
import '../../../core/models/install_models.dart';
import '../widgets/setup_widgets.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key, required this.controller});
  final InstallController controller;
  @override
  Widget build(BuildContext context) {
    final c = controller,
        p = c.proposal,
        colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageIntro(
            eyebrow: 'One last look',
            title: 'Your new beginning, at a glance.',
            description: 'Everything is ready. Check the details before we make any changes.',
          ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InfoLine(
                  icon: Icons.storage_rounded,
                  title: p?.summary ?? 'Installation plan',
                  detail:
                      '${c.disk?.model} · ${p?.disk} · ${formatBytes(p?.rootBytes ?? 0)} for AmogOS 2 Pro',
                ),
                if (p != null) ...[
                  const Divider(height: 24),
                  for (final op in p.operations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.arrow_right_alt_rounded,
                            size: 18,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              op,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (p.preserved.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final os in p.preserved)
                            StatusChip(
                              icon: Icons.verified_user_outlined,
                              text: 'Keep $os',
                            ),
                        ],
                      ),
                    ),
                  for (final warning in p.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        warning,
                        style: TextStyle(fontSize: 12, color: colors.error),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: InfoLine(
              icon: Icons.power_settings_new_rounded,
              title: 'Bootloader',
              detail: p?.bootDescription ?? 'Automatic GRUB placement',
            ),
          ),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Column(
              children: [
                InfoLine(
                  icon: Icons.person_outline_rounded,
                  title: c.fullName,
                  detail:
                      '${c.username} on ${c.hostname} · ${c.autoLogin ? 'Automatic login' : 'Password protected'}',
                ),
                const Divider(height: 16),
                InfoLine(
                  icon: Icons.public_rounded,
                  title: c.timezone.replaceAll('_', ' '),
                  detail: '${c.locale} · ${c.keyboard.toUpperCase()} keyboard',
                ),
                const Divider(height: 16),
                InfoLine(
                  icon: Icons.memory_rounded,
                  title: c.drivers
                      ? 'Recommended hardware support'
                      : 'Keep the included drivers',
                  detail: c.upgrade
                      ? 'Full system upgrade, verified before installation completes'
                      : 'Install the included system without a full package upgrade',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> confirmInstallation(
  BuildContext context,
  InstallController controller,
) async {
  final name = controller.proposal!.confirmation.isNotEmpty
      ? controller.proposal!.confirmation
      : controller.proposal!.disk.split('/').last;
  final text = TextEditingController();
  var accepted = false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Ready to make it yours?'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.preview
                      ? 'This runs a preview. It will not modify any disks.'
                      : 'The reviewed changes will now be applied to ${controller.proposal!.disk}. Boot setup: ${controller.proposal!.bootDescription}. Formatting and resizing cannot be undone by the installer.',
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: text,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Type $name to confirm',
                    hintText: name,
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: accepted,
                  onChanged: (v) => setState(() => accepted = v ?? false),
                  title: const Text(
                    'I have reviewed the changes and backed up the files I need.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: accepted && text.text == name
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(
              controller.preview ? 'Start preview' : 'Install AmogOS 2 Pro',
            ),
          ),
        ],
      ),
    ),
  );
  text.dispose();
  if (confirmed == true) await controller.begin(name);
}
