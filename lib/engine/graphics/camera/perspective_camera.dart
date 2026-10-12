import 'dart:ui';

import 'package:vector_math/vector_math_64.dart' as v64;

/// A perspective camera that projects world-space positions into framebuffer
/// pixel coordinates and normalized depth.
class PerspectiveCamera {
  /// Creates a camera looking from [position] toward [target], using the given
  /// vertical field of view and clipping planes.
  PerspectiveCamera({
    required this.position,
    required this.target,
    v64.Vector3? up,
    this.verticalFieldOfView = 60.0,
    this.nearPlane = 0.1,
    this.farPlane = 100.0,
  }) : up = up ?? v64.Vector3(0.0, 1.0, 0.0) {
    _validateFrustum();
  }

  /// The camera position in world space.
  final v64.Vector3 position;

  /// The world-space point the camera looks toward.
  final v64.Vector3 target;

  /// The camera's up direction.
  final v64.Vector3 up;

  /// The vertical field of view in degrees.
  final double verticalFieldOfView;

  /// The near clipping distance.
  final double nearPlane;

  /// The far clipping distance.
  final double farPlane;

  final v64.Matrix4 _viewMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _projectionMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _viewProjectionMatrix = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();
  int? _viewportWidth;
  int? _viewportHeight;

  /// Prepares the view-projection matrix for a framebuffer viewport.
  ///
  /// Call this after changing [position], [target], or [up], and before
  /// projecting vertices. Rebuilding once per frame avoids repeating matrix
  /// setup for every vertex.
  void configureViewport(int viewportWidth, int viewportHeight) {
    if (viewportWidth <= 0 || viewportHeight <= 0) {
      throw ArgumentError('Viewport dimensions must be positive.');
    }

    _validateOrientation();
    v64.setViewMatrix(_viewMatrix, position, target, up);
    v64.setPerspectiveMatrix(
      _projectionMatrix,
      v64.radians(verticalFieldOfView),
      viewportWidth / viewportHeight,
      nearPlane,
      farPlane,
    );
    _viewProjectionMatrix
      ..setFrom(_projectionMatrix)
      ..multiply(_viewMatrix);
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
  }

  /// Projects [worldPosition] into the configured viewport and returns its
  /// pixel-space position and normalized depth.
  ///
  /// Smaller depth values are nearer, matching the engine depth-buffer
  /// convention. Callers must keep projected geometry within the camera's
  /// clipping volume; near-plane clipping is not performed here.
  ProjectedVertex project(v64.Vector3 worldPosition) {
    final int? viewportWidth = _viewportWidth;
    final int? viewportHeight = _viewportHeight;
    if (viewportWidth == null || viewportHeight == null) {
      throw StateError('Configure the camera viewport before projecting.');
    }

    _clipPosition.setValues(
      worldPosition.x,
      worldPosition.y,
      worldPosition.z,
      1.0,
    );
    _viewProjectionMatrix.transform(_clipPosition);
    if (_clipPosition.w == 0.0 || !_clipPosition.w.isFinite) {
      throw StateError('The world position cannot be projected.');
    }

    final double inverseW = 1.0 / _clipPosition.w;
    final double normalizedX = _clipPosition.x * inverseW;
    final double normalizedY = _clipPosition.y * inverseW;
    final double normalizedDepth = (_clipPosition.z * inverseW + 1.0) * 0.5;
    return ProjectedVertex(
      Offset(
        (normalizedX + 1.0) * viewportWidth / 2.0,
        (1.0 - normalizedY) * viewportHeight / 2.0,
      ),
      normalizedDepth,
    );
  }

  /// Ensures the perspective settings define a valid clipping volume.
  void _validateFrustum() {
    if (!verticalFieldOfView.isFinite ||
        verticalFieldOfView <= 0.0 ||
        verticalFieldOfView >= 180.0) {
      throw ArgumentError.value(
        verticalFieldOfView,
        'verticalFieldOfView',
        'must be finite and between 0 and 180 degrees',
      );
    }
    if (!nearPlane.isFinite ||
        !farPlane.isFinite ||
        nearPlane <= 0.0 ||
        farPlane <= nearPlane) {
      throw ArgumentError(
        'The camera requires finite clipping planes with 0 < near < far.',
      );
    }
  }

  /// Ensures the view matrix can be built from finite, non-collinear vectors.
  void _validateOrientation() {
    final v64.Vector3 viewDirection = target - position;
    final v64.Vector3 rightDirection = up.cross(viewDirection);
    final bool vectorsAreFinite = [
      position.x,
      position.y,
      position.z,
      target.x,
      target.y,
      target.z,
      up.x,
      up.y,
      up.z,
    ].every((double value) => value.isFinite);
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
  /// Creates a projected vertex at [position] with normalized [depth].
  const ProjectedVertex(this.position, this.depth);

  /// The projected position in framebuffer pixel coordinates.
  final Offset position;

  /// Normalized depth where smaller values are nearer.
  final double depth;
}
