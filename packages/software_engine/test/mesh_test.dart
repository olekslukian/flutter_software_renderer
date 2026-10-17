import 'dart:math' as math;

import 'package:software_engine/errors/engine_exception.dart';
import 'package:software_engine/graphics/mesh.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  test('triangulates OBJ polygon faces with positive and relative indices', () {
    final mesh = Mesh.fromObj('''
v -1 0 0
v 0 1 0
v 1 0 0
v 0 -1 0
f 1/1/1 2/2/2 3/3/3 4/4/4
f -4 -3 -2
''');

    expect(mesh.vertices, hasLength(4));
    expect(mesh.indices, [0, 1, 2, 0, 2, 3, 0, 1, 2]);
  });

  test('rejects a face index outside the declared vertex range', () {
    expect(
      () => Mesh.fromObj('''
v 0 0 0
v 1 0 0
v 0 1 0
f 1 2 4
'''),
      throwsA(isA<MeshFormatException>()),
    );
  });

  test('normalized centers the mesh and scales its largest extent to 2', () {
    final mesh = Mesh(
      vertices: [
        v64.Vector3(10, 0, 0),
        v64.Vector3(14, 0, 0),
        v64.Vector3(10, 2, 0),
      ],
      indices: const [0, 1, 2],
    ).normalized();

    final minX = mesh.vertices.map((v) => v.x).reduce(math.min);
    final maxX = mesh.vertices.map((v) => v.x).reduce(math.max);
    final minY = mesh.vertices.map((v) => v.y).reduce(math.min);
    final maxY = mesh.vertices.map((v) => v.y).reduce(math.max);

    expect(maxX - minX, closeTo(2.0, 1e-9));
    expect(minX + maxX, closeTo(0.0, 1e-9));
    expect(minY + maxY, closeTo(0.0, 1e-9));
    expect(mesh.indices, [0, 1, 2]);
  });

  test('rejects meshes that are empty, partial, or degenerate', () {
    final triangle = [
      v64.Vector3.zero(),
      v64.Vector3(1, 0, 0),
      v64.Vector3(0, 1, 0),
    ];

    expect(
      () => Mesh(vertices: const [], indices: const []),
      throwsA(_invalidMesh(MeshIssue.noVertices)),
    );
    expect(
      () => Mesh(vertices: triangle, indices: const [0, 1]),
      throwsA(_invalidMesh(MeshIssue.incompleteTriangles)),
    );
    expect(
      () => Mesh(vertices: triangle, indices: const [0, 1, 3]),
      throwsA(_invalidMesh(MeshIssue.indexOutOfRange)),
    );
    expect(
      () => Mesh(
        vertices: [
          v64.Vector3.zero(),
          v64.Vector3(double.nan, 0, 0),
          v64.Vector3(0, 1, 0),
        ],
        indices: const [0, 1, 2],
      ),
      throwsA(_invalidMesh(MeshIssue.nonFiniteVertex)),
    );
    expect(
      () => Mesh(
        vertices: [
          v64.Vector3(1, 1, 1),
          v64.Vector3(1, 1, 1),
          v64.Vector3(1, 1, 1),
        ],
        indices: const [0, 1, 2],
      ).normalized(),
      throwsA(_invalidMesh(MeshIssue.zeroVolume)),
    );
  });

  test('ArgumentError is reserved for invalid caller arguments', () {
    expect(
      () => Mesh(
        vertices: [
          v64.Vector3.zero(),
          v64.Vector3(1, 0, 0),
          v64.Vector3(0, 1, 0),
        ],
        indices: const [0, 1, 2],
      ).normalized(targetExtent: -1),
      throwsArgumentError,
    );
  });
}

Matcher _invalidMesh(MeshIssue issue) => isA<InvalidMeshException>().having(
  (exception) => exception.issue,
  'issue',
  issue,
);
