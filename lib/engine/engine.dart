import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/engine/game.dart';

class Engine extends ChangeNotifier {
  Engine(this.game);

  final Game game;

  void initialize() {
    game.initialize();
  }

  void render(Canvas canvas, Size size) {
    game.render(canvas, size);
  }

  void update(double deltaTime) {
    game.update(deltaTime);
    notifyListeners();
  }

  Color get backgroundColor => game.backgroundColor;
}
