import 'dart:ui';

import 'package:flutter_software_renderer/engine/graphics/renderer.dart';

abstract class Game {
  Game({
    this.clearColor = const Color(0xFF000000),
    this.width = 320,
    this.height = 240,
  });

  Color clearColor;

  final int width;

  final int height;

  Future<void> initialize();

  void update(double deltaTime);

  void render(Renderer renderer);
}
