import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../rendering/cube_renderer.dart';

/// Owns the demo's vsync-driven update loop and presents its rendered canvas.
class Software3DEngineScreen extends StatefulWidget {
  const Software3DEngineScreen({super.key});

  @override
  State<Software3DEngineScreen> createState() => _Software3DEngineScreenState();
}

class _Software3DEngineScreenState extends State<Software3DEngineScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final CubeRenderer _renderer = CubeRenderer();
  double _lastFrameTime = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final double currentTime = elapsed.inMicroseconds / 1000000.0;
    final double deltaTime =
        _lastFrameTime == 0.0 ? 0.0 : currentTime - _lastFrameTime;
    _lastFrameTime = currentTime;
    _renderer.update(deltaTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D15),
      body: Center(
        child: CustomPaint(
          size: Size.infinite,
          painter: Software3DPainter(renderer: _renderer),
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
