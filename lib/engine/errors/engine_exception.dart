sealed class EngineException implements Exception {
  const EngineException(this.message);

  final String message;

  String get kind;

  @override
  String toString() => '$kind: $message';
}

final class MeshFormatException extends EngineException {
  const MeshFormatException(super.message, {this.line, this.token});

  final int? line;

  final String? token;

  @override
  String get kind => 'MeshFormatException';
}

final class InvalidMeshException extends EngineException {
  const InvalidMeshException(super.message, {required this.issue});

  final MeshIssue issue;

  @override
  String get kind => 'InvalidMeshException';
}

enum MeshIssue {
  noVertices,
  incompleteTriangles,
  indexOutOfRange,
  nonFiniteVertex,
  zeroVolume,
  noRenderableTriangles,
}

final class ProjectionException extends EngineException {
  const ProjectionException(super.message, {this.vertexIndex});

  final int? vertexIndex;

  @override
  String get kind => 'ProjectionException';
}
