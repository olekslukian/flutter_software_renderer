import 'dart:ui';

import '../buffers/depth_buffer.dart';
import '../buffers/software_framebuffer.dart';
import '../../triangle_rasterizer.dart';

/// Coordinates CPU triangle rasterization into a color and depth buffer.
class Renderer {
  /// Creates a renderer targeting the engine-owned [framebuffer] and allocates
  /// a matching depth buffer.
  Renderer(this.framebuffer)
    : depthBuffer = DepthBuffer(
        width: framebuffer.width,
        height: framebuffer.height,
      );

  /// The color target into which submitted triangles are rasterized.
  final SoftwareFramebuffer framebuffer;

  /// The per-pixel visibility buffer paired with [framebuffer].
  final DepthBuffer depthBuffer;

  /// Clears color and depth state before the game submits a new frame.
  void beginFrame() {
    framebuffer.clear();
    depthBuffer.clear();
  }

  /// Rasterizes a projected triangle with normalized per-vertex depths.
  ///
  /// Coordinates are in framebuffer pixel space. Depths are in the range
  /// `0.0..1.0`, where smaller values are nearer; fragments farther than the
  /// value already stored at a pixel are discarded.
  int drawTriangle({
    required Offset a,
    required Offset b,
    required Offset c,
    required double depthA,
    required double depthB,
    required double depthC,
    required Color color,
  }) {
    return TriangleRasterizer.fillWithDepth(
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
}
