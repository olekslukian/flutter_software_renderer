import 'dart:ui';

import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/perspective_camera.dart';
import 'package:flutter_software_renderer/engine/graphics/rendering/renderer.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class CubeDemo extends Game {
  CubeDemo({super.clearColor, super.width, super.height});

  final List<v64.Vector3> _vertices = [
    v64.Vector3(-1.0, -1.0, -1.0),
    v64.Vector3(1.0, -1.0, -1.0),
    v64.Vector3(1.0, 1.0, -1.0),
    v64.Vector3(-1.0, 1.0, -1.0),
    v64.Vector3(-1.0, -1.0, 1.0),
    v64.Vector3(1.0, -1.0, 1.0),
    v64.Vector3(1.0, 1.0, 1.0),
    v64.Vector3(-1.0, 1.0, 1.0),
  ];

  final List<int> _triangles = [
    4,
    5,
    6,
    4,
    6,
    7,
    1,
    0,
    3,
    1,
    3,
    2,
    5,
    1,
    2,
    5,
    2,
    6,
    0,
    4,
    7,
    0,
    7,
    3,
    7,
    6,
    2,
    7,
    2,
    3,
    0,
    1,
    5,
    0,
    5,
    4,
  ];

  final List<Color> _faceColors = [
    const Color(0xFF22D3EE),
    const Color(0xFF22D3EE),
    const Color(0xFF3B82F6),
    const Color(0xFF3B82F6),
    const Color(0xFFF97316),
    const Color(0xFFF97316),
    const Color(0xFFA855F7),
    const Color(0xFFA855F7),
    const Color(0xFF22C55E),
    const Color(0xFF22C55E),
    const Color(0xFFEAB308),
    const Color(0xFFEAB308),
  ];

  final Transform3 _transform = Transform3(
    rotation: v64.Vector3(0.0, 0.45, 0.0),
  );
  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0.0, 0.0, 4.5),
    target: v64.Vector3.zero(),
  );
  final List<v64.Vector4> _transformedPositions = List<v64.Vector4>.generate(
    8,
    (_) => v64.Vector4.zero(),
  );
  final List<v64.Vector3> _worldPositions = List<v64.Vector3>.generate(
    8,
    (_) => v64.Vector3.zero(),
  );
  final List<Offset> _screenPositions = List<Offset>.filled(8, Offset.zero);
  final List<double> _depths = List<double>.filled(8, 1.0);

  @override
  void initialize() {
    _transform.rotation.setValues(0.45 * 0.7, 0.45, 0.45 * 0.35);
    _transform.updateMatrix();
  }

  @override
  void update(double deltaTime) {
    final double angle = _transform.rotation.y + 1.2 * deltaTime;
    _transform.rotation.setValues(angle * 0.7, angle, angle * 0.35);
    _transform.updateMatrix();
  }

  @override
  void render(Renderer renderer) {
    final int width = renderer.framebuffer.width;
    final int height = renderer.framebuffer.height;
    _camera.configureViewport(width, height);
    for (int index = 0; index < _vertices.length; index++) {
      final v64.Vector3 vertex = _vertices[index];
      final v64.Vector4 transformedPosition = _transformedPositions[index];
      _transform.transformPosition(vertex, transformedPosition);
      final v64.Vector3 worldPosition = _worldPositions[index]
        ..setValues(
          transformedPosition.x,
          transformedPosition.y,
          transformedPosition.z,
        );
      final ProjectedVertex projected = _camera.project(worldPosition);
      _screenPositions[index] = projected.position;
      _depths[index] = projected.depth;
    }

    for (int triangle = 0; triangle < _faceColors.length; triangle++) {
      final int index = triangle * 3;
      final int a = _triangles[index];
      final int b = _triangles[index + 1];
      final int c = _triangles[index + 2];
      renderer.drawTriangle(
        a: _screenPositions[a],
        b: _screenPositions[b],
        c: _screenPositions[c],
        depthA: _depths[a],
        depthB: _depths[b],
        depthC: _depths[c],
        color: _faceColors[triangle],
      );
    }
  }
}
