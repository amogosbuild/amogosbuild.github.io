// Arcade scenes draw the bundled Amogus sprite and red imposters directly on canvas.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_engine.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.engine,
    required this.sprite,
    required this.dark,
    super.repaint,
  });
  final GameEngine engine;
  final ui.Image? sprite;
  final bool dark;
  final _spritePaints = <Color?, Paint>{};
  final _fill = Paint();
  late Canvas c;
  late Size s;
  final palette = const [
    Color(0xFFEFAA88),
    Color(0xFFB2A1E9),
    Color(0xFFA8C9B0),
    Color(0xFFE3B6C4),
    Color(0xFF9EBED6),
    Color(0xFFD5C38C),
    Color(0xFFA1A5C4),
    Color(0xFF92B6B4),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    c = canvas;
    s = size;
    c.drawRect(
      Offset.zero & s,
      Paint()..color = dark ? const Color(0xFF10151E) : const Color(0xFFE7EFFB),
    );
    if (engine is FlappyEngine) _flappy(engine as FlappyEngine);
    if (engine is CrossyEngine) _crossy(engine as CrossyEngine);
    if (engine is HiddenEngine) _hidden(engine as HiddenEngine);
    if (engine is TakedownEngine) _takedown(engine as TakedownEngine);
  }

  void rect(
    double x,
    double y,
    double w,
    double h,
    Color color, {
    double radius = 0,
  }) {
    final r = Rect.fromLTWH(
      x * s.width,
      y * s.height,
      w * s.width,
      h * s.height,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(radius)),
      _fill..color = color,
    );
  }

  void mascot(
    Offset at,
    double width, {
    Color? tint,
    double angle = 0,
    bool mirror = false,
  }) {
    final image = sprite;
    if (image == null) return;
    final w = width * s.width, h = w * image.height / image.width;
    c.save();
    c.translate(at.dx * s.width, at.dy * s.height);
    c.rotate(angle);
    if (mirror) c.scale(-1, 1);
    final paint = _spritePaints.putIfAbsent(tint, () {
      final value = Paint()..filterQuality = FilterQuality.low;
      if (tint != null) {
        value.colorFilter = ColorFilter.matrix([
          tint.r,
          0,
          0,
          0,
          0,
          0,
          tint.g,
          0,
          0,
          0,
          0,
          0,
          tint.b,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      }
      return value;
    });

    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      paint,
    );
    c.restore();
  }

  void _flappy(FlappyEngine e) {
    for (var i = 0; i < 6; i++) {
      final x = ((i * .23 - e.time * .025) % 1.4) - .1;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x * s.width, (.16 + (i % 3) * .12) * s.height),
          width: 110,
          height: 28,
        ),
        Paint()
          ..color = dark
              ? Colors.white.withValues(alpha: .035)
              : Colors.white.withValues(alpha: .65),
      );
    }
    for (final pipe in e.pipes) {
      final color = dark ? const Color(0xFF6955A1) : const Color(0xFFB2A3E1);
      rect(
        pipe.x,
        0,
        FlappyEngine.pipeWidth,
        pipe.gap - FlappyEngine.halfGap,
        color,
        radius: 12,
      );
      rect(
        pipe.x,
        pipe.gap + FlappyEngine.halfGap,
        FlappyEngine.pipeWidth,
        1 - pipe.gap - FlappyEngine.halfGap,
        color,
        radius: 12,
      );
      rect(
        pipe.x - .007,
        pipe.gap - FlappyEngine.halfGap - .027,
        FlappyEngine.pipeWidth + .014,
        .027,
        const Color(0xFF8E77C6),
        radius: 5,
      );
      rect(
        pipe.x - .007,
        pipe.gap + FlappyEngine.halfGap,
        FlappyEngine.pipeWidth + .014,
        .027,
        const Color(0xFF8E77C6),
        radius: 5,
      );
    }
    rect(
      0,
      .9,
      1,
      .1,
      dark ? const Color(0xFF22382E) : const Color(0xFFBFD7B7),
    );
    mascot(
      Offset(FlappyEngine.playerX, e.y),
      .06,
      angle: e.started ? (e.velocity * .8).clamp(-.4, .8) : 0,
    );
  }

  void _crossy(CrossyEngine e) {
    for (var row = 0; row < 9; row++) {
      final road = CrossyEngine.roads.contains(row);
      rect(
        0,
        row / 9,
        1,
        1 / 9,
        road
            ? (dark ? const Color(0xFF272B36) : const Color(0xFF7B8192))
            : (dark ? const Color(0xFF294234) : const Color(0xFFBED7AF)),
      );
      if (road) {
        for (var i = 0; i < 12; i++) {
          rect(
            i * .1,
            row / 9 + .052,
            .045,
            .006,
            Colors.white.withValues(alpha: .35),
            radius: 2,
          );
        }
        for (var car = 0; car < 4; car++) {
          final x = e.carPosition(row, car);
          rect(
            x,
            row / 9 + .02,
            .13,
            .07,
            palette[(row + car) % palette.length],
            radius: 9,
          );
          rect(
            x + .025,
            row / 9 + .028,
            .06,
            .045,
            const Color(0xFF3A435A),
            radius: 4,
          );
        }
      } else {
        for (var i = 0; i < 6; i++) {
          final x = (i * .193 + row * .127) % 1;
          rect(
            x,
            row / 9 + .032,
            .008,
            .025,
            dark ? const Color(0xFF3F6450) : const Color(0xFF91B383),
            radius: 2,
          );
        }
      }
    }
    mascot(Offset((e.column + .5) / 11, (e.row + .5) / 9), .057);
  }

  void _hidden(HiddenEngine e) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = LinearGradient(
          colors: dark
              ? [const Color(0xFF191629), const Color(0xFF222635)]
              : [const Color(0xFFE9DBEA), const Color(0xFFDFEAF5)],
        ).createShader(Offset.zero & s),
    );
    for (var i = 0; i < 9; i++) {
      rect(
        i / 8,
        .1,
        .007,
        .78,
        dark ? const Color(0xFF343044) : const Color(0xFFC9BECE),
      );
      rect(
        0,
        .24 + i * .085,
        1,
        .004,
        dark ? const Color(0xFF2D2A3B) : const Color(0xFFD2C7D9),
      );
    }
    for (final decoy in e.crowd) {
      mascot(
        decoy.point,
        decoy.scale,
        tint: palette[decoy.tint],
        mirror: decoy.tint.isEven,
        angle: (decoy.tint - 3) * .045,
      );
    }
    mascot(e.target, e.targetWidth);
    for (var i = 0; i < 12; i++) {
      final x = ((i * .171) + .03) % 1;
      final y = .27 + (i % 4) * .17;
      rect(
        x,
        y,
        .045,
        .025,
        dark ? const Color(0xFF52506C) : const Color(0xFFC4A2B6),
        radius: 3,
      );
      rect(
        x + .008,
        y - .02,
        .025,
        .02,
        dark ? const Color(0xFF77738A) : const Color(0xFFDCC4A8),
        radius: 3,
      );
    }
    rect(
      0,
      .94,
      1,
      .06,
      dark ? const Color(0xFF1D1C27) : const Color(0xFFD1C3DD),
    );
  }

  void _takedown(TakedownEngine e) {
    for (var i = 0; i < 40; i++) {
      final p = Offset(
        ((i * 73.7) % 100) / 100 * s.width,
        ((i * 41.1) % 100) / 100 * s.height,
      );
      c.drawCircle(
        p,
        i % 3 == 0 ? 2 : 1,
        Paint()
          ..color = (dark ? Colors.white : const Color(0xFF7C82A7)).withValues(
            alpha: .25,
          ),
      );
    }
    for (final enemy in e.enemies) {
      mascot(
        enemy.position,
        .1,
        tint: enemy.red ? const Color(0xFFFF3447) : null,
        angle: sin(e.time * 2 + enemy.wobble) * .12,
      );
    }
    for (final at in e.sparks) {
      for (var i = 0; i < 8; i++) {
        final p = Offset(
          at.dx * s.width + cos(i * pi / 4) * (1 - e.sparkLife / .35) * 55,
          at.dy * s.height + sin(i * pi / 4) * (1 - e.sparkLife / .35) * 55,
        );
        c.drawCircle(
          p,
          4,
          Paint()
            ..color = const Color(0xFFFFA7CF)
                .withValues(alpha: (e.sparkLife / .35).clamp(0, 1)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) =>
      engine != oldDelegate.engine ||
      sprite != oldDelegate.sprite ||
      dark != oldDelegate.dark;
}
