import 'package:vector_math/vector_math_64.dart' as v64;

/// Holds a 3D position, Euler rotation, and scale and applies them as a model
/// transform to local-space positions.
class Transform3 {
  /// Creates a transform with zero position and rotation and unit scale unless
  /// explicit vectors are provided.
  Transform3({
    v64.Vector3? position,
    v64.Vector3? rotation,
    v64.Vector3? scale,
  }) : position = position ?? v64.Vector3.zero(),
       rotation = rotation ?? v64.Vector3.zero(),
       scale = scale ?? v64.Vector3.all(1.0) {
    updateMatrix();
  }

  /// The model-space translation.
  final v64.Vector3 position;

  /// Euler angles in radians, applied around Z, then Y, then X.
  final v64.Vector3 rotation;

  /// Per-axis model scale.
  final v64.Vector3 scale;

  final v64.Matrix4 _matrix = v64.Matrix4.identity();

  /// Rebuilds the model matrix from the current position, rotation, and scale.
  ///
  /// Call this after changing any of the exposed vectors and before
  /// [transformPosition].
  void updateMatrix() {
    _matrix
      ..setIdentity()
      ..translate(position.x, position.y, position.z)
      ..rotateZ(rotation.z)
      ..rotateY(rotation.y)
      ..rotateX(rotation.x)
      ..scale(scale.x, scale.y, scale.z);
  }

  /// Applies the current model matrix to local-space [position] and writes the
  /// resulting homogeneous coordinates into [result].
  ///
  /// [result] is caller-owned so a render loop can reuse storage per vertex.
  void transformPosition(v64.Vector3 position, v64.Vector4 result) {
    result.setValues(position.x, position.y, position.z, 1.0);
    _matrix.transform(result);
  }
}
