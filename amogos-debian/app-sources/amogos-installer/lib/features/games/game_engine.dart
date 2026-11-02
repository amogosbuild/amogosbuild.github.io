// Independent bounded arcade simulations keep collisions and user-controlled retries testable.
import 'dart:math';
import 'dart:ui';

enum ArcadeGame { flappy, crossy, hidden, takedown }

extension ArcadeGameInfo on ArcadeGame {
  String get title => [
    'Flappy Amogus',
    'Crossy Amogus',
    'Where is Amogus?',
    'Imposter Take Down',
  ][index];
  String get instructions => [
    'Tap or press Space to fly. Mind the gaps.',
    'Arrow keys or WASD to hop. Avoid the traffic.',
    'Find the original pale-blue Amogus before time runs out.',
    'Tap the red imposters. Leave the blue Amogus alone.',
  ][index];
}

abstract class GameEngine {
  GameEngine(this.random);
  final Random random;
  bool lost = false, started = false;
  int score = 0;
  double time = 0;
  void update(double dt);
  void tap(Offset point);
  void move(int dx, int dy) {}
}

class Pipe {
  Pipe(this.x, this.gap);
  double x, gap;
  bool counted = false;
}

class FlappyEngine extends GameEngine {
  FlappyEngine(super.random) {
    for (var i = 0; i < 4; i++) {
      pipes.add(Pipe(1.05 + i * .43, .3 + random.nextDouble() * .35));
    }
  }
  double y = .45, velocity = 0;
  final List<Pipe> pipes = [];
  static const playerX = .24,
      radiusX = .03,
      radiusY = .07,
      pipeWidth = .085,
      halfGap = .16;
  @override
  void tap(Offset point) {
    if (!lost) {
      started = true;
      velocity = -.46;
    }
  }

  @override
  void update(double dt) {
    if (!started || lost) return;
    time += dt;
    velocity += 1.13 * dt;
    y += velocity * dt;
    if (y < radiusY || y > .9 - radiusY) lost = true;
    for (final pipe in pipes) {
      pipe.x -= (.19 + min(score, 15) * .004) * dt;
      if (pipe.x + pipeWidth < 0) {
        pipe.x += pipes.length * .43;
        pipe.gap = .3 + random.nextDouble() * .35;
        pipe.counted = false;
      }
      if (!pipe.counted && pipe.x + pipeWidth < playerX) {
        score++;
        pipe.counted = true;
      }
      if (pipe.x < playerX + radiusX &&
          pipe.x + pipeWidth > playerX - radiusX &&
          (y - radiusY < pipe.gap - halfGap ||
              y + radiusY > pipe.gap + halfGap)) {
        lost = true;
      }
    }
  }
}

class CrossyEngine extends GameEngine {
  CrossyEngine(super.random);
  int column = 5, row = 8;
  static const roads = [1, 2, 4, 5, 7];
  double carPosition(int lane, int car) =>
      ((car * .39 +
              (lane.isEven ? 1 : -1) * time * (.095 + lane * .008) +
              lane * .17) %
          1.25) -
      .15;
  @override
  void move(int dx, int dy) {
    if (lost) return;
    started = true;
    column = (column + dx).clamp(0, 10);
    row = (row + dy).clamp(0, 8);
    if (dy < 0) score++;
    if (row == 0) {
      row = 8;
      score += 5;
    }
    _collisions();
  }

  void _collisions() {
    if (!roads.contains(row)) return;
    final x = (column + .5) / 11;
    for (var car = 0; car < 4; car++) {
      final p = carPosition(row, car);
      if (x + .025 > p && x - .025 < p + .13) lost = true;
    }
  }

  @override
  void tap(Offset point) => move(0, -1);
  @override
  void update(double dt) {
    if (started && !lost) {
      time += dt;
      _collisions();
    }
  }
}

class HiddenDecoy {
  HiddenDecoy(this.point, this.tint, this.scale);
  final Offset point;
  final int tint;
  final double scale;
}

class HiddenEngine extends GameEngine {
  HiddenEngine(super.random) {
    _round();
  }
  Offset target = Offset.zero;
  double remaining = 25;
  final List<HiddenDecoy> crowd = [];
  double get targetWidth => max(.032, .055 - score * .003);
  void _round() {
    remaining = 25;
    crowd.clear();
    target = Offset(
      .09 + random.nextDouble() * .82,
      .18 + random.nextDouble() * .67,
    );
    for (var i = 0; i < 95; i++) {
      var point = Offset(
        .04 + random.nextDouble() * .92,
        .13 + random.nextDouble() * .75,
      );
      if ((point - target).distance < .075) {
        point = Offset((point.dx + .2) % .9, point.dy);
      }
      crowd.add(HiddenDecoy(point, i % 8, .035 + random.nextDouble() * .025));
    }
  }

  @override
  void tap(Offset point) {
    if (lost) return;
    started = true;
    if ((point.dx - target.dx).abs() < targetWidth * .75 &&
        (point.dy - target.dy).abs() < targetWidth) {
      score++;
      _round();
    } else {
      remaining = max(0, remaining - 2);
    }
  }

  @override
  void update(double dt) {
    if (!started || lost) return;
    time += dt;
    remaining -= dt;
    if (remaining <= 0) {
      remaining = 0;
      lost = true;
    }
  }
}

class Imposter {
  Imposter(this.position, this.speed, this.red, this.wobble);
  Offset position;
  final double speed, wobble;
  final bool red;
}

class TakedownEngine extends GameEngine {
  TakedownEngine(super.random);
  final List<Imposter> enemies = [];
  final List<Offset> sparks = [];
  int misses = 0;
  double spawn = 0, sparkLife = 0;
  @override
  void tap(Offset point) {
    if (lost) return;
    started = true;
    for (final enemy in enemies.reversed) {
      if ((point.dx - enemy.position.dx).abs() < .065 &&
          (point.dy - enemy.position.dy).abs() < .095) {
        if (!enemy.red) {
          lost = true;
          return;
        }
        score++;
        if (sparks.length == 8) sparks.removeAt(0);
        sparks.add(enemy.position);
        sparkLife = .35;
        enemies.remove(enemy);
        break;
      }
    }
  }

  @override
  void update(double dt) {
    if (!started || lost) return;
    time += dt;
    spawn -= dt;
    sparkLife -= dt;
    if (sparkLife <= 0) sparks.clear();
    if (spawn <= 0 && enemies.length < 24) {
      spawn = max(.3, .85 - score * .012);
      enemies.add(
        Imposter(
          Offset(.1 + random.nextDouble() * .8, 1.1),
          .13 + random.nextDouble() * .09 + score * .002,
          random.nextDouble() < .78,
          random.nextDouble() * 6,
        ),
      );
    }
    for (var i = enemies.length - 1; i >= 0; i--) {
      final enemy = enemies[i];
      enemy.position = Offset(
        enemy.position.dx + sin(time * 2 + enemy.wobble) * dt * .025,
        enemy.position.dy - enemy.speed * dt,
      );
      if (enemy.position.dy < -.1) {
        if (enemy.red) misses++;
        enemies.removeAt(i);
      }
    }
    if (misses >= 3) lost = true;
  }
}

GameEngine createGame(ArcadeGame game, {int? seed}) {
  final random = Random(seed);
  return switch (game) {
    ArcadeGame.flappy => FlappyEngine(random),
    ArcadeGame.crossy => CrossyEngine(random),
    ArcadeGame.hidden => HiddenEngine(random),
    ArcadeGame.takedown => TakedownEngine(random),
  };
}
