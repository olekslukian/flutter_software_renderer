import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

/// Demonstrates a CPU-side 3D pipeline by projecting and drawing a cube
/// directly onto Flutter's canvas.
class CubeRenderer extends ChangeNotifier {
  final v64.Matrix4 _modelMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _viewMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _projectionMatrix = v64.Matrix4.identity();
  final v64.Matrix4 _modelViewProjectionMatrix = v64.Matrix4.identity();
  final v64.Vector4 _clipPosition = v64.Vector4.zero();

  final List<v64.Vector3> _vertices = [
    v64.Vector3(-1, -1, -1),
    v64.Vector3(1, -1, -1),
    v64.Vector3(1, 1, -1),
    v64.Vector3(-1, 1, -1),
    v64.Vector3(-1, -1, 1),
    v64.Vector3(1, -1, 1),
    v64.Vector3(1, 1, 1),
    v64.Vector3(-1, 1, 1),
  ];

  final List<List<int>> _edges = const [
    [0, 1], [1, 2], [2, 3], [3, 0],
    [4, 5], [5, 6], [6, 7], [7, 4],
    [0, 4], [1, 5], [2, 6], [3, 7],
  ];

  final Paint _edgePaint = Paint()
    ..color = const Color(0xFF00FFC8)
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke;

  final Paint _vertexPaint = Paint()
    ..color = const Color(0xFFFF007F)
    ..style = PaintingStyle.fill;

  late final List<Offset> _screenPositions =
      List<Offset>.filled(_vertices.length, Offset.zero);

  double _angleX = 0.0;
  double _angleY = 0.0;
  double _angleZ = 0.0;

  /// Advances the cube's rotation by [deltaTime] seconds.
  ///
  /// Listeners are notified so Flutter can repaint the canvas without
  /// rebuilding the surrounding widget tree.
  void update(double deltaTime) {
    const double rotationSpeed = 1.2;
    _angleX += rotationSpeed * deltaTime;
    _angleY += rotationSpeed * 0.8 * deltaTime;
    _angleZ += rotationSpeed * 0.5 * deltaTime;

    _modelMatrix
      ..setIdentity()
      ..rotateX(_angleX)
      ..rotateY(_angleY)
      ..rotateZ(_angleZ);

    _viewMatrix
      ..setIdentity()
      ..setTranslationRaw(0.0, 0.0, -4.0);

    notifyListeners();
  }

  /// Projects the cube's vertices into canvas coordinates and draws its mesh.
  void render(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double aspectRatio = size.width / size.height;
    v64.setPerspectiveMatrix(
      _projectionMatrix,
      v64.radians(60.0),
      aspectRatio,
      0.1,
      100.0,
    );

    _modelViewProjectionMatrix
      ..setFrom(_projectionMatrix)
      ..multiply(_viewMatrix)
      ..multiply(_modelMatrix);

    final double halfWidth = size.width / 2.0;
    final double halfHeight = size.height / 2.0;

    for (int i = 0; i < _vertices.length; i++) {
      final v64.Vector3 vertex = _vertices[i];
      _clipPosition.setValues(vertex.x, vertex.y, vertex.z, 1.0);
      _modelViewProjectionMatrix.transform(_clipPosition);

      if (_clipPosition.w != 0.0) {
        _clipPosition.x /= _clipPosition.w;
        _clipPosition.y /= _clipPosition.w;
      }

      _screenPositions[i] = Offset(
        halfWidth + (_clipPosition.x * halfWidth),
        halfHeight - (_clipPosition.y * halfHeight),
      );
    }

    for (final List<int> edge in _edges) {
      canvas.drawLine(
        _screenPositions[edge[0]],
        _screenPositions[edge[1]],
        _edgePaint,
      );
    }

    for (final Offset position in _screenPositions) {
      canvas.drawCircle(position, 4.0, _vertexPaint);
    }
  }
}

/// Connects renderer notifications to Flutter's paint-only update path.
class Software3DPainter extends CustomPainter {
  Software3DPainter({required this.renderer}) : super(repaint: renderer);

  final CubeRenderer renderer;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant Software3DPainter oldDelegate) {
    return oldDelegate.renderer != renderer;
  }
}
