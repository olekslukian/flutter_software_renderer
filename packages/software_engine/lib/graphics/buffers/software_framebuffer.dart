import 'dart:typed_data';

import 'package:software_engine/graphics/color32.dart';

class SoftwareFramebuffer {
  SoftwareFramebuffer({
    this.width = 320,
    this.height = 240,
    this.clearColor = const Color32.fromARGB32(0x00000000),
  }) : assert(width > 0, 'width must be positive'),
       assert(height > 0, 'height must be positive'),
       _words = _allocate(width, height);

  final int width;
  final int height;
  final Color32 clearColor;
  final Uint32List _words;

  static Uint32List _allocate(int width, int height) {
    if (Endian.host != Endian.little) {
      throw UnsupportedError(
        'SoftwareFramebuffer requires a little-endian host.',
      );
    }
    return Uint32List(width * height);
  }

  void clear() => _words.fillRange(0, _words.length, clearColor.abgr);

  void setPixel(int x, int y, Color32 color) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return;
    }

    _words[y * width + x] = color.abgr;
  }

  void drawLine(int startX, int startY, int endX, int endY, Color32 color) {
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

  Color32? pixelAt(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) {
      return null;
    }

    final abgr = _words[y * width + x];
    return Color32.fromARGB(
      abgr >>> 24,
      abgr & 0xFF,
      (abgr >> 8) & 0xFF,
      (abgr >> 16) & 0xFF,
    );
  }

  Uint8List snapshot() => Uint8List.fromList(_words.buffer.asUint8List());
}
