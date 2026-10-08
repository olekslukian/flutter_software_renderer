import 'software_framebuffer.dart';
import 'dart:ui';

abstract class Game {
  Game({
    this.clearColor = const Color(0xFF000000),
    this.width = 320,
    this.height = 240,
  });

  Color clearColor;
  final int width;
  final int height;

  void initialize();
  void update(double deltaTime);
  void render(SoftwareFramebuffer framebuffer);
}
