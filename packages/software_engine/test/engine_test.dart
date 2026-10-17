import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/renderer.dart';
import 'package:test/test.dart';

final class _RecordingSink implements DiagnosticSink {
  final List<EngineDiagnostic> reports = [];

  @override
  void report(EngineDiagnostic diagnostic) => reports.add(diagnostic);
}

final class _NoAssets implements AssetLoader {
  @override
  Future<String> loadString(String path) async => '';
}

final class _ScriptedGame extends Game {
  _ScriptedGame({this.failInitialize = false});

  final bool failInitialize;
  bool failRender = false;
  int initializeCalls = 0;
  int renderCalls = 0;
  final List<double> updates = [];

  @override
  Future<void> initialize(AssetLoader assets) async {
    initializeCalls++;
    if (failInitialize) {
      throw StateError('initialize failed');
    }
  }

  @override
  void update(double deltaTime) => updates.add(deltaTime);

  @override
  void render(Renderer renderer) {
    renderCalls++;
    if (failRender) {
      throw StateError('render failed');
    }
  }
}

void main() {
  group('Engine lifecycle', () {
    test('records an initialize failure and stays uninitialized', () async {
      final sink = _RecordingSink();
      final engine = Engine(
        _ScriptedGame(failInitialize: true),
        _NoAssets(),
        logSink: sink,
      );

      await engine.initialize();

      expect(engine.isInitialized, isFalse);
      expect(engine.renderError?.phase, 'initialize');
      expect(sink.reports.single.severity, DiagnosticSeverity.error);
    });

    test('initializes the game only once', () async {
      final game = _ScriptedGame();
      final engine = Engine(game, _NoAssets(), logSink: _RecordingSink());

      await engine.initialize();
      await engine.initialize();

      expect(game.initializeCalls, 1);
      expect(engine.isInitialized, isTrue);
    });

    test('ignores updates before initialization', () {
      final game = _ScriptedGame();
      Engine(game, _NoAssets(), logSink: _RecordingSink()).update(0.5);

      expect(game.updates, isEmpty);
    });

    test('step runs one update and one render', () async {
      final game = _ScriptedGame();
      final engine = Engine(game, _NoAssets(), logSink: _RecordingSink());
      await engine.initialize();

      engine.step(0.25);

      expect(game.updates, [0.25]);
      expect(game.renderCalls, 1);
      expect(engine.renderError, isNull);
    });

    test('renderFrame returns false and records a render failure', () async {
      final sink = _RecordingSink();
      final game = _ScriptedGame()..failRender = true;
      final engine = Engine(game, _NoAssets(), logSink: sink);
      await engine.initialize();

      expect(engine.renderFrame(), isFalse);
      expect(engine.renderError?.phase, 'render');
      expect(sink.reports.single.phase, 'render');
    });

    test('a successful render clears the previous failure', () async {
      final game = _ScriptedGame()..failRender = true;
      final engine = Engine(game, _NoAssets(), logSink: _RecordingSink());
      await engine.initialize();
      engine.renderFrame();

      game.failRender = false;

      expect(engine.renderFrame(), isTrue);
      expect(engine.renderError, isNull);
    });

    test(
      'records update and render durations from the injected clock',
      () async {
        final readings = [0, 5, 10, 17];
        final engine = Engine(
          _ScriptedGame(),
          _NoAssets(),
          logSink: _RecordingSink(),
          clock: () => readings.removeAt(0),
        );
        await engine.initialize();

        engine.step(0.25);

        expect(engine.lastUpdateMicros, 5);
        expect(engine.lastRenderMicros, 7);
      },
    );

    test('dispose stops updates and renders', () async {
      final game = _ScriptedGame();
      final engine = Engine(game, _NoAssets(), logSink: _RecordingSink());
      await engine.initialize();

      engine
        ..dispose()
        ..update(1);

      expect(engine.renderFrame(), isFalse);
      expect(game.updates, isEmpty);
      expect(game.renderCalls, 0);
    });
  });
}
