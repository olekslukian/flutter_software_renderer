import 'package:software_engine/graphics/camera/camera.dart';
import 'package:software_engine/graphics/camera/perspective_camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class _OrthographicStubCamera extends Camera {
  _OrthographicStubCamera({
    required super.position,
    required super.target,
    super.nearPlane,
    super.farPlane,
  });

  @override
  void setProjectionMatrix(v64.Matrix4 projection, double aspectRatio) {
    v64.setOrthographicMatrix(projection, -1, 1, -1, 1, nearPlane, farPlane);
  }
}

void main() {
  group('PerspectiveCamera', () {
    test('projects the target to viewport center with normalized depth', () {
      final camera = PerspectiveCamera(
        position: v64.Vector3(0, 0, 4.5),
        target: v64.Vector3.zero(),
      )..configureViewport(160, 120);

      final projected = camera.project(v64.Vector3.zero());

      expect(projected.x, closeTo(80.0, 1e-9));
      expect(projected.y, closeTo(60.0, 1e-9));
      expect(projected.depth, inInclusiveRange(0.0, 1.0));
    });

    test('requires a valid viewport before projecting', () {
      final camera = PerspectiveCamera(
        position: v64.Vector3(0, 0, 4.5),
        target: v64.Vector3.zero(),
      );

      expect(() => camera.project(v64.Vector3.zero()), throwsStateError);
      expect(() => camera.configureViewport(0, 10), throwsArgumentError);
    });

    test('rejects an invalid field of view', () {
      expect(
        () => PerspectiveCamera(
          position: v64.Vector3(0, 0, 4.5),
          target: v64.Vector3.zero(),
          verticalFieldOfView: 180,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Camera', () {
    test('rejects clipping planes that are not 0 < near < far', () {
      expect(
        () => _OrthographicStubCamera(
          position: v64.Vector3(0, 0, 4.5),
          target: v64.Vector3.zero(),
          nearPlane: 2,
          farPlane: 1,
        ),
        throwsArgumentError,
      );
    });

    test('drives any subclass through the shared viewport projection', () {
      final camera = _OrthographicStubCamera(
        position: v64.Vector3(0, 0, 4),
        target: v64.Vector3.zero(),
      )..configureViewport(10, 20);

      final projected = camera.project(v64.Vector3(1, 1, 0));

      expect(projected.x, closeTo(10.0, 1e-9));
      expect(projected.y, closeTo(0.0, 1e-9));
    });
  });
}
