import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/app/game/model_view_demo/model_view_demo.dart';
import 'package:flutter_software_renderer/engine/engine_screen.dart';

void main() {
  testWidgets(
    'EngineScreen presents the software-rendered image as time advances',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EngineScreen(game: ModelViewDemo())),
      );

      expect(find.byType(EngineScreen), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);

      // Image decoding uses the real async codec, so let it finish outside the
      // widget-test clock before rebuilding with the decoded image.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      final RawImage rawImage = tester.widget(find.byType(RawImage));
      expect(rawImage.image, isNotNull);

      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
