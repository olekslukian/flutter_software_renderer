import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/renderer.dart';

abstract class Game {
  Game({
    this.clearColor = const Color32.fromARGB32(0xFF000000),
    this.width = 320,
    this.height = 240,
  });

  Color32 clearColor;

  final int width;

  final int height;

  Future<void> initialize(AssetLoader assets);

  void update(double deltaTime);

  void render(Renderer renderer);
}

abstract interface class AssetLoader {
  Future<String> loadString(String path);
}
