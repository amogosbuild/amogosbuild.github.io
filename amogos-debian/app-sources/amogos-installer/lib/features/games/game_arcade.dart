// The arcade retries the selected game and suspends its bounded render loop when inactive.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game_engine.dart';
import 'arcade_loop.dart';
import 'game_painter.dart';

class GameArcade extends StatefulWidget {
  const GameArcade({super.key, this.paused = false});
  final bool paused;
  @override
  State<GameArcade> createState() => _GameArcadeState();
}

class _GameArcadeState extends State<GameArcade>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  ArcadeGame selected = ArcadeGame.flappy;
  late GameEngine engine = createGame(selected);
  late final Ticker ticker;
  Timer? countdown;
  final focus = FocusNode();
  late ArcadeLoop loop;
  Object? hud;
  bool applicationActive = true, tickerEnabled = true;
  ui.Image? sprite;
  bool paused = false;
  @override
  void initState() {
    super.initState();
    _load();
    loop = ArcadeLoop(engine);
    ticker = createTicker((elapsed) {
      if (!_running) {
        _syncTicker();
        return;
      }
      if (loop.advance(elapsed)) _refresh(paint: false);
    });
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) focus.requestFocus();
    });
  }

  bool get _running =>
      applicationActive &&
      tickerEnabled &&
      !paused &&
      !widget.paused &&
      engine.started &&
      !engine.lost;

  void _syncTicker() {
    if (_running && engine is HiddenEngine) {
      ticker.stop();
      countdown ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!_running) {
          _syncTicker();
          return;
        }
        engine.update(1);
        _refresh(paint: false);
      });
      return;
    }
    countdown?.cancel();
    countdown = null;
    if (_running && !ticker.isActive) {
      loop.resetTime();
      ticker.start();
    } else if (!_running && ticker.isActive) {
      ticker.stop();
      loop.resetTime();
    }
  }

  void _refresh({bool paint = true}) {
    if (paint) loop.repaint();
    final next = (
      engine.score,
      engine.started,
      engine.lost,
      engine is HiddenEngine ? (engine as HiddenEngine).remaining.ceil() : 0,
      engine is TakedownEngine ? (engine as TakedownEngine).misses : 0,
    );
    if (hud != next && mounted) setState(() => hud = next);
    _syncTicker();
  }

  void _tap(ui.Offset point) {
    if (paused || widget.paused || !applicationActive || engine.lost) return;
    engine.tap(point);
    _refresh();
  }

  void _move(int dx, int dy) {
    if (paused || widget.paused || !applicationActive || engine.lost) return;
    engine.move(dx, dy);
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    tickerEnabled = TickerMode.of(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant GameArcade oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    applicationActive = state == AppLifecycleState.resumed;
    _syncTicker();
  }

  Future<void> _load() async {
    final data = await rootBundle.load('assets/images/amogus.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 240,
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (mounted) {
      setState(() => sprite = frame.image);
    } else {
      frame.image.dispose();
    }
  }

  void _select(ArcadeGame game) {
    setState(() {
      selected = game;
      ticker.stop();
      countdown?.cancel();
      countdown = null;
      loop.dispose();
      engine = createGame(game);
      loop = ArcadeLoop(engine);
      hud = null;
      paused = false;
    });
    focus.requestFocus();
  }

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (paused || widget.paused || !applicationActive) {
      return KeyEventResult.ignored;
    }
    final key = e.logicalKey;
    if (engine.lost && key == LogicalKeyboardKey.enter) {
      _select(selected);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _tap(const ui.Offset(.5, .5));
      return KeyEventResult.handled;
    }
    final move = {
      LogicalKeyboardKey.arrowUp: (0, -1),
      LogicalKeyboardKey.keyW: (0, -1),
      LogicalKeyboardKey.arrowDown: (0, 1),
      LogicalKeyboardKey.keyS: (0, 1),
      LogicalKeyboardKey.arrowLeft: (-1, 0),
      LogicalKeyboardKey.keyA: (-1, 0),
      LogicalKeyboardKey.arrowRight: (1, 0),
      LogicalKeyboardKey.keyD: (1, 0),
    }[key];
    if (move != null) {
      _move(move.$1, move.$2);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'A little fun while we unpack.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: paused ? 'Resume game' : 'Pause game',
              onPressed: () {
                setState(() => paused = !paused);
                _syncTicker();
              },
              icon: Icon(
                paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final game in ArcadeGame.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      game.title,
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: selected == game,
                    onSelected: (_) => _select(game),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Focus(
            focusNode: focus,
            onKeyEvent: _key,
            child: LayoutBuilder(
              builder: (context, size) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  focus.requestFocus();
                  if (!paused && !widget.paused) {
                    _tap(
                      ui.Offset(
                        d.localPosition.dx / size.maxWidth,
                        d.localPosition.dy / size.maxHeight,
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          painter: GamePainter(
                            repaint: loop,
                            engine: engine,
                            sprite: sprite,
                            dark:
                                Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        left: 14,
                        child: _badge('SCORE  ${engine.score}'),
                      ),
                      if (engine is HiddenEngine)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _badge(
                            '${(engine as HiddenEngine).remaining.ceil()}s',
                          ),
                        ),
                      if (engine is TakedownEngine)
                        Positioned(
                          top: 14,
                          right: 14,
                          child: _badge(
                            '♥  ${3 - (engine as TakedownEngine).misses}',
                          ),
                        ),
                      if (!engine.started)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .65),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Text(
                              'Tap to start',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      if (engine.lost)
                        Container(
                          color: Colors.black.withValues(alpha: .65),
                          child: Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFFFFA7CF),
                                    size: 34,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Nice try, Amogus.',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 23,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Try again or choose another game above.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () => _select(selected),
                                    icon: const Icon(Icons.replay_rounded),
                                    label: const Text('Try again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (paused || widget.paused)
                        Container(
                          color: Colors.black.withValues(alpha: .6),
                          child: const Center(
                            child: Text(
                              'Game paused',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                selected.instructions,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ),
            if (selected == ArcadeGame.crossy) ...[
              for (final d in [
                (-1, 0, Icons.arrow_back_rounded),
                (0, -1, Icons.arrow_upward_rounded),
                (0, 1, Icons.arrow_downward_rounded),
                (1, 0, Icons.arrow_forward_rounded),
              ])
                IconButton(
                  tooltip: 'Hop',
                  visualDensity: VisualDensity.compact,
                  iconSize: 19,
                  onPressed: () => _move(d.$1, d.$2),
                  icon: Icon(d.$3),
                ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    countdown?.cancel();
    loop.dispose();
    focus.dispose();
    sprite?.dispose();
    super.dispose();
  }
}
