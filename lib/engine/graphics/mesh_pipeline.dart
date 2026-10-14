import 'dart:ui';

import 'package:flutter_software_renderer/engine/errors/engine_exception.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/camera.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class MeshPipeline {
  final v64.Matrix4 _modelViewProjection = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();

  List<Offset> _screenPositions = const [];
  List<double> _depths = const [];

  List<Offset> get screenPositions => _screenPositions;

  List<double> get depths => _depths;

  int projectVertices(Mesh mesh, Transform3 transform, Camera camera) {
    _modelViewProjection
      ..setFrom(camera.viewProjectionMatrix)
      ..multiply(transform.matrix);

    final vertexCount = mesh.vertices.length;
    if (_screenPositions.length != vertexCount) {
      _screenPositions = List<Offset>.filled(vertexCount, Offset.zero);
      _depths = List<double>.filled(vertexCount, 1);
    }

    var unprojectableVertices = 0;
    for (var index = 0; index < vertexCount; index++) {
      final vertex = mesh.vertices[index];
      _clipPosition.setValues(vertex.x, vertex.y, vertex.z, 1);
      _modelViewProjection.transform(_clipPosition);
      try {
        final projected = camera.projectClipPosition(_clipPosition);
        _screenPositions[index] = projected.position;
        _depths[index] = projected.depth;
      } on ProjectionException {
        _screenPositions[index] = Offset.zero;
        _depths[index] = double.nan;
        unprojectableVertices++;
      }
    }
    return unprojectableVertices;
  }
}
