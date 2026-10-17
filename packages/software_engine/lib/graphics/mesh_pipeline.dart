import 'dart:typed_data';

import 'package:software_engine/errors/engine_exception.dart';
import 'package:software_engine/graphics/camera/camera.dart';
import 'package:software_engine/graphics/mesh.dart';
import 'package:software_engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class MeshPipeline {
  final v64.Matrix4 _modelViewProjection = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();

  Float64List _screenX = Float64List(0);
  Float64List _screenY = Float64List(0);
  Float64List _depths = Float64List(0);

  Float64List get screenX => _screenX;

  Float64List get screenY => _screenY;

  Float64List get depths => _depths;

  int projectVertices(Mesh mesh, Transform3 transform, Camera camera) {
    _modelViewProjection
      ..setFrom(camera.viewProjectionMatrix)
      ..multiply(transform.matrix);

    final vertexCount = mesh.vertices.length;
    if (_depths.length != vertexCount) {
      _screenX = Float64List(vertexCount);
      _screenY = Float64List(vertexCount);
      _depths = Float64List(vertexCount);
    }

    var unprojectableVertices = 0;
    for (var index = 0; index < vertexCount; index++) {
      final vertex = mesh.vertices[index];
      _clipPosition.setValues(vertex.x, vertex.y, vertex.z, 1);
      _modelViewProjection.transform(_clipPosition);
      try {
        final projected = camera.projectClipPosition(_clipPosition);
        _screenX[index] = projected.x;
        _screenY[index] = projected.y;
        _depths[index] = projected.depth;
      } on ProjectionException {
        _screenX[index] = 0;
        _screenY[index] = 0;
        _depths[index] = double.nan;
        unprojectableVertices++;
      }
    }
    return unprojectableVertices;
  }
}
