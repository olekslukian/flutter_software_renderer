import 'dart:ui';

import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/triangle_rasterizer.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// A small 3D scene that draws its filled triangle entirely on the CPU.
class TriangleDemo extends Game {
  TriangleDemo({super.backgroundColor});

  final List<v64.Vector3> _vertices = [
    v64.Vector3(-1.0, -0.8, 0.0),
    v64.Vector3(1.0, -0.8, 0.0),
    v64.Vector3(0.0, 1.0, 0.0),
  ];

  final v64.Matrix4 _modelMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _viewMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _projectionMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _modelViewProjectionMatrix = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();
  final List<Offset> _screenPositions = List<Offset>.filled(3, Offset.zero);

  double _angle = 0.0;

  @override
  void initialize() {
    _angle = 0.0;
  }

  @override
  void update(double deltaTime) {
    _angle += 1.2 * deltaTime;
  }

  @override
  void render(SoftwareFramebuffer framebuffer) {
    _modelMatrix
      ..setIdentity()
      ..rotateZ(_angle)
      ..rotateY(_angle * 0.65);
    _viewMatrix
      ..setIdentity()
      ..setTranslationRaw(0.0, 0.0, -3.5);

    v64.setPerspectiveMatrix(
      _projectionMatrix,
      v64.radians(60.0),
      framebuffer.width / framebuffer.height,
      0.1,
      100.0,
    );

    _modelViewProjectionMatrix
      ..setFrom(_projectionMatrix)
      ..multiply(_viewMatrix)
      ..multiply(_modelMatrix);

    // Perspective division turns clip-space coordinates into screen space.
    for (int index = 0; index < _vertices.length; index++) {
      final v64.Vector3 vertex = _vertices[index];
      _clipPosition.setValues(vertex.x, vertex.y, vertex.z, 1.0);
      _modelViewProjectionMatrix.transform(_clipPosition);

      if (_clipPosition.w == 0.0) continue;
      final double normalizedX = _clipPosition.x / _clipPosition.w;
      final double normalizedY = _clipPosition.y / _clipPosition.w;
      _screenPositions[index] = Offset(
        (normalizedX + 1.0) * framebuffer.width / 2.0,
        (1.0 - normalizedY) * framebuffer.height / 2.0,
      );
    }

    TriangleRasterizer.fill(
      framebuffer,
      _screenPositions[0],
      _screenPositions[1],
      _screenPositions[2],
      const Color(0xFF00FFC8),
    );
  }
}
