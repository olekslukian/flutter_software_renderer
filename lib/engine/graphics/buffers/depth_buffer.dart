class DepthBuffer {
  DepthBuffer({required this.width, required this.height})
    : assert(width > 0, 'width must be positive'),
      assert(height > 0, 'height must be positive'),
      _depths = List<double>.filled(width * height, double.infinity);

  final int width;

  final int height;

  final List<double> _depths;

  void clear() {
    _depths.fillRange(0, _depths.length, double.infinity);
  }

  double? depthAt(int x, int y) {
    if (!_contains(x, y)) {
      return null;
    }
    return _depths[y * width + x];
  }

  bool testAndSet(int x, int y, double depth) {
    if (!depth.isFinite || depth < 0.0 || depth > 1.0) {
      throw ArgumentError.value(
        depth,
        'depth',
        'must be finite and between 0.0 and 1.0',
      );
    }
    if (!_contains(x, y)) {
      return false;
    }

    final index = y * width + x;
    if (depth >= _depths[index]) {
      return false;
    }

    _depths[index] = depth;
    return true;
  }

  bool _contains(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;
}
