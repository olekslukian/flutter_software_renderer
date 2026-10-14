import 'dart:ui';

import 'package:flutter_software_renderer/engine/diagnostics/engine_diagnostic.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/depth_buffer.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/camera.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh_pipeline.dart';
import 'package:flutter_software_renderer/engine/graphics/triangle_rasterizer.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';

class Renderer {
  Renderer(
    this.framebuffer, {
    DiagnosticSink diagnostics = const NullDiagnosticSink(),
  }) : depthBuffer = DepthBuffer(
         width: framebuffer.width,
         height: framebuffer.height,
       ),
       _diagnostics = diagnostics;

  final SoftwareFramebuffer framebuffer;

  final DepthBuffer depthBuffer;

  final DiagnosticSink _diagnostics;

  final MeshPipeline _meshPipeline = MeshPipeline();

  void beginFrame() {
    framebuffer.clear();
    depthBuffer.clear();
  }

  int drawMesh({
    required Mesh mesh,
    required Transform3 transform,
    required Camera camera,
    required Color color,
  }) {
    camera.configureViewport(framebuffer.width, framebuffer.height);
    final unprojectableVertices = _meshPipeline.projectVertices(
      mesh,
      transform,
      camera,
    );
    if (unprojectableVertices > 0) {
      _diagnostics.report(
        EngineDiagnostic(
          severity: DiagnosticSeverity.warning,
          phase: 'render',
          message:
              '$unprojectableVertices vertices could not be projected; '
              'their triangles were skipped.',
        ),
      );
    }

    final screenPositions = _meshPipeline.screenPositions;
    final depths = _meshPipeline.depths;
    final indices = mesh.indices;
    var trianglesDrawn = 0;
    var trianglesSkipped = 0;
    for (var triangle = 0; triangle < indices.length; triangle += 3) {
      final a = indices[triangle];
      final b = indices[triangle + 1];
      final c = indices[triangle + 2];
      if (!_isWithinDepthRange(depths[a]) ||
          !_isWithinDepthRange(depths[b]) ||
          !_isWithinDepthRange(depths[c])) {
        trianglesSkipped++;
        continue;
      }
      drawTriangle(
        a: screenPositions[a],
        b: screenPositions[b],
        c: screenPositions[c],
        depthA: depths[a],
        depthB: depths[b],
        depthC: depths[c],
        color: color,
      );
      trianglesDrawn++;
    }
    if (trianglesSkipped > 0 && unprojectableVertices == 0) {
      _diagnostics.report(
        EngineDiagnostic(
          severity: DiagnosticSeverity.warning,
          phase: 'render',
          message:
              '$trianglesSkipped triangles lie outside the camera depth range '
              'and were skipped.',
        ),
      );
    }
    return trianglesDrawn;
  }

  static bool _isWithinDepthRange(double depth) =>
      depth.isFinite && depth >= 0.0 && depth <= 1.0;

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
