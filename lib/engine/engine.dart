import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_software_renderer/engine/game.dart';
import 'package:flutter_software_renderer/engine/graphics/buffers/software_framebuffer.dart';
import 'package:flutter_software_renderer/engine/graphics/renderer.dart';

class Engine extends ChangeNotifier {
  /// Creates an engine for [game] and allocates a framebuffer matching the
  /// dimensions and clear color declared by that game.
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

  /// The clear color configured by the current [game].
  Color get clearColor => game.clearColor;

  /// The most recently decoded frame, or `null` until a frame is available.
  ui.Image? get image => _image;

  /// Awaits game initialization before requesting its first rendered frame.
  ///
  /// Initialization failures are published through [renderError] so the host
  /// can display them alongside render failures.
  Future<void> initialize() async {
    if (_disposed || _initialized || _initializationInProgress) return;
    _initializationInProgress = true;
    try {
      // Asset-backed games must finish loading before the first frame is drawn.
      await game.initialize();
      if (_disposed) return;
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

  /// Advances the game by [deltaTime] seconds and requests a frame containing
  /// the resulting game state.
  void update(double deltaTime) {
    if (!_initialized || _disposed) return;
    game.update(deltaTime);
    _requestFrame();
  }

  /// Renders the current game state into the framebuffer and starts converting
  /// its copied RGBA pixels into a Flutter image. While a conversion is active,
  /// coalesces additional requests so that only the latest state is rendered
  /// when that conversion finishes.
  void _requestFrame() {
    if (_disposed) return;
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
    final Uint8List pixels = framebuffer.snapshot();
    _conversionInProgress = true;
    renderError = null;
    _convertToImage(pixels);
  }

  /// Converts a copied RGBA [pixels] buffer into a [ui.Image], releasing every
  /// temporary decoder resource when complete. Publishes successful images and
  /// decoding errors unless the engine has already been disposed; if a frame
  /// was requested during conversion, renders the latest game state afterward.
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

  /// Marks the engine as unusable and releases its owned image before allowing
  /// [ChangeNotifier] to complete disposal. Any conversion already in flight
  /// will dispose its result rather than publishing it.
  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
