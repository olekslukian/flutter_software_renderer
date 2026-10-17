import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/camera/perspective_camera.dart';
import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/mesh.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:software_engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

final class TriangleScene extends Game {
  TriangleScene({super.clearColor, super.width, super.height});

  final Mesh _mesh = Mesh(
    vertices: [
      v64.Vector3(-1, -1, 0),
      v64.Vector3(1, -1, 0),
      v64.Vector3(0, 1, 0),
    ],
    indices: const [0, 1, 2],
  );

  final Transform3 _transform = Transform3();

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 4),
    target: v64.Vector3.zero(),
  );

  @override
  Future<void> initialize(AssetLoader assets) async {}

  @override
  void update(double deltaTime) {}

  @override
  void render(Renderer renderer) {
    renderer.drawMesh(
      mesh: _mesh,
      transform: _transform,
      camera: _camera,
      color: const Color32.fromARGB32(0xFFFF0000),
    );
  }
}

const _radiansPerFrame = 0.05;

void _spin(Transform3 transform, double angle) {
  transform.rotation.setValues(angle * 0.7, angle, angle * 0.35);
  transform.updateMatrix();
}

final class PengerScene extends Game {
  PengerScene({this.modelPath = 'models/penger.obj'});

  final String modelPath;

  final Transform3 _transform = Transform3();

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 4.5),
    target: v64.Vector3.zero(),
  );

  Mesh? _mesh;

  int _frame = 0;

  @override
  Future<void> initialize(AssetLoader assets) async {
    _mesh = Mesh.fromObj(await assets.loadString(modelPath)).normalized();
  }

  @override
  void update(double deltaTime) {
    _frame++;
    _spin(_transform, _frame * _radiansPerFrame);
  }

  @override
  void render(Renderer renderer) {
    final mesh = _mesh;
    if (mesh == null) {
      return;
    }
    renderer.drawMesh(
      mesh: mesh,
      transform: _transform,
      camera: _camera,
      color: const Color32.fromARGB32(0xFF20C7D9),
    );
  }
}

final class RotatingCubeScene extends Game {
  final Mesh _mesh = Mesh(
    vertices: [
      v64.Vector3(-1, -1, -1),
      v64.Vector3(1, -1, -1),
      v64.Vector3(1, 1, -1),
      v64.Vector3(-1, 1, -1),
      v64.Vector3(-1, -1, 1),
      v64.Vector3(1, -1, 1),
      v64.Vector3(1, 1, 1),
      v64.Vector3(-1, 1, 1),
    ],
    indices: const [
      0,
      2,
      1,
      0,
      3,
      2,
      4,
      5,
      6,
      4,
      6,
      7,
      0,
      4,
      7,
      0,
      7,
      3,
      1,
      2,
      6,
      1,
      6,
      5,
      0,
      1,
      5,
      0,
      5,
      4,
      3,
      7,
      6,
      3,
      6,
      2,
    ],
  );

  final Transform3 _transform = Transform3();

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 5),
    target: v64.Vector3.zero(),
  );

  int _frame = 0;

  @override
  Future<void> initialize(AssetLoader assets) async {}

  @override
  void update(double deltaTime) {
    _frame++;
    _spin(_transform, _frame * _radiansPerFrame);
  }

  @override
  void render(Renderer renderer) {
    renderer.drawMesh(
      mesh: _mesh,
      transform: _transform,
      camera: _camera,
      color: const Color32.fromARGB32(0xFFE0A030),
    );
  }
}

final class OverdrawScene extends Game {
  OverdrawScene({int layerCount = 24}) : _mesh = _stackedQuads(layerCount);

  final Mesh _mesh;

  final Transform3 _transform = Transform3();

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 4),
    target: v64.Vector3.zero(),
  );

  int _frame = 0;

  static Mesh _stackedQuads(int layerCount) {
    final vertices = <v64.Vector3>[];
    final indices = <int>[];
    for (var layer = 0; layer < layerCount; layer++) {
      final z = -1.0 + 2.0 * layer / (layerCount - 1);
      final base = vertices.length;
      vertices
        ..add(v64.Vector3(-1.5, -1.5, z))
        ..add(v64.Vector3(1.5, -1.5, z))
        ..add(v64.Vector3(1.5, 1.5, z))
        ..add(v64.Vector3(-1.5, 1.5, z));
      indices
        ..add(base)
        ..add(base + 1)
        ..add(base + 2)
        ..add(base)
        ..add(base + 2)
        ..add(base + 3);
    }
    return Mesh(vertices: vertices, indices: indices);
  }

  @override
  Future<void> initialize(AssetLoader assets) async {}

  @override
  void update(double deltaTime) {
    _frame++;
    _spin(_transform, _frame * _radiansPerFrame);
  }

  @override
  void render(Renderer renderer) {
    renderer.drawMesh(
      mesh: _mesh,
      transform: _transform,
      camera: _camera,
      color: const Color32.fromARGB32(0xFF6080FF),
    );
  }
}
