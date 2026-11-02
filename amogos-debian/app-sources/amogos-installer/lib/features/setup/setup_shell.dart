// Setup keeps navigation, music and the gradient progress pill accessible at compact sizes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/controllers/install_controller.dart';
import '../music/music_controller.dart';
import '../music/music_dialog.dart';
import 'pages/welcome_page.dart';
import 'pages/preferences_pages.dart';
import 'pages/storage_page.dart';
import 'pages/review_page.dart';
import 'pages/install_page.dart';

class SetupShell extends StatefulWidget {
  const SetupShell({super.key, required this.controller, required this.music});
  final InstallController controller;
  final MusicController music;
  @override
  State<SetupShell> createState() => _SetupShellState();
}

class _SetupShellState extends State<SetupShell> {
  bool musicOpen = false;
  Future<void> _music() async {
    setState(() => musicOpen = true);
    await showMusicDialog(context, widget.music);
    if (mounted) setState(() => musicOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller, colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 900 || box.maxHeight < 620;
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 12 : 28,
                      vertical: compact ? 4 : 16,
                    ),
                    child: Row(
                      children: [
                        if (!compact) ...[
                          Image.asset(
                            'assets/images/amogus.png',
                            cacheWidth: 80,
                            width: 38,
                            height: 38,
                          ),
                          const SizedBox(width: 11),
                        ],
                        Expanded(
                          child: Text(
                            'AmogOS 2 Pro',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: compact ? 17 : 20),
                          ),
                        ),
                        if (c.preview && !compact)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: Text(
                              'DESIGN PREVIEW · SAMPLE HARDWARE',
                              style: TextStyle(
                                fontSize: 8,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ListenableBuilder(
                          listenable: widget.music,
                          builder: (context, _) {
                            final icon = Icon(
                              widget.music.playing
                                  ? Icons.graphic_eq_rounded
                                  : widget.music.enabled
                                  ? Icons.headphones_rounded
                                  : Icons.music_off_rounded,
                            );
                            return compact
                                ? IconButton(
                                    tooltip: 'Your soundtrack',
                                    onPressed: _music,
                                    icon: icon,
                                  )
                                : OutlinedButton.icon(
                                    onPressed: _music,
                                    icon: icon,
                                    label: Text(
                                      widget.music.playing
                                          ? 'Now playing'
                                          : 'Your soundtrack',
                                    ),
                                  );
                          },
                        ),
                        IconButton(
                          tooltip: c.dark
                              ? 'Switch to light mode'
                              : 'Switch to pitch-black mode',
                          onPressed: c.toggleTheme,
                          icon: Icon(
                            c.dark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                        ),
                        if (!c.installing)
                          IconButton(
                            tooltip: 'Close installer',
                            onPressed: () => SystemNavigator.pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: colors.outlineVariant),
                  if (compact)
                    SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (
                            var i = 0;
                            i < InstallController.steps.length;
                            i++
                          )
                            _step(context, i, true),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!compact)
                          SizedBox(
                            width: 218,
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                26,
                                18,
                                16,
                              ),
                              children: [
                                Text(
                                  'YOUR NEXT CHAPTER',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.8,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                for (
                                  var i = 0;
                                  i < InstallController.steps.length;
                                  i++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _step(context, i, false),
                                  ),
                                const SizedBox(height: 35),
                                Text(
                                  'A little different.\nA little more you.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    height: 1.8,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!compact)
                          VerticalDivider(
                            width: 1,
                            color: colors.outlineVariant,
                          ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              compact ? 16 : 38,
                              compact ? 12 : 28,
                              compact ? 16 : 38,
                              12,
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: KeyedSubtree(
                                      key: ValueKey(c.step),
                                      child: _page(),
                                    ),
                                  ),
                                ),
                                if (c.error != null)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 80,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: colors.errorContainer
                                              .withValues(alpha: .4),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          c.error!,
                                          style: TextStyle(
                                            color: colors.error,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _footer(context, compact),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _page() {
    final c = widget.controller;
    return switch (c.step) {
      0 => const WelcomePage(),
      1 => LocationPage(controller: c),
      2 => KeyboardPage(controller: c),
      3 => StoragePage(controller: c),
      4 => AccountPage(controller: c),
      5 => ReviewPage(controller: c),
      _ => InstallPage(controller: c, musicOpen: musicOpen),
    };
  }

  Widget _step(BuildContext context, int i, bool compact) {
    final c = widget.controller, colors = Theme.of(context).colorScheme;
    final current = c.step == i, done = c.step > i || c.complete;
    final circle = Container(
      width: 25,
      height: 25,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: current
            ? colors.primary
            : done
            ? colors.primary.withValues(alpha: .12)
            : null,
        border: !current && !done
            ? Border.all(color: colors.outlineVariant)
            : null,
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 14, color: colors.primary)
          : Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 11,
                color: current ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
    );
    return Tooltip(
      message: InstallController.steps[i],
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: i < c.step && c.step < 6 && !c.busy
            ? () => c.change(() => c.step = i)
            : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 7 : 12,
          ),
          decoration: BoxDecoration(
            color: current ? colors.primary.withValues(alpha: .09) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: compact
              ? circle
              : Row(
                  children: [
                    circle,
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        InstallController.steps[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: current
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: current
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, bool compact) {
    final c = widget.controller, colors = Theme.of(context).colorScheme;
    final back = c.step > 0 && c.step < 6
        ? TextButton.icon(
            onPressed: c.busy ? null : c.back,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Go back'),
          )
        : const SizedBox.shrink();
    final next = FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: colors.onSurface,
        foregroundColor: colors.surface,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 12 : 20,
        ),
      ),
      onPressed: c.busy || c.installing || c.event.error
          ? null
          : c.complete
          ? (c.preview ? null : c.service.reboot)
          : c.step == 5
          ? () => confirmInstallation(context, c)
          : c.next,
      icon: c.busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              c.complete
                  ? Icons.restart_alt_rounded
                  : Icons.arrow_forward_rounded,
              size: 17,
            ),
      iconAlignment: IconAlignment.end,
      label: Text(
        c.complete
            ? (c.preview ? 'Preview complete' : 'Restart now')
            : c.step == 5
            ? 'Install AmogOS 2 Pro'
            : c.installing
            ? 'Installing…'
            : c.event.error
            ? 'Needs attention'
            : 'Continue',
        style: const TextStyle(fontSize: 12),
      ),
    );
    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        gradient: installGradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: .15),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: c.stageText,
                  child: Text(
                    c.stageText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                c.step < 6
                    ? 'Step ${c.step + 1} of 7'
                    : '${(c.event.progress * 100).round()}%',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 7),
          TweenAnimationBuilder<double>(
            tween: Tween(end: c.progress),
            duration: const Duration(milliseconds: 350),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              color: Colors.white,
              backgroundColor: Colors.white.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 28,
        compact ? 8 : 16,
        compact ? 16 : 28,
        compact ? 8 : 22,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                pill,
                const SizedBox(height: 6),
                Row(
                  children: [
                    back,
                    const Spacer(),
                    Flexible(flex: 3, child: next),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(width: 110, child: back),
                const SizedBox(width: 18),
                Expanded(child: pill),
                const SizedBox(width: 24),
                SizedBox(width: 205, child: next),
              ],
            ),
    );
  }
}
