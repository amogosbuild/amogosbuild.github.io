// Arcade regressions cover manual retry, bounded rendering, static scenes, and inactive lifecycle time.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_installer/features/games/arcade_loop.dart';
import 'package:amogos_installer/features/games/game_arcade.dart';
import 'package:amogos_installer/features/games/game_engine.dart';
import 'package:amogos_installer/features/games/game_painter.dart';

void main() {
  test('rendering is capped at 30 fps and uses fixed simulation steps', () {
    final engine = CrossyEngine(Random(1))..started = true;
    engine.row = 8;
    final loop = ArcadeLoop(engine);
    var paints = 0;
    loop.addListener(() => paints++);
    for (var i = 0; i <= 1200; i++) {
      loop.advance(Duration(microseconds: (i * 1000000 / 120).round()));
    }
    expect(paints, inInclusiveRange(299, 301));
    expect(engine.time, closeTo(10, .02));
    loop.dispose();
  });
  test('static hidden scene does not redraw for countdown and idle/lost games do no work', () {
    final engine = HiddenEngine(Random(1));
    final loop = ArcadeLoop(engine);
    var paints = 0;
    loop.addListener(() => paints++);
    for (var i = 0; i <= 60; i++) {
      loop.advance(Duration(milliseconds: i * 17));
    }
    expect(engine.time, 0);
    engine.started = true;
    loop.resetTime();
    for (var i = 0; i <= 60; i++) {
      loop.advance(Duration(milliseconds: i * 17));
    }
    expect(engine.remaining, lessThan(25));
    expect(paints, 0);
    engine.lost = true;
    final frozen = engine.time;
    for (var i = 61; i <= 180; i++) {
      loop.advance(Duration(milliseconds: i * 17));
    }
    expect(engine.time, frozen);
    expect(paints, 0);
    loop.dispose();
  });
  test(
    'resuming discards paused wall time and long stalls have bounded catch-up',
    () {
      final engine = CrossyEngine(Random(2))..started = true;
      final loop = ArcadeLoop(engine);
      loop.advance(Duration.zero);
      loop.advance(const Duration(milliseconds: 34));
      final before = engine.time;
      loop.resetTime();
      loop.advance(const Duration(seconds: 100));
      expect(engine.time, before);
      loop.advance(const Duration(seconds: 200));
      expect(engine.time - before, closeTo(.1, .0001));
      loop.dispose();
    },
  );

  testWidgets(
    'hidden countdown is quiet while paused and input stays blocked',
    (tester) async {
      final paused = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: paused,
              builder: (context, value, _) => GameArcade(paused: value),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Where is Amogus?'));
      await tester.pump();
      await tester.tap(find.text('Tap to start'));
      await tester.pump();
      final paints = find.byWidgetPredicate(
        (v) => v is CustomPaint && v.painter is GamePainter,
      );
      final engine =
          (tester.widget<CustomPaint>(paints).painter! as GamePainter).engine
              as HiddenEngine;
      final remaining = engine.remaining;
      await tester.pump(const Duration(seconds: 1));
      expect(engine.remaining, remaining - 1);
      paused.value = true;
      await tester.pump();
      final frozen = engine.remaining;
      await tester.pump(const Duration(seconds: 20));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(engine.remaining, frozen);
      paused.value = false;
      await tester.pump();
      expect(engine.remaining, frozen);
      await tester.pump(const Duration(seconds: 1));
      expect(engine.remaining, frozen - 1);
      await tester.pumpWidget(const SizedBox());
      paused.dispose();
    },
  );
  testWidgets('loss stays on the current game and retry resets that game', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(padding: EdgeInsets.all(16), child: GameArcade()),
        ),
      ),
    );
    await tester.pump();
    final paints = find.byWidgetPredicate(
      (v) => v is CustomPaint && v.painter is GamePainter,
    );
    var painter = tester.widget<CustomPaint>(paints).painter! as GamePainter;
    final engine = painter.engine as FlappyEngine;
    await tester.tap(find.text('Tap to start'));
    await tester.pump();
    engine.y = .95;
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Try again'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    painter = tester.widget<CustomPaint>(paints).painter! as GamePainter;
    expect(painter.engine, same(engine));
    expect(painter.engine.lost, isTrue);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    painter = tester.widget<CustomPaint>(paints).painter! as GamePainter;
    expect(painter.engine, isA<FlappyEngine>());
    expect(painter.engine, isNot(same(engine)));
    expect(painter.engine.lost, isFalse);
    expect(find.text('Tap to start'), findsOneWidget);
    await tester.tap(find.text('Crossy Amogus'));
    await tester.pump();
    expect(
      (tester.widget<CustomPaint>(paints).painter! as GamePainter).engine,
      isA<CrossyEngine>(),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'active gameplay repaints its canvas without rebuilding the arcade controls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GameArcade())),
      );
      await tester.pump();
      await tester.tap(find.text('Tap to start'));
      await tester.pump();
      final paints = find.byWidgetPredicate(
        (v) => v is CustomPaint && v.painter is GamePainter,
      );
      final painter = tester.widget<CustomPaint>(paints).painter!;
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
      expect(tester.widget<CustomPaint>(paints).painter, same(painter));
      await tester.tap(find.byTooltip('Pause game'));
      await tester.pump();
      final engine =
          (tester.widget<CustomPaint>(paints).painter! as GamePainter).engine;
      final time = engine.time;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(seconds: 5));
      expect(engine.time, time);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
