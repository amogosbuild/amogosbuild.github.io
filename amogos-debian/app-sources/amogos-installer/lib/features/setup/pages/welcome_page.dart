// The welcome screen introduces the installer with its bundled Amogus character.
import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/setup_widgets.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context), c = t.colorScheme;
    return LayoutBuilder(
      builder: (context, size) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StatusChip(
              icon: Icons.auto_awesome_rounded,
              text: 'A FRESH START, MADE SIMPLE',
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New home.\nSame Amogus.',
                        style: t.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'A little less setup.\nA lot more possibility.',
                        style: t.textTheme.bodyLarge?.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Let’s make AmogOS 2 Pro yours. We’ll take care of the details, keep your favorite music close, and leave a little room for play.',
                        style: t.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          StatusChip(
                            icon: Icons.favorite_border_rounded,
                            text: 'Your space',
                          ),
                          StatusChip(
                            icon: Icons.headphones_rounded,
                            text: 'Your soundtrack',
                          ),
                          StatusChip(
                            icon: Icons.sports_esports_outlined,
                            text: 'Your high score',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (size.maxWidth > 650)
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 310,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(330, 310),
                            painter: _OrbitPainter(
                              dark: t.brightness == Brightness.dark,
                            ),
                          ),
                          Transform.rotate(
                            angle: -.09,
                            child: Image.asset(
                              'assets/images/amogus.png',
                              height: 240,
                            ),
                          ),
                          Positioned(
                            top: 18,
                            right: 5,
                            child: _tag(
                              context,
                              Icons.rocket_launch_outlined,
                              'Ready for a new orbit',
                              -.07,
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 2,
                            child: _tag(
                              context,
                              Icons.check_circle_outline_rounded,
                              'Good things ahead.',
                              .05,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 34),
            AdaptiveFields(
              children: [
                for (final item in [
                  (
                    Icons.tune_rounded,
                    'Made for you',
                    'A few choices. A familiar home.',
                  ),
                  (
                    Icons.shield_outlined,
                    'Clear at every step',
                    'Review every disk change first.',
                  ),
                  (
                    Icons.offline_bolt_outlined,
                    'Ready when you are',
                    'Install offline. Update your way.',
                  ),
                ]) ...[
                  if (item.$2 != 'Made for you') const SizedBox(width: 12),
                  Expanded(
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(17),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1, size: 21, color: c.primary),
                          const SizedBox(height: 13),
                          Text(
                            item.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.$3,
                            style: TextStyle(
                              color: c.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(
    BuildContext context,
    IconData icon,
    String label,
    double angle,
  ) => Transform.rotate(
    angle: angle,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.dark});
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      126,
      Paint()
        ..shader = RadialGradient(
          colors: dark
              ? [const Color(0xFF25163D), Colors.black]
              : [const Color(0xFFEADFFC), const Color(0xFFF7F2FE)],
        ).createShader(Rect.fromCircle(center: center, radius: 130)),
    );
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-.5 + i * .6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 295, height: 180 + i * 18),
        Paint()
          ..color = (dark ? Colors.white : const Color(0xFFAB88D0)).withValues(
            alpha: .16,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
    for (var i = 0; i < 8; i++) {
      final at = center + Offset(cos(i * pi / 4) * 145, sin(i * pi / 4) * 128);
      canvas.drawCircle(
        at,
        i.isEven ? 3 : 2,
        Paint()
          ..color = [
            const Color(0xFFF1A9CE),
            const Color(0xFFB6A1EF),
            const Color(0xFF9BC6B8),
          ][i % 3],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.dark != dark;
}
