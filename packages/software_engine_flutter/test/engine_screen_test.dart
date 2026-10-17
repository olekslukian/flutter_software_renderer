import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software_engine/testing/reference_scenes.dart';
import 'package:software_engine_flutter/engine_screen.dart';

void main() {
  testWidgets(
    'EngineScreen presents the software-rendered image as time advances',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EngineScreen(game: TriangleScene())),
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
