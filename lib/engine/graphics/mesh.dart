import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:vector_math/vector_math_64.dart' as v64;

class Mesh {
  Mesh({required this.vertices, required this.indices}) {
    _validate();
  }

  factory Mesh.fromObj(String objText) {
    final parsedVertices = <v64.Vector3>[];
    final parsedIndices = <int>[];
    final lines = objText.split('\n');

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex].trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final parts = line.split(RegExp(r'\s+'));
      final header = parts[0];
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
        final faceIndices = <int>[];
        for (final part in parts.skip(1)) {
          if (part.startsWith('#')) {
            break;
          }
          final objIndex = int.parse(part.split('/').first);
          final vertexIndex = objIndex > 0
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
        for (var index = 1; index < faceIndices.length - 1; index++) {
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

  static Future<Mesh> loadFromAsset(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    return Mesh.fromObj(content);
  }

  final List<v64.Vector3> vertices;

  final List<int> indices;

  Mesh normalized({double targetExtent = 2.0}) {
    if (!targetExtent.isFinite || targetExtent <= 0.0) {
      throw ArgumentError.value(
        targetExtent,
        'targetExtent',
        'must be finite and positive',
      );
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var minZ = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    var maxZ = double.negativeInfinity;
    for (final vertex in vertices) {
      minX = math.min(minX, vertex.x);
      minY = math.min(minY, vertex.y);
      minZ = math.min(minZ, vertex.z);
      maxX = math.max(maxX, vertex.x);
      maxY = math.max(maxY, vertex.y);
      maxZ = math.max(maxZ, vertex.z);
    }

    final largestExtent = math.max(
      maxX - minX,
      math.max(maxY - minY, maxZ - minZ),
    );
    if (largestExtent == 0.0) {
      throw ArgumentError('Mesh vertices must span a non-zero volume.');
    }

    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;
    final centerZ = (minZ + maxZ) / 2.0;
    final scale = targetExtent / largestExtent;
    return Mesh(
      vertices: vertices
          .map(
            (vertex) => v64.Vector3(
              (vertex.x - centerX) * scale,
              (vertex.y - centerY) * scale,
              (vertex.z - centerZ) * scale,
            ),
          )
          .toList(growable: false),
      indices: List<int>.of(indices),
    );
  }

  void _validate() {
    if (vertices.isEmpty) {
      throw ArgumentError('Mesh must contain at least one vertex.');
    }
    if (indices.length % 3 != 0) {
      throw ArgumentError('Mesh indices must contain complete triangles.');
    }
    for (final index in indices) {
      if (index < 0 || index >= vertices.length) {
        throw ArgumentError.value(index, 'indices', 'is out of range');
      }
    }
    for (final vertex in vertices) {
      if (!vertex.x.isFinite || !vertex.y.isFinite || !vertex.z.isFinite) {
        throw ArgumentError('Mesh vertices must have finite coordinates.');
      }
    }
  }
}
