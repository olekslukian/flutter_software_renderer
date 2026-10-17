import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/game/model_view_demo/model_view_demo.dart';
import 'package:software_engine_flutter/engine_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EngineScreen(game: ModelViewDemo()),
    ),
  );
}
