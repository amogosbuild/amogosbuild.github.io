// Fixed simulation steps cap rendering at 30 fps and keep idle or static scenes quiet.
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'game_engine.dart';

class ArcadeLoop extends ChangeNotifier {
  ArcadeLoop(this.engine);
  final GameEngine engine;
  static const frameSeconds = 1 / 30, stepSeconds = 1 / 60;
  Duration? _last;
  double _frame = 0, _simulation = 0;
  void resetTime() {
    _last = null;
    _frame = 0;
    _simulation = 0;
  }

  void repaint() => notifyListeners();
  bool advance(Duration elapsed) {
    final previous = _last;
    _last = elapsed;
    if (previous == null || !engine.started || engine.lost) return false;
    _frame += max(0, (elapsed - previous).inMicroseconds / 1000000);
    if (_frame + .000002 < frameSeconds) return false;
    _simulation += min(_frame, .1);
    _frame = 0;
    final score = engine.score;
    var steps = 0;
    while (_simulation + .000002 >= stepSeconds && steps < 6 && !engine.lost) {
      engine.update(stepSeconds);
      _simulation = max(0, _simulation - stepSeconds);
      steps++;
    }
    if (engine is! HiddenEngine || engine.score != score || engine.lost) {
      notifyListeners();
    }
    return true;
  }
}
