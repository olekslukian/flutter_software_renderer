import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';

class Engine extends ChangeNotifier {
  Engine(this.game)
    : renderer = Renderer(
        SoftwareFramebuffer(
          width: game.width,
          height: game.height,
          clearColor: game.clearColor,
        ),
      );

  final Game game;
  final Renderer renderer;
  SoftwareFramebuffer get framebuffer => renderer.framebuffer;

  ui.Image? _image;
  bool _conversionInProgress = false;
  bool _frameRequested = false;
  bool _initializationInProgress = false;
  bool _initialized = false;
  bool _disposed = false;
  Object? renderError;

  Color get clearColor => game.clearColor;

  ui.Image? get image => _image;

  Future<void> initialize() async {
    if (_disposed || _initialized || _initializationInProgress) {
      return;
    }
    _initializationInProgress = true;
    try {
      await game.initialize();
      if (_disposed) {
        return;
      }
      _initialized = true;
      _requestFrame();
    } catch (error) {
      if (!_disposed) {
        renderError = error;
        notifyListeners();
      }
    } finally {
      _initializationInProgress = false;
    }
  }

  void update(double deltaTime) {
    if (!_initialized || _disposed) {
      return;
    }
    game.update(deltaTime);
    _requestFrame();
  }

  void _requestFrame() {
    if (_disposed) {
      return;
    }
    if (_conversionInProgress) {
      _frameRequested = true;
      return;
    }

    try {
      renderer.beginFrame();
      game.render(renderer);
    } catch (error) {
      renderError = error;
      notifyListeners();
      return;
    }
    final pixels = framebuffer.snapshot();
    _conversionInProgress = true;
    renderError = null;
    unawaited(_convertToImage(pixels));
  }

  Future<void> _convertToImage(Uint8List pixels) async {
    ui.Image? decodedImage;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
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
