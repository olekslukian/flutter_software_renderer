import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  test('applies rotation and translation to local positions', () {
    final transform = Transform3(
      position: v64.Vector3(3, 4, 0),
      rotation: v64.Vector3(0, 0, v64.radians(90)),
    );
    final result = v64.Vector4.zero();

    transform.transformPosition(v64.Vector3(1, 0, 0), result);

    expect(result.x, closeTo(3.0, 1e-9));
    expect(result.y, closeTo(5.0, 1e-9));
    expect(result.z, closeTo(0.0, 1e-9));
    expect(result.w, closeTo(1.0, 1e-9));
  });

  test('transformPoint returns the transformed 3D point', () {
    final transform = Transform3(
      position: v64.Vector3(3, 4, 0),
      rotation: v64.Vector3(0, 0, v64.radians(90)),
    );
    final result = v64.Vector3.zero();

    transform.transformPoint(v64.Vector3(1, 0, 0), result);

    expect(result.x, closeTo(3.0, 1e-9));
    expect(result.y, closeTo(5.0, 1e-9));
    expect(result.z, closeTo(0.0, 1e-9));
  });
}
