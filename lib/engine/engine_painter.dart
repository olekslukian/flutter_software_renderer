import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/engine/engine.dart';

class EnginePainter extends CustomPainter {
  EnginePainter({required this.renderer}) : super(repaint: renderer);

  final Engine renderer;

  @override
  void paint(Canvas canvas, Size size) {
    renderer.render(canvas, size);
  }

  @override
  bool shouldRepaint(covariant EnginePainter oldDelegate) {
    return oldDelegate.renderer != renderer;
  }
}
