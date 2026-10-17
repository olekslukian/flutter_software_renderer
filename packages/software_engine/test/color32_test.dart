import 'package:software_engine/graphics/color32.dart';
import 'package:test/test.dart';

void main() {
  group('Color32', () {
    test('decodes ARGB32 channels', () {
      const color = Color32.fromARGB32(0x80102030);

      expect(color.alpha, 0x80);
      expect(color.red, 0x10);
      expect(color.green, 0x20);
      expect(color.blue, 0x30);
      expect(color.toARGB32(), 0x80102030);
    });

    test('builds from channels and round-trips through ARGB32', () {
      const color = Color32.fromARGB(0xFF, 0x20, 0xC7, 0xD9);

      expect(color, const Color32.fromARGB32(0xFF20C7D9));
      expect(color.toARGB32(), 0xFF20C7D9);
    });

    test('stores the framebuffer-native abgr word', () {
      const color = Color32.fromARGB32(0xFF112233);

      expect(color.abgr, 0xFF332211);
    });

    test('compares by channel value', () {
      expect(
        const Color32.fromARGB32(0xFF000000),
        isNot(const Color32.fromARGB32(0x00000000)),
      );
    });
  });
}
