import 'package:flutter/material.dart';

import '../features/cube_demo/presentation/cube_demo_screen.dart';

class RendererApp extends StatelessWidget {
  const RendererApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Software3DEngineScreen(),
    );
  }
}
