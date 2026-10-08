import 'dart:ui';

abstract class Game {
  Game({this.backgroundColor = const Color(0xFF000000)});

  Color backgroundColor;

  void initialize();
  void update(double deltaTime);
  void render(Canvas canvas, Size size);
}
