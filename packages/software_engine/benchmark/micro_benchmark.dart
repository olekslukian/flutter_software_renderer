import 'dart:io';

import 'package:software_engine/testing/benchmark.dart';
import 'package:software_engine/testing/micro_benchmarks.dart';

Future<void> main() async {
  final results = [
    for (final benchmarkCase in await microBenchmarkCases(benchmarkAssets))
      await runBenchmark(benchmarkCase),
  ];
  stdout.write(formatBenchmarkTable(results));
}
