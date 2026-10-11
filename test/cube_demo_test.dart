import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/app/game/cube_demo/cube_demo.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/rendering/renderer.dart';

void main() {
  test(
    'CubeDemo renders multiple faces and changes pixels as time advances',
    () {
      final CubeDemo demo = CubeDemo()..initialize();
      final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
        width: 80,
        height: 60,
      );
      final Renderer renderer = Renderer(framebuffer);

      renderer.beginFrame();
      demo.render(renderer);
      final List<int> firstFrame = framebuffer.snapshot();
      final Set<Color?> visibleColors = {
        for (int y = 0; y < framebuffer.height; y++)
          for (int x = 0; x < framebuffer.width; x++) framebuffer.pixelAt(x, y),
      }..remove(framebuffer.clearColor);

      demo.update(0.8);
      renderer.beginFrame();
      demo.render(renderer);

      expect(visibleColors.length, greaterThanOrEqualTo(3));
      expect(framebuffer.snapshot(), isNot(equals(firstFrame)));
    },
  );
}
