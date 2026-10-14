import 'dart:ui';

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
  });

  group('Renderer.drawMesh', () {
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
