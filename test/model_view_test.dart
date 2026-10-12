import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/app/game/model_view_demo/model_view_demo.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders and animates a mesh with more than eight vertices', () async {
    final ModelViewDemo demo = ModelViewDemo(mesh: _nineVertexMesh());
    await demo.initialize();
    final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
      width: 80,
      height: 60,
    );
    final Renderer renderer = Renderer(framebuffer);

    renderer.beginFrame();
    demo.render(renderer);
    final List<int> firstFrame = framebuffer.snapshot();
    final int visiblePixels = _countVisiblePixels(framebuffer);

    demo.update(0.8);
    renderer.beginFrame();
    demo.render(renderer);

    expect(visiblePixels, greaterThan(0));
    expect(framebuffer.snapshot(), isNot(equals(firstFrame)));
  });

  test('loads and renders the configured OBJ asset', () async {
    final ModelViewDemo demo = ModelViewDemo();
    await demo.initialize();
    final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
      width: 160,
      height: 120,
    );
    final Renderer renderer = Renderer(framebuffer)..beginFrame();

    demo.render(renderer);

    expect(_countVisiblePixels(framebuffer), greaterThan(0));
  });
}

Mesh _nineVertexMesh() {
  return Mesh(
    vertices: [
      v64.Vector3(-1.0, -1.0, -1.0),
      v64.Vector3(1.0, -1.0, -1.0),
      v64.Vector3(1.0, 1.0, -1.0),
      v64.Vector3(-1.0, 1.0, -1.0),
      v64.Vector3(-1.0, -1.0, 1.0),
      v64.Vector3(1.0, -1.0, 1.0),
      v64.Vector3(1.0, 1.0, 1.0),
      v64.Vector3(-1.0, 1.0, 1.0),
      v64.Vector3.zero(),
    ],
    indices: [
      0,
      1,
      8,
      1,
      2,
      8,
      2,
      3,
      8,
      3,
      0,
      8,
      4,
      5,
      8,
      5,
      6,
      8,
      6,
      7,
      8,
      7,
      4,
      8,
    ],
  );
}

int _countVisiblePixels(SoftwareFramebuffer framebuffer) {
  int count = 0;
  for (int y = 0; y < framebuffer.height; y++) {
    for (int x = 0; x < framebuffer.width; x++) {
      if (framebuffer.pixelAt(x, y) != framebuffer.clearColor) count++;
    }
  }
  return count;
}
