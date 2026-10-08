import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_software_renderer/engine/engine_painter.dart';
import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/engine.dart';

class EngineScreen extends StatefulWidget {
  const EngineScreen({required this.game, super.key});

  final Game game;

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final Engine _renderer;
  double _lastFrameTime = 0.0;

  @override
  void initState() {
    super.initState();
    _renderer = Engine(widget.game);
    _renderer.initialize();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double currentTime = elapsed.inMicroseconds / 1000000.0;
    final double deltaTime = _lastFrameTime == 0.0
        ? 0.0
        : currentTime - _lastFrameTime;
    _lastFrameTime = currentTime;
    _renderer.update(deltaTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _renderer.backgroundColor,
      body: Center(
        child: CustomPaint(
          size: Size.infinite,
          painter: EnginePainter(renderer: _renderer),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _renderer.dispose();
    super.dispose();
  }
}
