import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/camera/perspective_camera.dart';
import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/mesh.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:software_engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class ModelViewDemo extends Game {
  ModelViewDemo({
    super.clearColor,
    super.width,
    super.height,
    this.modelAssetPath = 'assets/models/penger.obj',
    Mesh? mesh,
    this.modelColor = const Color32.fromARGB32(0xFF20C7D9),
  }) : _mesh = mesh;

  final String modelAssetPath;

  final Color32 modelColor;

  Mesh? _mesh;

  final Transform3 _transform = Transform3(
    rotation: v64.Vector3(0.45 * 0.7, 0.45, 0.45 * 0.35),
  );

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 4.5),
    target: v64.Vector3.zero(),
  );

  @override
  Future<void> initialize(AssetLoader assets) async {
    final mesh = _mesh ?? Mesh.fromObj(await assets.loadString(modelAssetPath));
    _mesh = mesh.normalized();
  }

  @override
  void update(double deltaTime) {
    final angle = _transform.rotation.y + 1.2 * deltaTime;
    _transform.rotation.setValues(angle * 0.7, angle, angle * 0.35);
    _transform.updateMatrix();
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
      color: modelColor,
    );
  }
}
