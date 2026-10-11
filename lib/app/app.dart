import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/app/game/cube_demo/cube_demo.dart';
import 'package:flutter_software_renderer/engine/engine_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EngineScreen(game: CubeDemo(width: 160, height: 120)),
    );
  }
}
