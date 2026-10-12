import 'dart:ui';

import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/graphics/camera/perspective_camera.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';
import 'package:flutter_software_renderer/engine/math/transform3.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class ModelViewDemo extends Game {
  ModelViewDemo({
    super.clearColor,
    super.width,
    super.height,
    this.modelAssetPath = 'assets/models/penger.obj',
    Mesh? mesh,
    this.modelColor = const Color(0xFF20C7D9),
  }) : _mesh = mesh;

  final String modelAssetPath;

  final Color modelColor;

  Mesh? _mesh;

  final Transform3 _transform = Transform3(
    rotation: v64.Vector3(0.0, 0.45, 0.0),
  );

  final PerspectiveCamera _camera = PerspectiveCamera(
    position: v64.Vector3(0.0, 0.0, 4.5),
    target: v64.Vector3.zero(),
  );

  List<v64.Vector3> _normalizedVertices = [];
  List<v64.Vector4> _transformedPositions = [];
  List<v64.Vector3> _worldPositions = [];
  List<Offset> _screenPositions = [];
  List<double> _depths = [];

  @override
  Future<void> initialize() async {
    _mesh ??= await Mesh.loadFromAsset(modelAssetPath);
    _prepareMesh(_mesh!);
    _transform.rotation.setValues(0.45 * 0.7, 0.45, 0.45 * 0.35);
    _transform.updateMatrix();
  }

  /// Centers and uniformly scales the loaded model, and allocates working
  /// storage based on its actual vertex count.
  void _prepareMesh(Mesh mesh) {
    if (mesh.indices.length % 3 != 0) {
      throw ArgumentError('Mesh indices must contain complete triangles.');
    }
    for (final int index in mesh.indices) {
      if (index < 0 || index >= mesh.vertices.length) {
        throw ArgumentError.value(index, 'mesh.indices', 'is out of range');
      }
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double minZ = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    double maxZ = double.negativeInfinity;
    for (final v64.Vector3 vertex in mesh.vertices) {
      if (!vertex.x.isFinite || !vertex.y.isFinite || !vertex.z.isFinite) {
        throw ArgumentError('Mesh vertices must have finite coordinates.');
      }
      if (vertex.x < minX) minX = vertex.x;
      if (vertex.y < minY) minY = vertex.y;
      if (vertex.z < minZ) minZ = vertex.z;
      if (vertex.x > maxX) maxX = vertex.x;
      if (vertex.y > maxY) maxY = vertex.y;
      if (vertex.z > maxZ) maxZ = vertex.z;
    }
    if (mesh.vertices.isEmpty) {
      throw ArgumentError('Mesh must contain at least one vertex.');
    }

    final double centerX = (minX + maxX) / 2.0;
    final double centerY = (minY + maxY) / 2.0;
    final double centerZ = (minZ + maxZ) / 2.0;
    final double largestExtent = [
      maxX - minX,
      maxY - minY,
      maxZ - minZ,
    ].reduce((double a, double b) => a > b ? a : b);
    if (largestExtent == 0.0) {
      throw ArgumentError('Mesh vertices must span a non-zero volume.');
    }
    final double normalizationScale = 2.0 / largestExtent;

    // Centering in local space makes the model rotate around its own bounds.
    _normalizedVertices = mesh.vertices
        .map(
          (v64.Vector3 vertex) => v64.Vector3(
            (vertex.x - centerX) * normalizationScale,
            (vertex.y - centerY) * normalizationScale,
            (vertex.z - centerZ) * normalizationScale,
          ),
        )
        .toList(growable: false);
    _transformedPositions = List<v64.Vector4>.generate(
      mesh.vertices.length,
      (_) => v64.Vector4.zero(),
      growable: false,
    );
    _worldPositions = List<v64.Vector3>.generate(
      mesh.vertices.length,
      (_) => v64.Vector3.zero(),
      growable: false,
    );
    _screenPositions = List<Offset>.filled(
      mesh.vertices.length,
      Offset.zero,
      growable: false,
    );
    _depths = List<double>.filled(mesh.vertices.length, 1.0, growable: false);
  }

  @override
  void update(double deltaTime) {
    final double angle = _transform.rotation.y + 1.2 * deltaTime;
    _transform.rotation.setValues(angle * 0.7, angle, angle * 0.35);
    _transform.updateMatrix();
  }

  @override
  void render(Renderer renderer) {
    final int width = renderer.framebuffer.width;
    final int height = renderer.framebuffer.height;
    _camera.configureViewport(width, height);

    final Mesh? mesh = _mesh;
    if (mesh == null) return;

    for (int index = 0; index < _normalizedVertices.length; index++) {
      final v64.Vector3 vertex = _normalizedVertices[index];
      final v64.Vector4 transformedPosition = _transformedPositions[index];
      _transform.transformPosition(vertex, transformedPosition);
      final v64.Vector3 worldPosition = _worldPositions[index]
        ..setValues(
          transformedPosition.x,
          transformedPosition.y,
          transformedPosition.z,
        );
      final ProjectedVertex projected = _camera.project(worldPosition);
      _screenPositions[index] = projected.position;
      _depths[index] = projected.depth;
    }

    for (int triangle = 0; triangle < mesh.indices.length; triangle += 3) {
      final int a = mesh.indices[triangle];
      final int b = mesh.indices[triangle + 1];
      final int c = mesh.indices[triangle + 2];
      if (!_depths[a].isFinite ||
          _depths[a] < 0.0 ||
          _depths[a] > 1.0 ||
          !_depths[b].isFinite ||
          _depths[b] < 0.0 ||
          _depths[b] > 1.0 ||
          !_depths[c].isFinite ||
          _depths[c] < 0.0 ||
          _depths[c] > 1.0) {
        // Full clipping is a later pipeline stage; skip faces outside the
        // camera's depth interval rather than passing invalid depths onward.
        continue;
      }
      renderer.drawTriangle(
        a: _screenPositions[a],
        b: _screenPositions[b],
        c: _screenPositions[c],
        depthA: _depths[a],
        depthB: _depths[b],
        depthC: _depths[c],
        color: modelColor,
      );
    }
  }
}
