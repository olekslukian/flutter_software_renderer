import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_software_renderer/engine/diagnostics/engine_diagnostic.dart';
import 'package:flutter_software_renderer/engine/engine.dart';
import 'package:flutter_software_renderer/engine/game.dart';

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
  double _lastFrameTime = 0;
  bool _warningsExpanded = false;

  @override
  void initState() {
    super.initState();
    _engine = Engine(widget.game);
    unawaited(_engine.initialize());
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final currentTime = elapsed.inMicroseconds / 1000000.0;
    final deltaTime = _lastFrameTime == 0.0
        ? 0.0
        : currentTime - _lastFrameTime;
    _lastFrameTime = currentTime;
    _engine.update(deltaTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _engine.clearColor,
      body: AnimatedBuilder(
        animation: _engine,
        builder: (context, child) {
          final error = _engine.renderError;
          if (error != null) {
            return Center(
              child: Text(
                'Render failed during ${error.phase}: ${error.message}',
              ),
            );
          }

          final warnings = _engine.warnings;
          return Stack(
            children: [
              SizedBox.expand(
                child: RawImage(
                  image: _engine.image,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                ),
              ),
              if (kDebugMode && warnings.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _WarningsBanner(
                    warnings: warnings,
                    expanded: _warningsExpanded,
                    onTap: () =>
                        setState(() => _warningsExpanded = !_warningsExpanded),
                  ),
                ),
            ],
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

class _WarningsBanner extends StatelessWidget {
  const _WarningsBanner({
    required this.warnings,
    required this.expanded,
    required this.onTap,
  });

  final List<EngineDiagnostic> warnings;

  final bool expanded;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visible = expanded ? warnings : warnings.take(1);
    return Material(
      color: Colors.amber.shade100,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${warnings.length} warning${warnings.length == 1 ? '' : 's'}'
                ' (tap to ${expanded ? 'hide' : 'show'})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              for (final warning in visible)
                Text(warning.message, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
