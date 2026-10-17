import 'package:flutter_test/flutter_test.dart';
import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:software_engine/testing/reference_scenes.dart';
import 'package:software_engine_flutter/engine_presenter.dart';
import 'package:software_engine_flutter/flutter_asset_loader.dart';

final class _CountingGame extends Game {
  _CountingGame({this.failInitialize = false});

  final bool failInitialize;
  int updates = 0;
  int renders = 0;

  @override
  Future<void> initialize(AssetLoader assets) async {
    if (failInitialize) {
      throw StateError('initialize failed');
    }
  }

  @override
  void update(double deltaTime) {
    updates++;
  }

  @override
  void render(Renderer renderer) {
    renders++;
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 500 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

EnginePresenter _presenterFor(Game game) => EnginePresenter(
  Engine(game, const FlutterAssetLoader(), logSink: const NullDiagnosticSink()),
);

void main() {
  group('EnginePresenter', () {
    testWidgets('presents an image after initialization', (tester) async {
      final presenter = _presenterFor(TriangleScene());

      await tester.runAsync(() async {
        await presenter.initialize();
        await _waitUntil(() => presenter.image != null);
      });

      expect(presenter.image, isNotNull);
      presenter.dispose();
    });

    testWidgets('ignores ticks before initialization', (tester) async {
      final game = _CountingGame();
      final presenter = _presenterFor(game);
      addTearDown(presenter.dispose);

      presenter.tick(0.1);

      expect(game.updates, 0);
      expect(game.renders, 0);
    });

    testWidgets('coalesces frame requests made during a conversion', (
      tester,
    ) async {
      final game = _CountingGame();
      final presenter = _presenterFor(game);

      await tester.runAsync(() async {
        await presenter.initialize();
        await _waitUntil(() => presenter.image != null);

        presenter
          ..tick(0.1)
          ..tick(0.1)
          ..tick(0.1);

        expect(game.updates, 3);
        expect(game.renders, 2);

        await _waitUntil(() => game.renders == 3);
      });

      expect(game.renders, 3);
      presenter.dispose();
    });

    testWidgets('measures the present step with the injected clock', (
      tester,
    ) async {
      final readings = [100, 250];
      final presenter = EnginePresenter(
        Engine(
          TriangleScene(),
          const FlutterAssetLoader(),
          logSink: const NullDiagnosticSink(),
        ),
        clock: () =>
            readings.length > 1 ? readings.removeAt(0) : readings.single,
      );
      addTearDown(presenter.dispose);

      await tester.runAsync(() async {
        await presenter.initialize();
        await _waitUntil(() => presenter.image != null);
      });

      expect(presenter.timings?.presentMicros, 150);
    });

    testWidgets('notifies listeners when initialization fails', (tester) async {
      final presenter = _presenterFor(_CountingGame(failInitialize: true));
      var notifications = 0;
      presenter.addListener(() => notifications++);

      await tester.runAsync(presenter.initialize);

      expect(notifications, 1);
      expect(presenter.image, isNull);
      expect(presenter.engine.renderError?.phase, 'initialize');
      presenter.dispose();
    });
  });
}
