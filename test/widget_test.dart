import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/app/game/cube_demo/cube_demo.dart';
import 'package:flutter_software_renderer/engine/engine_screen.dart';

void main() {
  testWidgets(
    'Software3DEngineScreen pumps and advances ticks without errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EngineScreen(game: CubeDemo())),
      );

      expect(find.byType(EngineScreen), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
