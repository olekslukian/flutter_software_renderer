/// Stores one normalized depth value for each pixel in a software frame.
///
/// Depth uses the convention that smaller values are nearer: projected depth
/// runs from `0.0` at the near plane to `1.0` at the far plane. Clearing uses
/// positive infinity so even a fragment exactly on the far plane can be drawn.
class DepthBuffer {
  /// Allocates a [width]-by-[height] depth buffer. Both dimensions must be
  /// positive.
  DepthBuffer({required this.width, required this.height})
    : assert(width > 0),
      assert(height > 0),
      _depths = List<double>.filled(width * height, double.infinity);

  /// The horizontal pixel count.
  final int width;

  /// The vertical pixel count.
  final int height;

  final List<double> _depths;

  /// Resets every pixel to the farthest sentinel so a new frame has no
  /// visibility state left over from its predecessor.
  void clear() {
    _depths.fillRange(0, _depths.length, double.infinity);
  }

  /// Returns the stored depth at ([x], [y]), or `null` outside the buffer.
  double? depthAt(int x, int y) {
    if (!_contains(x, y)) return null;
    return _depths[y * width + x];
  }

  /// Stores [depth] at ([x], [y]) only if it is nearer than the existing
  /// fragment, returning whether the depth test passed.
  ///
  /// Values must be finite and within the normalized range `0.0..1.0`.
  /// Coordinates outside the buffer fail the test without writing.
  bool testAndSet(int x, int y, double depth) {
    if (!depth.isFinite || depth < 0.0 || depth > 1.0) {
      throw ArgumentError.value(
        depth,
        'depth',
        'must be finite and between 0.0 and 1.0',
      );
    }
    if (!_contains(x, y)) return false;

    final int index = y * width + x;
    if (depth >= _depths[index]) return false;

    _depths[index] = depth;
    return true;
  }

  /// Reports whether ([x], [y]) addresses a pixel in this buffer.
  bool _contains(int x, int y) =>
      x >= 0 && x < width && y >= 0 && y < height;
}
