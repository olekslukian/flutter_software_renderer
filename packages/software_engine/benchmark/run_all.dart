import 'dart:io';

import 'package:software_engine/testing/benchmark.dart';
import 'package:software_engine/testing/frame_benchmarks.dart';
import 'package:software_engine/testing/micro_benchmarks.dart';

const _machinePrefix = '--machine=';

Future<void> main(List<String> arguments) async {
  final results = [
    for (final benchmarkCase in await microBenchmarkCases(benchmarkAssets))
      await runBenchmark(benchmarkCase),
    for (final benchmarkCase in frameBenchmarkCases(benchmarkAssets))
      await runBenchmark(benchmarkCase),
  ];
  stdout.write(formatBenchmarkTable(results));

  final document = encodeBenchmarkDocument(
    machine: _machineFrom(arguments),
    results: results,
  );
  final output = File('benchmark/results/run_all.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('$document\n');
  stdout.writeln('Wrote ${output.path}');
}

String _machineFrom(List<String> arguments) {
  for (final argument in arguments) {
    if (argument.startsWith(_machinePrefix)) {
      return argument.substring(_machinePrefix.length);
    }
  }
  return 'unspecified';
}
