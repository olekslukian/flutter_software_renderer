import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/app/game/triangle_demo/triangle_demo.dart';
import 'package:flutter_software_renderer/engine/software_framebuffer.dart';

void main() {
  test('advancing time changes the triangle pixels', () {
    final TriangleDemo demo = TriangleDemo()..initialize();
    final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
      width: 80,
      height: 60,
    );

    framebuffer.clear();
    demo.render(framebuffer);
    final List<int> firstFrame = framebuffer.snapshot();

    demo.update(0.8);
    framebuffer.clear();
    demo.render(framebuffer);

    expect(framebuffer.snapshot(), isNot(equals(firstFrame)));
  });
}
