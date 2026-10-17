import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:software_engine/testing/file_asset_loader.dart';
import 'package:software_engine/testing/framebuffer_hash.dart';

const benchmarkAssets = FileAssetLoader('../../assets');

abstract interface class BenchmarkTarget {
  void iterate();

  Uint8List pixels();
}

final class BenchmarkCase {
  const BenchmarkCase({
    required this.name,
    required this.scene,
    required this.width,
    required this.height,
    required this.create,
  });

  final String name;

  final String scene;

  final int width;

  final int height;

  final Future<BenchmarkTarget> Function() create;
}

final class BenchmarkResult {
  const BenchmarkResult({
    required this.name,
    required this.scene,
    required this.width,
    required this.height,
    required this.iterations,
    required this.medianUs,
    required this.p95Us,
    required this.minUs,
    required this.framebufferHash,
  });

  final String name;

  final String scene;

  final int width;

  final int height;

  final int iterations;

  final int medianUs;

  final int p95Us;

  final int minUs;

  final int framebufferHash;

  Map<String, Object> toJson() => {
    'name': name,
    'scene': scene,
    'width': width,
    'height': height,
    'iterations': iterations,
    'medianUs': medianUs,
    'p95Us': p95Us,
    'minUs': minUs,
    'framebufferHash': _hex(framebufferHash),
    'dartVersion': Platform.version,
    'os': Platform.operatingSystem,
  };
}

Future<BenchmarkResult> runBenchmark(
  BenchmarkCase benchmarkCase, {
  int warmupIterations = 20,
  int iterations = 200,
}) async {
  final target = await benchmarkCase.create();
  for (var index = 0; index < warmupIterations; index++) {
    target.iterate();
  }

  final samples = List<int>.filled(iterations, 0);
  final stopwatch = Stopwatch();
  for (var index = 0; index < iterations; index++) {
    stopwatch
      ..reset()
      ..start();
    target.iterate();
    stopwatch.stop();
    samples[index] = stopwatch.elapsedMicroseconds;
  }
  samples.sort();

  final fresh = await benchmarkCase.create();
  fresh.iterate();
  final hash = fnv1a32(fresh.pixels());

  return BenchmarkResult(
    name: benchmarkCase.name,
    scene: benchmarkCase.scene,
    width: benchmarkCase.width,
    height: benchmarkCase.height,
    iterations: iterations,
    medianUs: samples[iterations ~/ 2],
    p95Us: samples[(iterations * 95 + 99) ~/ 100 - 1],
    minUs: samples.first,
    framebufferHash: hash,
  );
}

String formatBenchmarkTable(List<BenchmarkResult> results) {
  final buffer = StringBuffer()
    ..writeln(
      '${'name'.padRight(26)}${'scene'.padRight(14)}'
      '${'median us'.padLeft(10)}${'p95 us'.padLeft(10)}'
      '${'min us'.padLeft(10)}  hash',
    );
  for (final result in results) {
    buffer.writeln(
      '${result.name.padRight(26)}${result.scene.padRight(14)}'
      '${result.medianUs.toString().padLeft(10)}'
      '${result.p95Us.toString().padLeft(10)}'
      '${result.minUs.toString().padLeft(10)}  '
      '${_hex(result.framebufferHash)}',
    );
  }
  return buffer.toString();
}

String encodeBenchmarkDocument({
  required String machine,
  required List<BenchmarkResult> results,
}) {
  final document = {
    'machine': machine,
    'results': [for (final result in results) result.toJson()],
  };
  return const JsonEncoder.withIndent('  ').convert(document);
}

String _hex(int value) => '0x${value.toRadixString(16).padLeft(8, '0')}';
