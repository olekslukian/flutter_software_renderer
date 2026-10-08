import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/software_framebuffer.dart';

class Engine extends ChangeNotifier {
  Engine(this.game, {int width = 320, int height = 240})
    : framebuffer = SoftwareFramebuffer(width: width, height: height);

  final Game game;
  final SoftwareFramebuffer framebuffer;

  ui.Image? _image;
  bool _conversionInProgress = false;
  bool _frameRequested = false;
  bool _disposed = false;
  Object? renderError;

  ui.Image? get image => _image;

  void initialize() {
    game.initialize();
    _requestFrame();
  }

  void update(double deltaTime) {
    game.update(deltaTime);
    _requestFrame();
  }

  Color get backgroundColor => game.backgroundColor;

  void _requestFrame() {
    if (_disposed) return;
    if (_conversionInProgress) {
      // Drop intermediate frames; after decoding finishes, render the newest
      // game state once rather than starting several expensive decoders.
      _frameRequested = true;
      return;
    }

    framebuffer.clear();
    game.render(framebuffer);
    final Uint8List pixels = framebuffer.snapshot();
    _conversionInProgress = true;
    renderError = null;
    _convertToImage(pixels);
  }

  Future<void> _convertToImage(Uint8List pixels) async {
    ui.Image? decodedImage;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(
        pixels,
      );
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: framebuffer.width,
        height: framebuffer.height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      codec = await descriptor.instantiateCodec();
      decodedImage = (await codec.getNextFrame()).image;

      if (_disposed) {
        decodedImage.dispose();
      } else {
        _image?.dispose();
        _image = decodedImage;
        decodedImage = null;
        notifyListeners();
      }
    } catch (error) {
      // Keep the failure inspectable by the screen instead of hiding it.
      if (!_disposed) {
        renderError = error;
        notifyListeners();
      }
    } finally {
      decodedImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      _conversionInProgress = false;
      if (!_disposed && _frameRequested) {
        _frameRequested = false;
        _requestFrame();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
