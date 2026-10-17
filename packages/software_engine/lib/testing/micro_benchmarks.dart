import 'dart:typed_data';

import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/buffers/software_framebuffer.dart';
import 'package:software_engine/graphics/camera/perspective_camera.dart';
import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/mesh.dart';
import 'package:software_engine/graphics/mesh_pipeline.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:software_engine/graphics/triangle_rasterizer.dart';
import 'package:software_engine/math/transform3.dart';
import 'package:software_engine/testing/benchmark.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

const _width = 320;
const _height = 240;

Future<List<BenchmarkCase>> microBenchmarkCases(AssetLoader assets) async {
  final objText = await assets.loadString('models/penger.obj');

  BenchmarkCase synthetic(
    String name,
    Future<BenchmarkTarget> Function() create,
  ) => BenchmarkCase(
    name: name,
    scene: 'synthetic',
    width: _width,
    height: _height,
    create: create,
  );

  return [
    synthetic('clear', () async => _ClearTarget()),
    synthetic(
      'triangle_fill_small',
      () async => _TriangleFillTarget([10, 10, 30, 10, 10, 30]),
    ),
    synthetic(
      'triangle_fill_medium',
      () async => _TriangleFillTarget([40, 30, 200, 30, 40, 150]),
    ),
    synthetic(
      'triangle_fill_full_screen',
      () async => _TriangleFillTarget([-1, -1, 641, -1, -1, 481]),
    ),
    synthetic('depth_test', () async => _DepthTestTarget()),
    synthetic('project_vertices', () async {
      final mesh = Mesh.fromObj(objText).normalized();
      return _ProjectTarget(mesh);
    }),
    synthetic('obj_parse', () async => _ObjParseTarget(objText)),
  ];
}

final class _ClearTarget implements BenchmarkTarget {
  final SoftwareFramebuffer _framebuffer = SoftwareFramebuffer(
    clearColor: const Color32.fromARGB32(0xFF112233),
  );

  @override
  void iterate() {
    _framebuffer.clear();
  }

  @override
  Uint8List pixels() => _framebuffer.snapshot();
}

final class _TriangleFillTarget implements BenchmarkTarget {
  _TriangleFillTarget(this._corners);

  final List<double> _corners;

  final SoftwareFramebuffer _framebuffer = SoftwareFramebuffer();

  @override
  void iterate() {
    TriangleRasterizer.fill(
      _framebuffer,
      _corners[0],
      _corners[1],
      _corners[2],
      _corners[3],
      _corners[4],
      _corners[5],
      const Color32.fromARGB32(0xFFFF0000),
    );
  }

  @override
  Uint8List pixels() => _framebuffer.snapshot();
}

final class _DepthTestTarget implements BenchmarkTarget {
  final Renderer _renderer = Renderer(SoftwareFramebuffer());

  @override
  void iterate() {
    _renderer
      ..beginFrame()
      ..drawTriangle(
        ax: -1,
        ay: -1,
        bx: 641,
        by: -1,
        cx: -1,
        cy: 481,
        depthA: 0.2,
        depthB: 0.2,
        depthC: 0.2,
        color: const Color32.fromARGB32(0xFF00FF00),
      )
      ..drawTriangle(
        ax: -1,
        ay: -1,
        bx: 641,
        by: -1,
        cx: -1,
        cy: 481,
        depthA: 0.8,
        depthB: 0.8,
        depthC: 0.8,
        color: const Color32.fromARGB32(0xFFFF0000),
      );
  }

  @override
  Uint8List pixels() => _renderer.framebuffer.snapshot();
}

final class _ProjectTarget implements BenchmarkTarget {
  _ProjectTarget(this._mesh);

  final Mesh _mesh;

  final MeshPipeline _pipeline = MeshPipeline();

  final Transform3 _transform = Transform3();

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0, 0, 4.5),
    target: v64.Vector3.zero(),
  )..configureViewport(_width, _height);

  @override
  void iterate() {
    _pipeline.projectVertices(_mesh, _transform, _camera);
  }

  @override
  Uint8List pixels() => _pipeline.screenX.buffer.asUint8List();
}

final class _ObjParseTarget implements BenchmarkTarget {
  _ObjParseTarget(this._text);

  final String _text;

  Mesh? _lastMesh;

  @override
  void iterate() {
    _lastMesh = Mesh.fromObj(_text);
  }

  @override
  Uint8List pixels() {
    final indices = _lastMesh?.indices ?? const <int>[];
    return Int32List.fromList(indices).buffer.asUint8List();
  }
}
