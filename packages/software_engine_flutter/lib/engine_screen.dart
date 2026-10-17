import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:software_engine/diagnostics/engine_diagnostic.dart';
import 'package:software_engine/engine.dart';
import 'package:software_engine/game.dart';
import 'package:software_engine_flutter/color32_flutter.dart';
import 'package:software_engine_flutter/engine_presenter.dart';
import 'package:software_engine_flutter/flutter_asset_loader.dart';

class EngineScreen extends StatefulWidget {
  const EngineScreen({required this.game, super.key});

  final Game game;

  @override
  State<EngineScreen> createState() => _EngineScreenState();
}

class _EngineScreenState extends State<EngineScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final EnginePresenter _presenter;
  double _lastFrameTime = 0;
  bool _warningsExpanded = false;

  @override
  void initState() {
    super.initState();
    _presenter = EnginePresenter(
      Engine(widget.game, const FlutterAssetLoader()),
    );
    unawaited(_presenter.initialize());
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final currentTime = elapsed.inMicroseconds / 1000000.0;
    final deltaTime = _lastFrameTime == 0.0
        ? 0.0
        : currentTime - _lastFrameTime;
    _lastFrameTime = currentTime;
    _presenter.tick(deltaTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _presenter.engine.clearColor.toFlutterColor(),
      body: AnimatedBuilder(
        animation: _presenter,
        builder: (context, child) {
          final error = _presenter.engine.renderError;
          if (error != null) {
            return Center(
              child: Text(
                'Render failed during ${error.phase}: ${error.message}',
              ),
            );
          }

          final warnings = _presenter.engine.warnings;
          final timings = _presenter.timings;
          return Stack(
            children: [
              SizedBox.expand(
                child: RawImage(
                  image: _presenter.image,
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
              if (!kReleaseMode && timings != null)
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _TimingsLabel(timings: timings),
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
    _presenter.dispose();
    super.dispose();
  }
}

class _TimingsLabel extends StatelessWidget {
  const _TimingsLabel({required this.timings});

  final FrameTimings timings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          'update ${_ms(timings.updateMicros)}  '
          'render ${_ms(timings.renderMicros)}  '
          'present ${_ms(timings.presentMicros)}',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
    );
  }

  static String _ms(int micros) => '${(micros / 1000).toStringAsFixed(2)} ms';
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
