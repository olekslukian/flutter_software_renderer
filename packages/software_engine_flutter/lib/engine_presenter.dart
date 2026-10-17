import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:software_engine/engine.dart';

final _presenterStopwatch = Stopwatch()..start();

int _presenterElapsedMicros() => _presenterStopwatch.elapsedMicroseconds;

final class FrameTimings {
  const FrameTimings({
    required this.updateMicros,
    required this.renderMicros,
    required this.presentMicros,
  });

  final int updateMicros;

  final int renderMicros;

  final int presentMicros;
}

class EnginePresenter extends ChangeNotifier {
  EnginePresenter(this.engine, {int Function()? clock})
    : _clock = clock ?? _presenterElapsedMicros;

  final Engine engine;

  final int Function() _clock;

  ui.Image? _image;
  FrameTimings? _timings;
  bool _conversionInProgress = false;
  bool _frameRequested = false;
  bool _disposed = false;

  ui.Image? get image => _image;

  FrameTimings? get timings => _timings;

  Future<void> initialize() async {
    await engine.initialize();
    if (_disposed) {
      return;
    }
    if (engine.isInitialized) {
      _requestFrame();
    } else {
      notifyListeners();
    }
  }

  void tick(double deltaTime) {
    if (_disposed || !engine.isInitialized) {
      return;
    }
    engine.update(deltaTime);
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

    if (!engine.renderFrame()) {
      notifyListeners();
      return;
    }
    final presentStart = _clock();
    final pixels = engine.framebuffer.snapshot();
    _conversionInProgress = true;
    unawaited(_convertToImage(pixels, presentStart));
  }

  Future<void> _convertToImage(Uint8List pixels, int presentStart) async {
    ui.Image? decodedImage;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: engine.framebuffer.width,
        height: engine.framebuffer.height,
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
        _timings = FrameTimings(
          updateMicros: engine.lastUpdateMicros,
          renderMicros: engine.lastRenderMicros,
          presentMicros: _clock() - presentStart,
        );
        notifyListeners();
      }
    } catch (error, stackTrace) {
      if (!_disposed) {
        engine.recordFailure('convert', error, stackTrace);
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
    engine.dispose();
    super.dispose();
  }
}
