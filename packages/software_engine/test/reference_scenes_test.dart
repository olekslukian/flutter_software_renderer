import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine/testing/file_asset_loader.dart';
import 'package:software_engine/testing/reference_scenes.dart';
import 'package:test/test.dart';

void main() {
  group('reference scenes', () {
    final scenes = <String, Game Function()>{
      'triangle': TriangleScene.new,
      'rotating cube': RotatingCubeScene.new,
      'penger': PengerScene.new,
      'overdraw': OverdrawScene.new,
    };

    for (final entry in scenes.entries) {
      test('${entry.key} draws pixels on its first frame', () async {
        final engine = Engine(
          entry.value(),
          const FileAssetLoader('../../assets'),
          logSink: const NullDiagnosticSink(),
        );
        await engine.initialize();

        engine.step(1 / 60);

        final pixels = engine.framebuffer.snapshot();
        expect(pixels.any((byte) => byte != 0), isTrue);
        expect(engine.renderError, isNull);
      });
    }
  });
}
