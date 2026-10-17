import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/game/model_view_demo/model_view_demo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:software_engine_flutter/engine_screen.dart';

void main() {
  testWidgets('app renders the real model-view demo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EngineScreen(game: ModelViewDemo())),
    );

    RawImage rawImage() => tester.widget<RawImage>(find.byType(RawImage));
    expect(rawImage(), isNotNull);

    for (
      var attempt = 0;
      attempt < 200 && rawImage().image == null;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
