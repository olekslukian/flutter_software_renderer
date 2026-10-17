import 'dart:io';

import 'package:software_engine/testing/benchmark.dart';
import 'package:software_engine/testing/frame_benchmarks.dart';

Future<void> main() async {
  final results = [
    for (final benchmarkCase in frameBenchmarkCases(benchmarkAssets))
      await runBenchmark(benchmarkCase),
  ];
  stdout.write(formatBenchmarkTable(results));
}
