import 'package:flutter/services.dart' show rootBundle;
import 'package:software_engine/game.dart';

final class FlutterAssetLoader implements AssetLoader {
  const FlutterAssetLoader();

  @override
  Future<String> loadString(String path) => rootBundle.loadString(path);
}
