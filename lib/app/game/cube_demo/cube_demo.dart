import 'dart:ui';

import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/app/game/cube_demo/cube.dart';

class CubeDemo extends Game {
  CubeDemo({super.backgroundColor});

  late final Cube _cube;

  @override
  void initialize() {
    _cube = Cube();
  }

  @override
  void update(double deltaTime) {
    _cube.update(deltaTime);
  }

  @override
  void render(Canvas canvas, Size size) {
    _cube.render(canvas, size);
  }
}
