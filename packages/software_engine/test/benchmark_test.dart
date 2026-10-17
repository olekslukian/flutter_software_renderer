import 'dart:convert';
import 'dart:typed_data';

import 'package:software_engine/testing/benchmark.dart';
import 'package:software_engine/testing/framebuffer_hash.dart';
import 'package:test/test.dart';

final class _CountingTarget implements BenchmarkTarget {
  int iterations = 0;

  @override
  void iterate() {
    iterations++;
  }

  @override
  Uint8List pixels() => Uint8List.fromList([1, 2, 3]);
}

void main() {
  group('runBenchmark', () {
    test(
      'runs warmup, timed iterations, and a fresh verification run',
      () async {
        final targets = <_CountingTarget>[];
        final benchmarkCase = BenchmarkCase(
          name: 'counting',
          scene: 'synthetic',
          width: 1,
          height: 1,
          create: () async {
            final target = _CountingTarget();
            targets.add(target);
            return target;
          },
        );

        final result = await runBenchmark(
          benchmarkCase,
          warmupIterations: 2,
          iterations: 5,
        );

        expect(result.iterations, 5);
        expect(targets, hasLength(2));
        expect(targets.first.iterations, 7);
        expect(targets.last.iterations, 1);
        expect(result.minUs, lessThanOrEqualTo(result.medianUs));
        expect(result.medianUs, lessThanOrEqualTo(result.p95Us));
      },
    );

    test('hashes the pixels of one iteration on a fresh target', () async {
      final benchmarkCase = BenchmarkCase(
        name: 'hash',
        scene: 'synthetic',
        width: 1,
        height: 1,
        create: () async => _CountingTarget(),
      );

      final result = await runBenchmark(
        benchmarkCase,
        warmupIterations: 0,
        iterations: 1,
      );

      expect(result.framebufferHash, fnv1a32(Uint8List.fromList([1, 2, 3])));
    });

    test('encodes the JSON document with the documented fields', () async {
      const result = BenchmarkResult(
        name: 'clear',
        scene: 'synthetic',
        width: 320,
        height: 240,
        iterations: 10,
        medianUs: 5,
        p95Us: 7,
        minUs: 4,
        framebufferHash: 0x8ab934b5,
      );

      final document =
          jsonDecode(
                encodeBenchmarkDocument(
                  machine: 'test-machine',
                  results: [result],
                ),
              )
              as Map<String, Object?>;
      final entry =
          (document['results']! as List<Object?>).single!
              as Map<String, Object?>;

      expect(document['machine'], 'test-machine');
      expect(entry['framebufferHash'], '0x8ab934b5');
      expect(entry['medianUs'], 5);
      expect(entry['p95Us'], 7);
      expect(entry['minUs'], 4);
      expect(entry, containsPair('dartVersion', isA<String>()));
      expect(entry, containsPair('os', isA<String>()));
    });
  });
}
