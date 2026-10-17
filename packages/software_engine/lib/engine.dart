import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/diagnostics/logger_diagnostic_sink.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine/graphics/buffers/software_framebuffer.dart';
import 'package:software_engine/graphics/color32.dart';
import 'package:software_engine/graphics/renderer.dart';

final _systemStopwatch = Stopwatch()..start();

int _elapsedMicros() => _systemStopwatch.elapsedMicroseconds;

class Engine {
  Engine(
    Game game,
    AssetLoader assets, {
    DiagnosticSink? logSink,
    int Function()? clock,
  }) : this._(
         game,
         assets,
         FrameDiagnostics(logSink ?? LoggerDiagnosticSink()),
         clock ?? _elapsedMicros,
       );

  Engine._(
    this.game,
    this._assets,
    FrameDiagnostics frameDiagnostics,
    this._clock,
  ) : _frameDiagnostics = frameDiagnostics,
      renderer = Renderer(
        SoftwareFramebuffer(
          width: game.width,
          height: game.height,
          clearColor: game.clearColor,
        ),
        diagnostics: frameDiagnostics,
      );

  final Game game;
  final AssetLoader _assets;
  final Renderer renderer;
  final FrameDiagnostics _frameDiagnostics;
  final int Function() _clock;
  int _lastUpdateMicros = 0;
  int _lastRenderMicros = 0;
  SoftwareFramebuffer get framebuffer => renderer.framebuffer;

  bool _initializationInProgress = false;
  bool _initialized = false;
  bool _disposed = false;
  EngineDiagnostic? renderError;

  Color32 get clearColor => game.clearColor;

  bool get isInitialized => _initialized;

  int get lastUpdateMicros => _lastUpdateMicros;

  int get lastRenderMicros => _lastRenderMicros;

  List<EngineDiagnostic> get warnings => _frameDiagnostics.warnings;

  Future<void> initialize() async {
    if (_disposed || _initialized || _initializationInProgress) {
      return;
    }
    _initializationInProgress = true;
    try {
      await game.initialize(_assets);
      if (_disposed) {
        return;
      }
      _initialized = true;
    } catch (error, stackTrace) {
      if (!_disposed) {
        recordFailure('initialize', error, stackTrace);
      }
    } finally {
      _initializationInProgress = false;
    }
  }

  void update(double deltaTime) {
    if (!_initialized || _disposed) {
      return;
    }
    final start = _clock();
    game.update(deltaTime);
    _lastUpdateMicros = _clock() - start;
  }

  bool renderFrame() {
    if (_disposed) {
      return false;
    }
    _frameDiagnostics.clear();
    final start = _clock();
    try {
      renderer.beginFrame();
      game.render(renderer);
    } catch (error, stackTrace) {
      recordFailure('render', error, stackTrace);
      return false;
    } finally {
      _lastRenderMicros = _clock() - start;
    }
    renderError = null;
    return true;
  }

  void step(double deltaTime) {
    update(deltaTime);
    renderFrame();
  }

  void recordFailure(String phase, Object error, StackTrace stackTrace) {
    final diagnostic = EngineDiagnostic(
      severity: DiagnosticSeverity.error,
      phase: phase,
      message: error.toString(),
      error: error,
      stackTrace: stackTrace,
    );
    renderError = diagnostic;
    _frameDiagnostics.report(diagnostic);
  }

  void dispose() {
    _disposed = true;
  }
}
