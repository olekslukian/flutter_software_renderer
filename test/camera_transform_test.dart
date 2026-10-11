import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/perspective_camera.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  group('PerspectiveCamera', () {
    test('projects the target to viewport center with normalized depth', () {
      final PerspectiveCamera camera = PerspectiveCamera(
        position: v64.Vector3(0.0, 0.0, 4.5),
        target: v64.Vector3.zero(),
      )..configureViewport(160, 120);

      final ProjectedVertex projected = camera.project(v64.Vector3.zero());

      expect(projected.position.dx, closeTo(80.0, 1e-9));
      expect(projected.position.dy, closeTo(60.0, 1e-9));
      expect(projected.depth, inInclusiveRange(0.0, 1.0));
    });

    test('requires a valid viewport before projecting', () {
      final PerspectiveCamera camera = PerspectiveCamera(
        position: v64.Vector3(0.0, 0.0, 4.5),
        target: v64.Vector3.zero(),
      );

      expect(() => camera.project(v64.Vector3.zero()), throwsStateError);
      expect(() => camera.configureViewport(0, 10), throwsArgumentError);
    });
  });

  test('Transform3 applies rotation and translation to local positions', () {
    final Transform3 transform = Transform3(
      position: v64.Vector3(3.0, 4.0, 0.0),
      rotation: v64.Vector3(0.0, 0.0, v64.radians(90.0)),
    );
    final v64.Vector4 result = v64.Vector4.zero();

    transform.transformPosition(v64.Vector3(1.0, 0.0, 0.0), result);

    expect(result.x, closeTo(3.0, 1e-9));
    expect(result.y, closeTo(5.0, 1e-9));
    expect(result.z, closeTo(0.0, 1e-9));
    expect(result.w, closeTo(1.0, 1e-9));
  });
}
