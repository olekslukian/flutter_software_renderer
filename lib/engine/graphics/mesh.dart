import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math_64.dart' as v64;

class Mesh {
  final List<v64.Vector3> vertices;
  final List<int> indices;

  Mesh({required this.vertices, required this.indices});

  /// Loads an .obj file from Flutter assets and parses its geometry.
  static Future<Mesh> loadFromAsset(String assetPath) async {
    final String content = await rootBundle.loadString(assetPath);
    return _parseObj(content);
  }

  static Mesh _parseObj(String objText) {
    final List<v64.Vector3> parsedVertices = [];
    final List<int> parsedIndices = [];

    final List<String> lines = objText.split('\n');

    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final List<String> parts = line.split(RegExp(r'\s+'));
      final String header = parts[0];

      if (header == 'v') {
        final double x = double.parse(parts[1]);
        final double y = double.parse(parts[2]);
        final double z = double.parse(parts[3]);
        parsedVertices.add(v64.Vector3(x, y, z));
      } else if (header == 'f') {
        final List<int> faceIndices = [];

        for (int i = 1; i < parts.length; i++) {
          final String vertexPart = parts[i].split('/')[0];

          final int index = int.parse(vertexPart) - 1;
          faceIndices.add(index);
        }

        for (int i = 1; i < faceIndices.length - 1; i++) {
          parsedIndices.add(faceIndices[0]);
          parsedIndices.add(faceIndices[i]);
          parsedIndices.add(faceIndices[i + 1]);
        }
      }
    }

    return Mesh(vertices: parsedVertices, indices: parsedIndices);
  }
}
