import 'dart:typed_data';
import 'dart:ui';

/// A small CPU-owned RGBA image that software renderers can write into.
class SoftwareFramebuffer {
  SoftwareFramebuffer({this.width = 320, this.height = 240})
    : assert(width > 0),
      assert(height > 0),
      _pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Uint8List _pixels;

  /// Clears the whole image to [color] before drawing the next frame.
  void clear([Color color = const Color(0x00000000)]) {
    final int argb = color.toARGB32();
    final int red = (argb >> 16) & 0xFF;
    final int green = (argb >> 8) & 0xFF;
    final int blue = argb & 0xFF;
    final int alpha = (argb >> 24) & 0xFF;

    for (int offset = 0; offset < _pixels.length; offset += 4) {
      _pixels[offset] = red;
      _pixels[offset + 1] = green;
      _pixels[offset + 2] = blue;
      _pixels[offset + 3] = alpha;
    }
  }

  /// Writes one pixel in RGBA order; coordinates outside the image are ignored.
  void setPixel(int x, int y, Color color) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;

    final int offset = (y * width + x) * 4;
    final int argb = color.toARGB32();
    _pixels[offset] = (argb >> 16) & 0xFF;
    _pixels[offset + 1] = (argb >> 8) & 0xFF;
    _pixels[offset + 2] = argb & 0xFF;
    _pixels[offset + 3] = (argb >> 24) & 0xFF;
  }

  /// Draws a one-pixel line with Bresenham's integer stepping algorithm.
  void drawLine(int startX, int startY, int endX, int endY, Color color) {
    int x = startX;
    int y = startY;
    final int deltaX = (endX - startX).abs();
    final int stepX = startX < endX ? 1 : -1;
    final int deltaY = -(endY - startY).abs();
    final int stepY = startY < endY ? 1 : -1;
    int error = deltaX + deltaY;

    while (true) {
      setPixel(x, y, color);
      if (x == endX && y == endY) break;

      final int doubledError = 2 * error;
      if (doubledError >= deltaY) {
        error += deltaY;
        x += stepX;
      }
      if (doubledError <= deltaX) {
        error += deltaX;
        y += stepY;
      }
    }
  }

  /// Reads a pixel as a Flutter color, or returns null outside the image.
  Color? pixelAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return null;

    final int offset = (y * width + x) * 4;
    return Color.fromARGB(
      _pixels[offset + 3],
      _pixels[offset],
      _pixels[offset + 1],
      _pixels[offset + 2],
    );
  }

  /// Copies the pixels so asynchronous image decoding cannot observe later writes.
  Uint8List snapshot() => Uint8List.fromList(_pixels);
}
