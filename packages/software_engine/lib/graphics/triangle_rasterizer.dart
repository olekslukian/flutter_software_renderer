import 'package:software_engine/graphics/buffers/depth_buffer.dart';
import 'package:software_engine/graphics/buffers/software_framebuffer.dart';
import 'package:software_engine/graphics/color32.dart';

abstract class TriangleRasterizer {
  static int fill(
    SoftwareFramebuffer framebuffer,
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    Color32 color,
  ) {
    return _fill(
      framebuffer,
      null,
      ax,
      ay,
      bx,
      by,
      cx,
      cy,
      null,
      null,
      null,
      color,
    );
  }

  static int fillWithDepth(
    SoftwareFramebuffer framebuffer,
    DepthBuffer depthBuffer,
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double depthA,
    double depthB,
    double depthC,
    Color32 color,
  ) {
    assert(
      framebuffer.width == depthBuffer.width &&
          framebuffer.height == depthBuffer.height,
      'The framebuffer and depth buffer dimensions must match.',
    );
    assert(
      _isValidDepth(depthA),
      'Depth A must be finite and between 0.0 and 1.0.',
    );
    assert(
      _isValidDepth(depthB),
      'Depth B must be finite and between 0.0 and 1.0.',
    );
    assert(
      _isValidDepth(depthC),
      'Depth C must be finite and between 0.0 and 1.0.',
    );
    return _fill(
      framebuffer,
      depthBuffer,
      ax,
      ay,
      bx,
      by,
      cx,
      cy,
      depthA,
      depthB,
      depthC,
      color,
    );
  }

  static int _fill(
    SoftwareFramebuffer framebuffer,
    DepthBuffer? depthBuffer,
    double ax,
    double ay,
    double bx,
    double by,
    double cx,
    double cy,
    double? depthA,
    double? depthB,
    double? depthC,
    Color32 color,
  ) {
    final area = _edge(ax, ay, bx, by, cx, cy);
    if (area == 0.0) {
      return 0;
    }

    final minX = _minimum(ax, bx, cx).floor().clamp(0, framebuffer.width - 1);
    final maxX = _maximum(ax, bx, cx).ceil().clamp(0, framebuffer.width - 1);
    final minY = _minimum(ay, by, cy).floor().clamp(0, framebuffer.height - 1);
    final maxY = _maximum(ay, by, cy).ceil().clamp(0, framebuffer.height - 1);

    var writtenPixels = 0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final sampleX = x + 0.5;
        final sampleY = y + 0.5;
        final edgeAB = _edge(ax, ay, bx, by, sampleX, sampleY);
        final edgeBC = _edge(bx, by, cx, cy, sampleX, sampleY);
        final edgeCA = _edge(cx, cy, ax, ay, sampleX, sampleY);
        final inside = area > 0
            ? edgeAB >= 0 && edgeBC >= 0 && edgeCA >= 0
            : edgeAB <= 0 && edgeBC <= 0 && edgeCA <= 0;

        if (inside) {
          if (depthBuffer != null) {
            final depth =
                (edgeBC * depthA! + edgeCA * depthB! + edgeAB * depthC!) / area;
            if (!depthBuffer.testAndSet(x, y, depth)) {
              continue;
            }
          }
          framebuffer.setPixel(x, y, color);
          writtenPixels++;
        }
      }
    }

    return writtenPixels;
  }

  static bool _isValidDepth(double depth) =>
      depth.isFinite && depth >= 0.0 && depth <= 1.0;

  static double _edge(
    double startX,
    double startY,
    double endX,
    double endY,
    double pointX,
    double pointY,
  ) {
    return (endX - startX) * (pointY - startY) -
        (endY - startY) * (pointX - startX);
  }

  static double _minimum(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);

  static double _maximum(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);
}
