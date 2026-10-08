import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/engine/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/triangle_rasterizer.dart';

void main() {
  group('SoftwareFramebuffer', () {
    test('writes RGBA pixels and ignores out-of-bounds coordinates', () {
      final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
        width: 4,
        height: 3,
      );
      const Color color = Color(0xFF123456);

      framebuffer.setPixel(2, 1, color);
      framebuffer.setPixel(-1, 0, color);
      framebuffer.setPixel(4, 2, color);

      expect(framebuffer.pixelAt(2, 1), color);
      expect(framebuffer.pixelAt(0, 0), const Color(0x00000000));
      expect(framebuffer.pixelAt(4, 1), isNull);
    });

    test('clears every pixel to the requested color', () {
      final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
        width: 2,
        height: 2,
      );

      framebuffer
        ..setPixel(0, 0, const Color(0xFFFFFFFF))
        ..clear();

      expect(framebuffer.pixelAt(0, 0), const Color(0x00000000));
      expect(framebuffer.pixelAt(1, 1), const Color(0x00000000));
    });
  });

  group('TriangleRasterizer', () {
    test('fills covered pixels in either vertex winding order', () {
      final SoftwareFramebuffer clockwise = SoftwareFramebuffer(
        width: 8,
        height: 8,
      );
      final SoftwareFramebuffer counterClockwise = SoftwareFramebuffer(
        width: 8,
        height: 8,
      );
      const Offset a = Offset(1, 1);
      const Offset b = Offset(6, 1);
      const Offset c = Offset(1, 6);
      const Color color = Color(0xFFFF0000);

      final int clockwiseCount = TriangleRasterizer.fill(
        clockwise,
        a,
        b,
        c,
        color,
      );
      final int counterClockwiseCount = TriangleRasterizer.fill(
        counterClockwise,
        a,
        c,
        b,
        color,
      );

      expect(clockwiseCount, greaterThan(0));
      expect(counterClockwiseCount, clockwiseCount);
      expect(clockwise.pixelAt(2, 2), color);
      expect(clockwise.pixelAt(5, 5), isNot(color));
    });

    test('does not fill a degenerate triangle', () {
      final SoftwareFramebuffer framebuffer = SoftwareFramebuffer(
        width: 8,
        height: 8,
      );

      expect(
        TriangleRasterizer.fill(
          framebuffer,
          const Offset(1, 1),
          const Offset(3, 3),
          const Offset(5, 5),
          const Color(0xFFFFFFFF),
        ),
        0,
      );
    });
  });
}
