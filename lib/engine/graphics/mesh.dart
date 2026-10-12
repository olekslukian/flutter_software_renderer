import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math_64.dart' as v64;

/// Indexed triangle geometry loaded from the vertex and face data of a Wavefront
/// OBJ model.
class Mesh {
  /// Creates a mesh from [vertices] and a flattened triangle [indices] list.
  ///
  /// Every consecutive group of three indices describes one triangle.
  Mesh({required this.vertices, required this.indices});

  /// Loads and parses an OBJ file registered as a Flutter asset.
  static Future<Mesh> loadFromAsset(String assetPath) async {
    final String content = await rootBundle.loadString(assetPath);
    return Mesh.fromObj(content);
  }

  /// Parses positions and polygon faces from OBJ source text.
  ///
  /// Faces are triangulated as a fan. Positive indices are one-based and
  /// negative indices are resolved relative to the vertices declared so far.
  /// Texture coordinates and normals are ignored.
  factory Mesh.fromObj(String objText) {
    final List<v64.Vector3> parsedVertices = [];
    final List<int> parsedIndices = [];
    final List<String> lines = objText.split('\n');

    for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final String line = lines[lineIndex].trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final List<String> parts = line.split(RegExp(r'\s+'));
      final String header = parts[0];
      if (header == 'v') {
        if (parts.length < 4) {
          throw FormatException('Invalid vertex at line ${lineIndex + 1}.');
        }
        parsedVertices.add(
          v64.Vector3(
            double.parse(parts[1]),
            double.parse(parts[2]),
            double.parse(parts[3]),
          ),
        );
      } else if (header == 'f') {
        final List<int> faceIndices = [];
        for (final String part in parts.skip(1)) {
          if (part.startsWith('#')) break;
          final int objIndex = int.parse(part.split('/').first);
          final int vertexIndex = objIndex > 0
              ? objIndex - 1
              : parsedVertices.length + objIndex;
          if (vertexIndex < 0 || vertexIndex >= parsedVertices.length) {
            throw FormatException(
              'Face index $objIndex is out of range at line ${lineIndex + 1}.',
            );
          }
          faceIndices.add(vertexIndex);
        }

        if (faceIndices.length < 3) {
          throw FormatException('Invalid face at line ${lineIndex + 1}.');
        }
        for (int index = 1; index < faceIndices.length - 1; index++) {
          parsedIndices
            ..add(faceIndices[0])
            ..add(faceIndices[index])
            ..add(faceIndices[index + 1]);
        }
      }
    }

    if (parsedVertices.isEmpty || parsedIndices.isEmpty) {
      throw const FormatException(
        'OBJ model contains no renderable triangles.',
      );
    }
    return Mesh(vertices: parsedVertices, indices: parsedIndices);
  }

  /// The model's local-space vertex positions.
  final List<v64.Vector3> vertices;

  /// Flattened vertex indices, with each consecutive triple forming a
  /// triangle.
  final List<int> indices;
}
