import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/features/cube_demo/presentation/cube_demo_screen.dart';

void main() {
  testWidgets(
    'Software3DEngineScreen pumps and advances ticks without errors',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Software3DEngineScreen()),
      );

      expect(find.byType(Software3DEngineScreen), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    },
  );
}
