import 'package:flutter_software_renderer/engine/graphics/camera/camera.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class PerspectiveCamera extends Camera {
  PerspectiveCamera({
    required super.position,
    required super.target,
    super.up,
    this.verticalFieldOfView = 60.0,
    super.nearPlane,
    super.farPlane,
  }) {
    _validateFieldOfView();
  }

  final double verticalFieldOfView;

  @override
  void setProjectionMatrix(v64.Matrix4 projection, double aspectRatio) {
    v64.setPerspectiveMatrix(
      projection,
      v64.radians(verticalFieldOfView),
      aspectRatio,
      nearPlane,
      farPlane,
    );
  }

  void _validateFieldOfView() {
    if (!verticalFieldOfView.isFinite ||
        verticalFieldOfView <= 0.0 ||
        verticalFieldOfView >= 180.0) {
      throw ArgumentError.value(
        verticalFieldOfView,
        'verticalFieldOfView',
        'must be finite and between 0 and 180 degrees',
      );
    }
  }
}
