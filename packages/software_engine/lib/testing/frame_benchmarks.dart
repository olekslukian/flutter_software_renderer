import 'dart:typed_data';

import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine/testing/benchmark.dart';
import 'package:software_engine/testing/reference_scenes.dart';

const _fixedStep = 1 / 60;

List<BenchmarkCase> frameBenchmarkCases(AssetLoader assets) => [
  _frameCase('rotating_cube', RotatingCubeScene.new, assets),
  _frameCase('penger', PengerScene.new, assets),
  _frameCase('overdraw', OverdrawScene.new, assets),
];

BenchmarkCase _frameCase(
  String scene,
  Game Function() createGame,
  AssetLoader assets,
) => BenchmarkCase(
  name: 'frame_$scene',
  scene: scene,
  width: 320,
  height: 240,
  create: () async {
    final engine = Engine(
      createGame(),
      assets,
      logSink: const NullDiagnosticSink(),
    );
    await engine.initialize();
    return _EngineTarget(engine);
  },
);

final class _EngineTarget implements BenchmarkTarget {
  _EngineTarget(this._engine);

  final Engine _engine;

  @override
  void iterate() {
    _engine.step(_fixedStep);
  }

  @override
  Uint8List pixels() => _engine.framebuffer.snapshot();
}
