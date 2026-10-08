import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  late final Engine _engine;
  double _lastFrameTime = 0.0;

  @override
  void initState() {
    super.initState();
    _engine = Engine(widget.game);
    _engine.initialize();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double currentTime = elapsed.inMicroseconds / 1000000.0;
    final double deltaTime = _lastFrameTime == 0.0
        ? 0.0
        : currentTime - _lastFrameTime;
    _lastFrameTime = currentTime;
    _engine.update(deltaTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _engine.backgroundColor,
      body: AnimatedBuilder(
        animation: _engine,
        builder: (BuildContext context, Widget? child) {
          if (_engine.renderError case final Object error) {
            return Center(child: Text('Render failed: $error'));
          }

          return SizedBox.expand(
            child: RawImage(
              image: _engine.image,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _engine.dispose();
    super.dispose();
  }
}
