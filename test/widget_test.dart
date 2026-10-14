import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/app/game/model_view_demo/model_view_demo.dart';
import 'package:flutter_software_renderer/engine/engine_screen.dart';
import 'package:flutter_software_renderer/engine/graphics/mesh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

void main() {
  testWidgets(
    'EngineScreen presents the software-rendered image as time advances',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EngineScreen(
            game: ModelViewDemo(
              mesh: Mesh(
                vertices: [
                  v64.Vector3(-1, -1, 0),
                  v64.Vector3(1, -1, 0),
                  v64.Vector3(0, 1, 0),
                ],
                indices: [0, 1, 2],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EngineScreen), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final rawImage = tester.widget<RawImage>(find.byType(RawImage));
      expect(rawImage.image, isNotNull);

      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
