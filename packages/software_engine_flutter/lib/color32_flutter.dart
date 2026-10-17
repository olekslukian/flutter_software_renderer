import 'dart:ui' show Color;

import 'package:software_engine/graphics/color32.dart';

extension Color32FlutterColor on Color32 {
  Color toFlutterColor() => Color(toARGB32());
}
