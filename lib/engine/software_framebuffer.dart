import 'dart:typed_data';
import 'dart:ui';

/// A small CPU-owned RGBA image that software renderers can write into.
class SoftwareFramebuffer {
  /// Allocates a [width]-by-[height] RGBA pixel buffer and sets its default
  /// [clearColor]. Both dimensions must be positive.
  SoftwareFramebuffer({
    this.width = 320,
    this.height = 240,
    this.clearColor = const Color(0x00000000),
  }) : assert(width > 0),
       assert(height > 0),
       _pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Color clearColor;
  final Uint8List _pixels;

  /// Fills every pixel with [clearColor], writing the color's red, green, blue,
  /// and alpha channels in RGBA byte order. Call this before drawing a new
  /// frame to prevent pixels from a previous frame from remaining visible.
  void clear() {
    final int argb = clearColor.toARGB32();
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

  /// Writes [color] at ([x], [y]) using RGBA byte order. Coordinates outside
  /// the framebuffer are ignored, allowing callers to clip simply by drawing
  /// without a separate bounds check.
  void setPixel(int x, int y, Color color) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;

    final int offset = (y * width + x) * 4;
    final int argb = color.toARGB32();
    _pixels[offset] = (argb >> 16) & 0xFF;
    _pixels[offset + 1] = (argb >> 8) & 0xFF;
    _pixels[offset + 2] = argb & 0xFF;
    _pixels[offset + 3] = (argb >> 24) & 0xFF;
  }

  /// Draws a one-pixel-wide line from ([startX], [startY]) to ([endX], [endY])
  /// using Bresenham's integer error stepping. The inclusive traversal chooses
  /// the nearest pixel at each step for any line slope; [setPixel] clips steps
  /// that fall outside the framebuffer.
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

  /// Returns the pixel at ([x], [y]) as a Flutter [Color], or `null` when the
  /// coordinates lie outside the framebuffer. The stored RGBA channels are
  /// converted back to the ARGB argument order expected by [Color.fromARGB].
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

  /// Returns an independent copy of the current RGBA bytes. The copy is
  /// unaffected by subsequent framebuffer writes, which makes it safe to pass
  /// to an asynchronous image decoder while rendering continues.
  Uint8List snapshot() => Uint8List.fromList(_pixels);
}
