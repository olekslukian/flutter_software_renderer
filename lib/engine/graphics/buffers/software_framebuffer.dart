import 'dart:typed_data';
import 'dart:ui';

class SoftwareFramebuffer {
  SoftwareFramebuffer({
    this.width = 320,
    this.height = 240,
    this.clearColor = const Color(0x00000000),
  }) : assert(width > 0, 'width must be positive'),
       assert(height > 0, 'height must be positive'),
       _pixels = Uint8List(width * height * 4);

  final int width;
  final int height;
  final Color clearColor;
  final Uint8List _pixels;

  void clear() {
    final argb = clearColor.toARGB32();
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    final alpha = (argb >> 24) & 0xFF;

    for (var offset = 0; offset < _pixels.length; offset += 4) {
      _pixels[offset] = red;
      _pixels[offset + 1] = green;
      _pixels[offset + 2] = blue;
      _pixels[offset + 3] = alpha;
    }
  }

  void setPixel(int x, int y, Color color) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }

    final offset = (y * width + x) * 4;
    final argb = color.toARGB32();
    _pixels[offset] = (argb >> 16) & 0xFF;
    _pixels[offset + 1] = (argb >> 8) & 0xFF;
    _pixels[offset + 2] = argb & 0xFF;
    _pixels[offset + 3] = (argb >> 24) & 0xFF;
  }

  void drawLine(int startX, int startY, int endX, int endY, Color color) {
    var x = startX;
    var y = startY;
    final deltaX = (endX - startX).abs();
    final stepX = startX < endX ? 1 : -1;
    final deltaY = -(endY - startY).abs();
    final stepY = startY < endY ? 1 : -1;
    var error = deltaX + deltaY;

    while (true) {
      setPixel(x, y, color);
      if (x == endX && y == endY) {
        break;
      }

      final doubledError = 2 * error;
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

  Color? pixelAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return null;
    }

    final offset = (y * width + x) * 4;
    return Color.fromARGB(
      _pixels[offset + 3],
      _pixels[offset],
      _pixels[offset + 1],
      _pixels[offset + 2],
    );
  }

  Uint8List snapshot() => Uint8List.fromList(_pixels);
}
