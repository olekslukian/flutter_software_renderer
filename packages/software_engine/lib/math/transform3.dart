import 'package:vector_math/vector_math_64.dart' as v64;

class Transform3 {
  Transform3({v64.Vector3? position, v64.Vector3? rotation, v64.Vector3? scale})
    : position = position ?? v64.Vector3.zero(),
      rotation = rotation ?? v64.Vector3.zero(),
      scale = scale ?? v64.Vector3.all(1) {
    updateMatrix();
  }

  final v64.Vector3 position;

  final v64.Vector3 rotation;

  final v64.Vector3 scale;

  final v64.Matrix4 _matrix = v64.Matrix4.identity();

  final v64.Vector4 _scratch = v64.Vector4.zero();

  v64.Matrix4 get matrix => _matrix;

  void updateMatrix() {
    _matrix
      ..setIdentity()
      ..translate(position.x, position.y, position.z)
      ..rotateZ(rotation.z)
      ..rotateY(rotation.y)
      ..rotateX(rotation.x)
      ..scale(scale.x, scale.y, scale.z);
  }

  void transformPosition(v64.Vector3 position, v64.Vector4 result) {
    result.setValues(position.x, position.y, position.z, 1);
    _matrix.transform(result);
  }

  void transformPoint(v64.Vector3 position, v64.Vector3 result) {
    transformPosition(position, _scratch);
    result.setValues(_scratch.x, _scratch.y, _scratch.z);
  }
}
