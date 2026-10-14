import 'dart:ui';

import 'package:flutter_software_renderer/engine/diagnostics/engine_diagnostic.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/perspective_camera.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh_pipeline.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  group('MeshPipeline', () {
    test('projects vertices through the model and camera', () {
      final camera = PerspectiveCamera(
        position: v64.Vector3(0, 0, 4),
        target: v64.Vector3.zero(),
      )..configureViewport(16, 16);
      final mesh = Mesh(vertices: [v64.Vector3.zero()], indices: const []);
      final pipeline = MeshPipeline()
        ..projectVertices(mesh, Transform3(), camera);

      expect(pipeline.screenPositions.single.dx, closeTo(8.0, 1e-9));
      expect(pipeline.screenPositions.single.dy, closeTo(8.0, 1e-9));
    });

    test('requires a configured camera viewport', () {
      final camera = PerspectiveCamera(
        position: v64.Vector3(0, 0, 4),
        target: v64.Vector3.zero(),
      );
      final mesh = Mesh(vertices: [v64.Vector3.zero()], indices: const []);

      expect(
        () => MeshPipeline().projectVertices(mesh, Transform3(), camera),
        throwsStateError,
      );
    });

    test('counts vertices on the camera plane instead of aborting', () {
      final camera = PerspectiveCamera(
        position: v64.Vector3(0, 0, 4),
        target: v64.Vector3.zero(),
      )..configureViewport(16, 16);
      final mesh = Mesh(
        vertices: [
          v64.Vector3(0, 0, 4),
          v64.Vector3(-1, -1, 0),
          v64.Vector3(1, -1, 0),
        ],
        indices: const [0, 1, 2],
      );
      final pipeline = MeshPipeline();

      final unprojectable = pipeline.projectVertices(
        mesh,
        Transform3(),
        camera,
      );

      expect(unprojectable, 1);
      expect(pipeline.depths[0].isNaN, isTrue);
      expect(pipeline.depths[1].isNaN, isFalse);
      expect(pipeline.depths[2].isNaN, isFalse);
    });
  });

  group('Renderer.drawMesh', () {
    test('reports unprojectable vertices and still draws the frame', () {
      final sink = _RecordingSink();
      final renderer = Renderer(
        SoftwareFramebuffer(width: 16, height: 16),
        diagnostics: sink,
      )..beginFrame();
      final mesh = Mesh(
        vertices: [
          v64.Vector3(0, 0, 4),
          v64.Vector3(-1, -1, 0),
          v64.Vector3(1, -1, 0),
        ],
        indices: const [0, 1, 2],
      );

      renderer.drawMesh(
        mesh: mesh,
        transform: Transform3(),
        color: const Color(0xFFFF0000),
        camera: PerspectiveCamera(
          position: v64.Vector3(0, 0, 4),
          target: v64.Vector3.zero(),
        )..configureViewport(16, 16),
      );

      expect(sink.reports, hasLength(1));
      expect(sink.reports.single.severity, DiagnosticSeverity.warning);
      expect(sink.reports.single.phase, 'render');
    });

    test('fills a triangle covered by the projected mesh', () {
      final renderer = Renderer(SoftwareFramebuffer(width: 4, height: 4))
        ..beginFrame();
      final mesh = Mesh(
        vertices: [
          v64.Vector3(-1, -1, 0),
          v64.Vector3(1, -1, 0),
          v64.Vector3(0, 1, 0),
        ],
        indices: const [0, 1, 2],
      );

      final drawn = renderer.drawMesh(
        mesh: mesh,
        transform: Transform3(),
        camera: PerspectiveCamera(
          position: v64.Vector3(0, 0, 4),
          target: v64.Vector3.zero(),
        ),
        color: const Color(0xFFFF0000),
      );

      expect(drawn, 1);
      expect(renderer.framebuffer.pixelAt(2, 2), const Color(0xFFFF0000));
    });

    test('skips triangles whose depth lies outside [0, 1]', () {
      final renderer = Renderer(SoftwareFramebuffer(width: 4, height: 4))
        ..beginFrame();
      final mesh = Mesh(
        vertices: [
          v64.Vector3(-1, -1, 0),
          v64.Vector3(1, -1, 0),
          v64.Vector3(0, 1, 0),
        ],
        indices: const [0, 1, 2],
      );

      final drawn = renderer.drawMesh(
        mesh: mesh,
        transform: Transform3(),
        camera: PerspectiveCamera(
          position: v64.Vector3(0, 0, 0.05),
          target: v64.Vector3.zero(),
        ),
        color: const Color(0xFFFF0000),
      );

      expect(drawn, 0);
      expect(renderer.framebuffer.pixelAt(2, 2), const Color(0x00000000));
    });
  });
}

final class _RecordingSink implements DiagnosticSink {
  final List<EngineDiagnostic> reports = [];

  @override
  void report(EngineDiagnostic diagnostic) => reports.add(diagnostic);
}
