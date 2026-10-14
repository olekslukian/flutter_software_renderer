import 'dart:ui';

import 'package:flutter_software_renderer/engine/graphics/buffers/depth_buffer.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';

abstract class TriangleRasterizer {
  static int fill(
    SoftwareFramebuffer framebuffer,
    Offset a,
    Offset b,
    Offset c,
    Color color,
  ) {
    return _fill(framebuffer, null, a, b, c, null, null, null, color);
  }

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
      a,
      b,
      c,
      depthA,
      depthB,
      depthC,
      color,
    );
  }

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
    final area = _edge(a, b, c);
    if (area == 0.0) {
      return 0;
    }

    final minX = _minimum(
      a.dx,
      b.dx,
      c.dx,
    ).floor().clamp(0, framebuffer.width - 1);
    final maxX = _maximum(
      a.dx,
      b.dx,
      c.dx,
    ).ceil().clamp(0, framebuffer.width - 1);
    final minY = _minimum(
      a.dy,
      b.dy,
      c.dy,
    ).floor().clamp(0, framebuffer.height - 1);
    final maxY = _maximum(
      a.dy,
      b.dy,
      c.dy,
    ).ceil().clamp(0, framebuffer.height - 1);

    var writtenPixels = 0;
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final sample = Offset(x + 0.5, y + 0.5);
        final edgeAB = _edge(a, b, sample);
        final edgeBC = _edge(b, c, sample);
        final edgeCA = _edge(c, a, sample);
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

  static double _edge(Offset start, Offset end, Offset point) {
    return (end.dx - start.dx) * (point.dy - start.dy) -
        (end.dy - start.dy) * (point.dx - start.dx);
  }

  static double _minimum(double a, double b, double c) =>
      a < b ? (a < c ? a : c) : (b < c ? b : c);

  static double _maximum(double a, double b, double c) =>
      a > b ? (a > c ? a : c) : (b > c ? b : c);
}
