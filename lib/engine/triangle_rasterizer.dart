import 'dart:ui';

import 'software_framebuffer.dart';

/// Fills a 2D triangle by testing each pixel center against its three edges.
class TriangleRasterizer {
  const TriangleRasterizer._();

  static int fill(
    SoftwareFramebuffer framebuffer,
    Offset a,
    Offset b,
    Offset c,
    Color color,
  ) {
    final double area = _edge(a, b, c);
    if (area == 0.0) return 0;

    // Only visit pixels near the shape instead of scanning the entire image.
    final int minX = _minimum(a.dx, b.dx, c.dx).floor().clamp(
      0,
      framebuffer.width - 1,
    );
    final int maxX = _maximum(a.dx, b.dx, c.dx).ceil().clamp(
      0,
      framebuffer.width - 1,
    );
    final int minY = _minimum(a.dy, b.dy, c.dy).floor().clamp(
      0,
      framebuffer.height - 1,
    );
    final int maxY = _maximum(a.dy, b.dy, c.dy).ceil().clamp(
      0,
      framebuffer.height - 1,
    );

    int writtenPixels = 0;
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        // Sampling at the center makes coverage consistent for every pixel.
        final Offset sample = Offset(x + 0.5, y + 0.5);
        final double edgeAB = _edge(a, b, sample);
        final double edgeBC = _edge(b, c, sample);
        final double edgeCA = _edge(c, a, sample);
        final bool inside = area > 0
            ? edgeAB >= 0 && edgeBC >= 0 && edgeCA >= 0
            : edgeAB <= 0 && edgeBC <= 0 && edgeCA <= 0;

        if (inside) {
          framebuffer.setPixel(x, y, color);
          writtenPixels++;
        }
      }
    }

    return writtenPixels;
  }

  static double _edge(Offset start, Offset end, Offset point) {
    return (end.dx - start.dx) * (point.dy - start.dy) -
        (end.dy - start.dy) * (point.dx - start.dx);
  }

  static double _minimum(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);

  static double _maximum(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);
}
