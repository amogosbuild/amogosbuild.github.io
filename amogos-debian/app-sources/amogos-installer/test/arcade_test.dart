// Arcade tests verify collision outcomes and safe progression for each game.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:amogos_installer/features/games/game_engine.dart';

void main() {
  test('Flappy loses on ground collision and a flap changes velocity', () {
    final game = FlappyEngine(Random(1));
    game.tap(Offset.zero);
    expect(game.velocity, lessThan(0));
    for (var i = 0; i < 300; i++) {
      game.update(.02);
    }
    expect(game.lost, isTrue);
  });
  test('Crossy cannot move beyond the playfield', () {
    final game = CrossyEngine(Random(1));
    for (var i = 0; i < 30; i++) {
      game.move(-1, 0);
    }
    expect(game.column, 0);
    game.move(0, -1);
    expect(game.score, 1);
  });
  test(
    'Hidden Amogus rewards a correct target and loses when time expires',
    () {
      final game = HiddenEngine(Random(2));
      game.tap(game.target);
      expect(game.score, 1);
      game.update(26);
      expect(game.lost, isTrue);
    },
  );
  test('Red imposters score and blue Amogus must be protected', () {
    final game = TakedownEngine(Random(3));
    game.enemies.add(Imposter(const Offset(.5, .5), .1, true, 0));
    game.tap(const Offset(.5, .5));
    expect(game.score, 1);
    game.enemies.add(Imposter(const Offset(.5, .5), .1, false, 0));
    game.tap(const Offset(.5, .5));
    expect(game.lost, isTrue);
  });
}
