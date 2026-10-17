import 'dart:io';

import 'package:software_engine/game.dart';

final class FileAssetLoader implements AssetLoader {
  const FileAssetLoader(this.root);

  final String root;

  @override
  Future<String> loadString(String path) => File('$root/$path').readAsString();
}
