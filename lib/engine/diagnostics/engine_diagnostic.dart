enum DiagnosticSeverity { warning, error }

final class EngineDiagnostic {
  const EngineDiagnostic({
    required this.severity,
    required this.phase,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DiagnosticSeverity severity;

  final String phase;

  final String message;

  final Object? error;

  final StackTrace? stackTrace;
}

abstract interface class DiagnosticSink {
  void report(EngineDiagnostic diagnostic);
}

final class NullDiagnosticSink implements DiagnosticSink {
  const NullDiagnosticSink();

  @override
  void report(EngineDiagnostic diagnostic) {}
}

final class FrameDiagnostics implements DiagnosticSink {
  FrameDiagnostics(this._forward);

  static const _maxWarningsPerFrame = 20;

  final DiagnosticSink _forward;

  final List<EngineDiagnostic> _warnings = [];

  List<EngineDiagnostic> get warnings => List.unmodifiable(_warnings);

  void clear() => _warnings.clear();

  @override
  void report(EngineDiagnostic diagnostic) {
    _forward.report(diagnostic);
    if (diagnostic.severity == DiagnosticSeverity.warning &&
        _warnings.length < _maxWarningsPerFrame) {
      _warnings.add(diagnostic);
    }
  }
}
