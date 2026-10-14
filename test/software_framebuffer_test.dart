import 'dart:ui';

import 'package:flutter_software_renderer/engine/graphics/buffers/depth_buffer.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';
import 'package:flutter_software_renderer/engine/graphics/triangle_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SoftwareFramebuffer', () {
    test('writes RGBA pixels and ignores out-of-bounds coordinates', () {
      final framebuffer = SoftwareFramebuffer(width: 4, height: 3);
      const color = Color(0xFF123456);

      framebuffer
        ..setPixel(2, 1, color)
        ..setPixel(-1, 0, color)
        ..setPixel(4, 2, color);

      expect(framebuffer.pixelAt(2, 1), color);
      expect(framebuffer.pixelAt(0, 0), const Color(0x00000000));
      expect(framebuffer.pixelAt(4, 1), isNull);
    });

    test('clears every pixel to the requested color', () {
      final framebuffer = SoftwareFramebuffer(width: 2, height: 2)
        ..setPixel(0, 0, const Color(0xFFFFFFFF))
        ..clear();

      expect(framebuffer.pixelAt(0, 0), const Color(0x00000000));
      expect(framebuffer.pixelAt(1, 1), const Color(0x00000000));
    });
  });

  group('DepthBuffer', () {
    test('clears depth values and bounds-checks indexing', () {
      final depthBuffer = DepthBuffer(width: 3, height: 2);

      expect(depthBuffer.depthAt(0, 0), double.infinity);
      expect(depthBuffer.testAndSet(2, 1, 0.4), isTrue);
      expect(depthBuffer.depthAt(2, 1), 0.4);
      expect(depthBuffer.depthAt(3, 1), isNull);
      expect(depthBuffer.testAndSet(-1, 0, 0.2), isFalse);

      depthBuffer.clear();
      expect(depthBuffer.depthAt(2, 1), double.infinity);
    });

    test('accepts nearer fragments and rejects farther ones', () {
      final depthBuffer = DepthBuffer(width: 1, height: 1);

      expect(depthBuffer.testAndSet(0, 0, 0.7), isTrue);
      expect(depthBuffer.testAndSet(0, 0, 0.8), isFalse);
      expect(depthBuffer.testAndSet(0, 0, 0.2), isTrue);
      expect(depthBuffer.depthAt(0, 0), 0.2);
    });
  });

  group('TriangleRasterizer', () {
    test('fills covered pixels in either vertex winding order', () {
      final clockwise = SoftwareFramebuffer(width: 8, height: 8);
      final counterClockwise = SoftwareFramebuffer(width: 8, height: 8);
      const a = Offset(1, 1);
      const b = Offset(6, 1);
      const c = Offset(1, 6);
      const color = Color(0xFFFF0000);

      final clockwiseCount = TriangleRasterizer.fill(clockwise, a, b, c, color);
      final counterClockwiseCount = TriangleRasterizer.fill(
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
      final framebuffer = SoftwareFramebuffer(width: 8, height: 8);

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

  group('Renderer', () {
    test('resolves overlapping triangles independent of submission order', () {
      Color renderOverlaps({required bool nearFirst}) {
        final framebuffer = SoftwareFramebuffer(width: 12, height: 12);
        final renderer = Renderer(framebuffer)..beginFrame();

        void draw(double depth, Color color) {
          renderer.drawTriangle(
            a: const Offset(1, 1),
            b: const Offset(11, 1),
            c: const Offset(1, 11),
            depthA: depth,
            depthB: depth,
            depthC: depth,
            color: color,
          );
        }

        if (nearFirst) {
          draw(0.2, const Color(0xFF00FF00));
          draw(0.8, const Color(0xFFFF0000));
        } else {
          draw(0.8, const Color(0xFFFF0000));
          draw(0.2, const Color(0xFF00FF00));
        }

        return framebuffer.pixelAt(4, 4)!;
      }

      expect(renderOverlaps(nearFirst: true), const Color(0xFF00FF00));
      expect(renderOverlaps(nearFirst: false), const Color(0xFF00FF00));
    });

    test('clears both color and depth state at the start of a frame', () {
      final framebuffer = SoftwareFramebuffer(
        width: 4,
        height: 4,
        clearColor: const Color(0xFF010203),
      );
      final renderer = Renderer(framebuffer)
        ..drawTriangle(
          a: Offset.zero,
          b: const Offset(4, 0),
          c: const Offset(0, 4),
          depthA: 0.2,
          depthB: 0.2,
          depthC: 0.2,
          color: const Color(0xFFFFFFFF),
        )
        ..beginFrame();

      expect(framebuffer.pixelAt(1, 1), const Color(0xFF010203));
      expect(renderer.depthBuffer.depthAt(1, 1), double.infinity);
    });
  });
}
