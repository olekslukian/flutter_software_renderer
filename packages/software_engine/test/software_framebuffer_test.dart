import 'package:software_engine/graphics/buffers/depth_buffer.dart';
import 'package:software_engine/graphics/buffers/software_framebuffer.dart';
import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:software_engine/graphics/triangle_rasterizer.dart';
import 'package:test/test.dart';

void main() {
  group('SoftwareFramebuffer', () {
    test('writes RGBA pixels and ignores out-of-bounds coordinates', () {
      final framebuffer = SoftwareFramebuffer(width: 4, height: 3);
      const color = Color32.fromARGB32(0xFF123456);

      framebuffer
        ..setPixel(2, 1, color)
        ..setPixel(-1, 0, color)
        ..setPixel(4, 2, color);

      expect(framebuffer.pixelAt(2, 1), color);
      expect(framebuffer.pixelAt(0, 0), const Color32.fromARGB32(0x00000000));
      expect(framebuffer.pixelAt(4, 1), isNull);
    });

    test('clears every pixel to the requested color', () {
      final framebuffer = SoftwareFramebuffer(width: 2, height: 2)
        ..setPixel(0, 0, const Color32.fromARGB32(0xFFFFFFFF))
        ..clear();

      expect(framebuffer.pixelAt(0, 0), const Color32.fromARGB32(0x00000000));
      expect(framebuffer.pixelAt(1, 1), const Color32.fromARGB32(0x00000000));
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
      const color = Color32.fromARGB32(0xFFFF0000);

      final clockwiseCount = TriangleRasterizer.fill(
        clockwise,
        1,
        1,
        6,
        1,
        1,
        6,
        color,
      );
      final counterClockwiseCount = TriangleRasterizer.fill(
        counterClockwise,
        1,
        1,
        1,
        6,
        6,
        1,
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
          1,
          1,
          3,
          3,
          5,
          5,
          const Color32.fromARGB32(0xFFFFFFFF),
        ),
        0,
      );
    });
  });

  group('Renderer', () {
    test('resolves overlapping triangles independent of submission order', () {
      Color32 renderOverlaps({required bool nearFirst}) {
        final framebuffer = SoftwareFramebuffer(width: 12, height: 12);
        final renderer = Renderer(framebuffer)..beginFrame();

        void draw(double depth, Color32 color) {
          renderer.drawTriangle(
            ax: 1,
            ay: 1,
            bx: 11,
            by: 1,
            cx: 1,
            cy: 11,
            depthA: depth,
            depthB: depth,
            depthC: depth,
            color: color,
          );
        }

        if (nearFirst) {
          draw(0.2, const Color32.fromARGB32(0xFF00FF00));
          draw(0.8, const Color32.fromARGB32(0xFFFF0000));
        } else {
          draw(0.8, const Color32.fromARGB32(0xFFFF0000));
          draw(0.2, const Color32.fromARGB32(0xFF00FF00));
        }

        return framebuffer.pixelAt(4, 4)!;
      }

      expect(
        renderOverlaps(nearFirst: true),
        const Color32.fromARGB32(0xFF00FF00),
      );
      expect(
        renderOverlaps(nearFirst: false),
        const Color32.fromARGB32(0xFF00FF00),
      );
    });

    test('clears both color and depth state at the start of a frame', () {
      final framebuffer = SoftwareFramebuffer(
        width: 4,
        height: 4,
        clearColor: const Color32.fromARGB32(0xFF010203),
      );
      final renderer = Renderer(framebuffer)
        ..drawTriangle(
          ax: 0,
          ay: 0,
          bx: 4,
          by: 0,
          cx: 0,
          cy: 4,
          depthA: 0.2,
          depthB: 0.2,
          depthC: 0.2,
          color: const Color32.fromARGB32(0xFFFFFFFF),
        )
        ..beginFrame();

      expect(framebuffer.pixelAt(1, 1), const Color32.fromARGB32(0xFF010203));
      expect(renderer.depthBuffer.depthAt(1, 1), double.infinity);
    });
  });
}
