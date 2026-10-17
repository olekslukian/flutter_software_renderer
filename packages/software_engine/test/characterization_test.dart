import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/testing/file_asset_loader.dart';
import 'package:software_engine/testing/framebuffer_hash.dart';
import 'package:software_engine/testing/reference_scenes.dart';
import 'package:test/test.dart';

void main() {
  test('penger scene matches the pre-refactor pixels', () async {
    const expected = <int, int>{
      1: 0x8ab934b5,
      2: 0xdb3be0c5,
      3: 0x1d36fda9,
      10: 0x0a7d63a5,
      40: 0x04a18a65,
      90: 0x10300cc5,
    };
    final engine = Engine(
      PengerScene(),
      const FileAssetLoader('../../assets'),
      logSink: const NullDiagnosticSink(),
    );
    await engine.initialize();

    for (var frame = 1; frame <= 90; frame++) {
      engine.step(1 / 60);
      final expectedHash = expected[frame];
      if (expectedHash != null) {
        expect(
          fnv1a32(engine.framebuffer.snapshot()),
          expectedHash,
          reason: 'frame $frame changed',
        );
      }
    }
  });
}
