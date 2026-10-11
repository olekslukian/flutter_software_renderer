import 'dart:ui';

import 'graphics/rendering/renderer.dart';

/// Defines lifecycle and rendering hooks for engine-hosted game content.
abstract class Game {
  /// Creates a game with its clear color and software-rendering dimensions.
  Game({
    this.clearColor = const Color(0xFF000000),
    this.width = 320,
    this.height = 240,
  });

  /// The color used to clear each frame.
  Color clearColor;

  /// The width of the game's software-rendered image in pixels.
  final int width;

  /// The height of the game's software-rendered image in pixels.
  final int height;

  /// Initializes game state before the first update or render.
  void initialize();

  /// Advances game state by [deltaTime] seconds.
  void update(double deltaTime);

  /// Submits the current game state through the engine-owned [renderer].
  void render(Renderer renderer);
}
