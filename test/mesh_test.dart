import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';

void main() {
  test('triangulates OBJ polygon faces with positive and relative indices', () {
    final Mesh mesh = Mesh.fromObj('''
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
      throwsFormatException,
    );
  });
}
