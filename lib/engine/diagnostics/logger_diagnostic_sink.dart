import 'package:flutter_software_renderer/engine/diagnostics/engine_diagnostic.dart';
import 'package:logger/logger.dart';

final class LoggerDiagnosticSink implements DiagnosticSink {
  LoggerDiagnosticSink({Logger? logger, Duration? repeatInterval})
    : _logger = logger ?? Logger(printer: PrettyPrinter(methodCount: 0)),
      _repeatInterval = repeatInterval ?? const Duration(seconds: 1);

  final Logger _logger;

  final Duration _repeatInterval;

  final Map<String, DateTime> _lastLoggedAt = {};

  @override
  void report(EngineDiagnostic diagnostic) {
    final key = '${diagnostic.phase}|${diagnostic.message}';
    final now = DateTime.now();
    final lastLogged = _lastLoggedAt[key];
    if (lastLogged != null && now.difference(lastLogged) < _repeatInterval) {
      return;
    }
    _lastLoggedAt[key] = now;

    final label = '[${diagnostic.phase}] ${diagnostic.message}';
    switch (diagnostic.severity) {
      case DiagnosticSeverity.warning:
        _logger.w(label);
      case DiagnosticSeverity.error:
        _logger.e(
          label,
          error: diagnostic.error,
          stackTrace: diagnostic.stackTrace,
        );
    }
  }
}
