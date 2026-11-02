// Real installation milestones remain visible beside the optional arcade.
import 'package:flutter/material.dart';

import '../../../core/controllers/install_controller.dart';
import '../../games/game_arcade.dart';
import '../widgets/setup_widgets.dart';

class InstallPage extends StatelessWidget {
  const InstallPage({
    super.key,
    required this.controller,
    required this.musicOpen,
  });
  final InstallController controller;
  final bool musicOpen;
  @override
  Widget build(BuildContext context) {
    final c = controller, colors = Theme.of(context).colorScheme;
    if (c.complete) {
      return _finished(context);
    }
    if (c.event.error) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageIntro(
              eyebrow: 'Let’s take a closer look',
              title: 'Installation needs attention.',
              description: 'Your installation stopped before it could finish.',
            ),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: colors.error,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  SelectableText(c.event.message),
                  const SizedBox(height: 18),
                  const Text(
                    'The installation log is saved in /var/log/amogos-installer/. Keep this live session open to investigate before restarting.',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GOOD THINGS ARE UNPACKING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We’ll handle the setup.\nYou handle the high score.',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: LayoutBuilder(
                builder: (context, size) => Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: RepaintBoundary(
                        child: TickerMode(
                          enabled: !musicOpen,
                          child: const GameArcade(),
                        ),
                      ),
                    ),
                    if (size.maxWidth > 720) ...[
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 220,
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(18),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MAKING IT YOURS',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                for (final stage in [
                                  ('prepare', 'Getting ready'),
                                  ('partition', 'Preparing storage'),
                                  ('copy', 'Copying AmogOS 2 Pro'),
                                  ('configure', 'Your preferences'),
                                  ('drivers', 'Hardware support'),
                                  ('updates', 'System updates'),
                                  ('bootloader', 'Your boot menu'),
                                  ('finish', 'Finishing touches'),
                                ])
                                  _stage(context, stage.$1, stage.$2),
                                const SizedBox(height: 16),
                                Text(
                                  'Music and games run independently. Taking a break won’t pause your installation.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
        return box.maxHeight < 500
            ? SingleChildScrollView(child: SizedBox(height: 600, child: body))
            : body;
      },
    );
  }

  Widget _stage(BuildContext context, String id, String title) {
    final c = controller,
        colors = Theme.of(context).colorScheme,
        active = c.event.stage == id;
    final done = c.events.any((e) => e.stage == id) && !active;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          if (active)
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          else
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 17,
              color: done ? const Color(0xFF6CAF91) : colors.outlineVariant,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? colors.onSurface : colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _finished(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        SizedBox(height: 150, child: Image.asset('assets/images/amogus.png')),
        const SizedBox(height: 24),
        Text(
          controller.preview ? 'That’s the preview.' : 'Welcome home.',
          style: Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          controller.preview
              ? 'Your games, music, and setup flow are ready to explore. No disks were changed.'
              : 'AmogOS 2 Pro is installed. Your next chapter is a restart away.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        for (final warning in controller.events.where((e) => e.warning))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SurfaceCard(child: Text(warning.message)),
          ),
        if (!controller.preview)
          const Text(
            'Restart when you’re ready, then remove the installation media when prompted.',
            textAlign: TextAlign.center,
          ),
      ],
    ),
  );
}
