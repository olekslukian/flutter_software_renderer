import 'dart:ui';

import 'buffers/depth_buffer.dart';
import 'buffers/software_framebuffer.dart';

/// Fills a 2D triangle by testing each pixel center against its three edges.
abstract class TriangleRasterizer {
  /// Fills the portion of [framebuffer] covered by the triangle with vertices
  /// [a], [b], and [c], returning the number of pixel centers covered.
  ///
  /// Degenerate triangles with zero signed area write no pixels. Otherwise,
  /// the method clamps the triangle's bounding box to the framebuffer, samples
  /// each candidate pixel at its center, and tests the three directed edge
  /// functions against the triangle's winding. Coverage is therefore evaluated
  /// consistently for either clockwise or counterclockwise vertex order.
  static int fill(
    SoftwareFramebuffer framebuffer,
    Offset a,
    Offset b,
    Offset c,
    Color color,
  ) {
    return _fill(framebuffer, null, a, b, c, null, null, null, color);
  }

  /// Fills a projected triangle while interpolating its per-vertex normalized
  /// depths and testing each covered pixel against [depthBuffer].
  ///
  /// Depth uses the convention that smaller values are nearer. A depth value
  /// is written only when its fragment passes the depth test. The framebuffer
  /// and depth buffer must have matching dimensions.
  static int fillWithDepth(
    SoftwareFramebuffer framebuffer,
    DepthBuffer depthBuffer,
    Offset a,
    Offset b,
    Offset c,
    double depthA,
    double depthB,
    double depthC,
    Color color,
  ) {
    if (framebuffer.width != depthBuffer.width ||
        framebuffer.height != depthBuffer.height) {
      throw ArgumentError(
        'The framebuffer and depth buffer dimensions must match.',
      );
    }
    _validateDepth(depthA);
    _validateDepth(depthB);
    _validateDepth(depthC);
    return _fill(
      framebuffer,
      depthBuffer,
      a,
      b,
      c,
      depthA,
      depthB,
      depthC,
      color,
    );
  }

  /// Rasterizes [a], [b], and [c] once for both color-only and depth-tested
  /// fills, returning the number of covered pixels that were written.
  static int _fill(
    SoftwareFramebuffer framebuffer,
    DepthBuffer? depthBuffer,
    Offset a,
    Offset b,
    Offset c,
    double? depthA,
    double? depthB,
    double? depthC,
    Color color,
  ) {
    final double area = _edge(a, b, c);
    if (area == 0.0) return 0;

    final int minX = _minimum(
      a.dx,
      b.dx,
      c.dx,
    ).floor().clamp(0, framebuffer.width - 1);
    final int maxX = _maximum(
      a.dx,
      b.dx,
      c.dx,
    ).ceil().clamp(0, framebuffer.width - 1);
    final int minY = _minimum(
      a.dy,
      b.dy,
      c.dy,
    ).floor().clamp(0, framebuffer.height - 1);
    final int maxY = _maximum(
      a.dy,
      b.dy,
      c.dy,
    ).ceil().clamp(0, framebuffer.height - 1);

    int writtenPixels = 0;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        final Offset sample = Offset(x + 0.5, y + 0.5);
        final double edgeAB = _edge(a, b, sample);
        final double edgeBC = _edge(b, c, sample);
        final double edgeCA = _edge(c, a, sample);
        final bool inside = area > 0
            ? edgeAB >= 0 && edgeBC >= 0 && edgeCA >= 0
            : edgeAB <= 0 && edgeBC <= 0 && edgeCA <= 0;

        if (inside) {
          if (depthBuffer != null) {
            final double depth =
                (edgeBC * depthA! + edgeCA * depthB! + edgeAB * depthC!) / area;
            if (!depthBuffer.testAndSet(x, y, depth)) continue;
          }
          framebuffer.setPixel(x, y, color);
          writtenPixels++;
        }
      }
    }

    return writtenPixels;
  }

  /// Rejects projected vertex depths outside the normalized depth interval.
  static void _validateDepth(double depth) {
    if (!depth.isFinite || depth < 0.0 || depth > 1.0) {
      throw ArgumentError.value(
        depth,
        'depth',
        'must be finite and between 0.0 and 1.0',
      );
    }
  }

  /// Computes the signed 2D cross product of the [start]-to-[end] edge and the
  /// [start]-to-[point] vector. Its sign indicates which side of the directed
  /// edge contains [point], and its magnitude is twice the corresponding
  /// triangle's signed area.
  static double _edge(Offset start, Offset end, Offset point) {
    return (end.dx - start.dx) * (point.dy - start.dy) -
        (end.dy - start.dy) * (point.dx - start.dx);
  }

  /// Returns the smallest of three coordinates for the triangle's x/y bounds.
  static double _minimum(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);

  /// Returns the largest of three coordinates for the triangle's x/y bounds.
  static double _maximum(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);
}
