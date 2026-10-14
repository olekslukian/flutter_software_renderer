import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' as v64;

abstract class Camera {
  Camera({
    required this.position,
    required this.target,
    v64.Vector3? up,
    this.nearPlane = 0.1,
    this.farPlane = 100.0,
  }) : up = up ?? v64.Vector3(0, 1, 0) {
    _validateClippingPlanes();
  }

  final v64.Vector3 position;

  final v64.Vector3 target;

  final v64.Vector3 up;

  final double nearPlane;

  final double farPlane;

  final v64.Matrix4 _viewMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _projectionMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _viewProjectionMatrix = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();
  int? _viewportWidth;
  int? _viewportHeight;

  v64.Matrix4 get viewProjectionMatrix => _viewProjectionMatrix;

  void configureViewport(int viewportWidth, int viewportHeight) {
    if (viewportWidth <= 0 || viewportHeight <= 0) {
      throw ArgumentError('Viewport dimensions must be positive.');
    }

    _validateOrientation();
    v64.setViewMatrix(_viewMatrix, position, target, up);
    setProjectionMatrix(_projectionMatrix, viewportWidth / viewportHeight);
    _viewProjectionMatrix
      ..setFrom(_projectionMatrix)
      ..multiply(_viewMatrix);
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
  }

  void setProjectionMatrix(v64.Matrix4 projection, double aspectRatio);

  ProjectedVertex project(v64.Vector3 worldPosition) {
    _clipPosition.setValues(
      worldPosition.x,
      worldPosition.y,
      worldPosition.z,
      1,
    );
    _viewProjectionMatrix.transform(_clipPosition);
    return projectClipPosition(_clipPosition);
  }

  ProjectedVertex projectClipPosition(v64.Vector4 clipPosition) {
    final viewportWidth = _viewportWidth;
    final viewportHeight = _viewportHeight;
    if (viewportWidth == null || viewportHeight == null) {
      throw StateError('Configure the camera viewport before projecting.');
    }
    if (clipPosition.w == 0.0 || !clipPosition.w.isFinite) {
      throw StateError('The world position cannot be projected.');
    }

    final inverseW = 1.0 / clipPosition.w;
    final normalizedX = clipPosition.x * inverseW;
    final normalizedY = clipPosition.y * inverseW;
    final normalizedDepth = (clipPosition.z * inverseW + 1.0) * 0.5;
    return ProjectedVertex(
      Offset(
        (normalizedX + 1.0) * viewportWidth / 2.0,
        (1.0 - normalizedY) * viewportHeight / 2.0,
      ),
      normalizedDepth,
    );
  }

  void _validateClippingPlanes() {
    if (!nearPlane.isFinite ||
        !farPlane.isFinite ||
        nearPlane <= 0.0 ||
        farPlane <= nearPlane) {
      throw ArgumentError(
        'The camera requires finite clipping planes with 0 < near < far.',
      );
    }
  }

  void _validateOrientation() {
    final viewDirection = target - position;
    final rightDirection = up.cross(viewDirection);
    final vectorsAreFinite = [
      position.x,
      position.y,
      position.z,
      target.x,
      target.y,
      target.z,
      up.x,
      up.y,
      up.z,
    ].every((value) => value.isFinite);
    if (!vectorsAreFinite ||
        viewDirection.length2 == 0.0 ||
        up.length2 == 0.0 ||
        rightDirection.length2 == 0.0) {
      throw ArgumentError(
        'Camera position, target, and up must define a finite view direction.',
      );
    }
  }
}

class ProjectedVertex {
  const ProjectedVertex(this.position, this.depth);

  final Offset position;

  final double depth;
}
