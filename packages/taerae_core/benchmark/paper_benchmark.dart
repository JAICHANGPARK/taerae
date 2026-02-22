import 'dart:convert';
import 'dart:io';
import 'dart:math';

void main(List<String> args) async {
  final RunnerConfig config;
  try {
    config = RunnerConfig.parse(args);
  } on FormatException catch (error) {
    stderr.writeln('Argument error: ${error.message}');
    _printUsage();
    exitCode = 64;
    return;
  }

  if (config.showHelp) {
    _printUsage();
    return;
  }

  final Directory workingDirectory = Directory.current;
  final File benchmarkScript = File(
    '${workingDirectory.path}/benchmark/graph_search_benchmark.dart',
  );
  if (!benchmarkScript.existsSync()) {
    stderr.writeln(
      'Could not find benchmark/graph_search_benchmark.dart. '
      'Run this from packages/taerae_core.',
    );
    exitCode = 66;
    return;
  }

  final DateTime startedAt = DateTime.now().toUtc();
  final String timestamp = _timestampForPath(startedAt);
  final Directory outputDir = Directory(
    config.outputDir ?? '${workingDirectory.path}/benchmark/results/$timestamp',
  );
  await outputDir.create(recursive: true);

  stdout.writeln('Taerae Paper Benchmark Runner');
  stdout.writeln(
    'presets=${config.presets.join(",")} sizes=${config.sizes.join(",")} '
    'warmupRuns=${config.warmupRuns} repeat=${config.repeat} '
    'outputDir=${outputDir.path}',
  );

  final List<MetricSample> samples = <MetricSample>[];
  int runCounter = 0;
  final int totalRuns =
      config.presets.length * (config.warmupRuns + config.repeat);

  for (final String preset in config.presets) {
    for (
      int runIndex = 0;
      runIndex < config.warmupRuns + config.repeat;
      runIndex++
    ) {
      runCounter += 1;
      final bool isWarmup = runIndex < config.warmupRuns;
      final int measuredIndex = runIndex - config.warmupRuns;
      final int seed = config.seed + runIndex;

      stdout.writeln(
        '[${runCounter.toString().padLeft(2)}/$totalRuns] '
        '${isWarmup ? "warmup" : "measure"} '
        'preset=$preset run=${isWarmup ? runIndex + 1 : measuredIndex + 1} '
        'seed=$seed',
      );

      final ProcessResult result = await Process.run(
        'dart',
        _buildChildArgs(config, preset, seed),
        workingDirectory: workingDirectory.path,
      );

      if (result.exitCode != 0) {
        stderr.writeln('Child benchmark failed for preset="$preset".');
        stderr.writeln(result.stdout);
        stderr.writeln(result.stderr);
        exitCode = result.exitCode;
        return;
      }

      final String stdoutText = result.stdout as String;
      if (config.saveRawLogs) {
        final String suffix = isWarmup
            ? 'warmup_${runIndex + 1}'
            : 'run_${measuredIndex + 1}';
        final File rawLog = File('${outputDir.path}/${preset}_$suffix.txt');
        await rawLog.writeAsString(stdoutText, flush: true);
      }

      if (isWarmup) {
        continue;
      }

      final List<ScenarioRun> scenarios = _parseScenarioRuns(stdoutText);
      for (final ScenarioRun scenario in scenarios) {
        for (final MetricRun metric in scenario.metrics) {
          samples.add(
            MetricSample(
              preset: preset,
              runIndex: measuredIndex + 1,
              nodeCount: scenario.nodeCount,
              edgeCount: scenario.edgeCount,
              metric: metric.name,
              operations: metric.operations,
              totalMilliseconds: metric.totalMilliseconds,
              microsecondsPerOperation: metric.microsecondsPerOperation,
              operationsPerSecond: metric.operationsPerSecond,
            ),
          );
        }
      }
    }
  }

  if (samples.isEmpty) {
    stderr.writeln('No benchmark samples collected.');
    exitCode = 65;
    return;
  }

  final List<MetricSummary> summary = _summarize(samples);
  summary.sort((MetricSummary a, MetricSummary b) {
    final int presetCompare = a.preset.compareTo(b.preset);
    if (presetCompare != 0) {
      return presetCompare;
    }
    final int nodeCompare = a.nodeCount.compareTo(b.nodeCount);
    if (nodeCompare != 0) {
      return nodeCompare;
    }
    return a.metric.compareTo(b.metric);
  });

  final String dartVersion = await _readDartVersion();
  final DateTime finishedAt = DateTime.now().toUtc();
  final Duration duration = finishedAt.difference(startedAt);

  final File jsonFile = File('${outputDir.path}/results.json');
  final File csvFile = File('${outputDir.path}/summary.csv');
  final File reportFile = File('${outputDir.path}/REPORT.md');

  final Map<String, Object?> jsonRoot = <String, Object?>{
    'generatedAtUtc': finishedAt.toIso8601String(),
    'durationSeconds': duration.inMilliseconds / 1000.0,
    'environment': <String, Object?>{
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'dartVersion': dartVersion,
      'processors': Platform.numberOfProcessors,
      'localeName': Platform.localeName,
    },
    'config': config.toJson(),
    'samples': samples.map((MetricSample sample) => sample.toJson()).toList(),
    'summary': summary.map((MetricSummary item) => item.toJson()).toList(),
  };

  await jsonFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(jsonRoot),
    flush: true,
  );
  await csvFile.writeAsString(_toCsv(summary), flush: true);
  await reportFile.writeAsString(
    _toMarkdownReport(
      config: config,
      summary: summary,
      startedAt: startedAt,
      finishedAt: finishedAt,
      duration: duration,
      dartVersion: dartVersion,
      jsonPath: jsonFile.path,
      csvPath: csvFile.path,
    ),
    flush: true,
  );

  stdout.writeln('');
  stdout.writeln('Saved results:');
  stdout.writeln('- ${jsonFile.path}');
  stdout.writeln('- ${csvFile.path}');
  stdout.writeln('- ${reportFile.path}');
  stdout.writeln('');
  stdout.writeln('Top-line summary (mean ops/s):');
  for (final MetricSummary item in summary.take(12)) {
    stdout.writeln(
      '${item.preset.padRight(10)} '
      'nodes=${item.nodeCount.toString().padLeft(7)} '
      '${item.metric.padRight(24)} '
      '${item.meanOperationsPerSecond.toStringAsFixed(0).padLeft(10)}',
    );
  }
}

List<String> _buildChildArgs(RunnerConfig config, String preset, int seed) {
  final List<String> args = <String>[
    'run',
    'benchmark/graph_search_benchmark.dart',
    '--preset=$preset',
    '--sizes=${config.sizes.join(",")}',
    '--seed=$seed',
  ];

  if (config.edgeFactor != null) {
    args.add('--edge-factor=${config.edgeFactor}');
  }
  if (config.labelCount != null) {
    args.add('--label-count=${config.labelCount}');
  }
  if (config.propertyCardinality != null) {
    args.add('--property-cardinality=${config.propertyCardinality}');
  }
  if (config.lookupQueries != null) {
    args.add('--lookup-queries=${config.lookupQueries}');
  }
  if (config.pathQueries != null) {
    args.add('--path-queries=${config.pathQueries}');
  }
  return args;
}

List<ScenarioRun> _parseScenarioRuns(String source) {
  final RegExp scenarioPattern = RegExp(
    r'^Scenario: nodes=(\d+), edges=(\d+)$',
  );
  final RegExp metricPattern = RegExp(
    r'^([A-Za-z0-9_()]+)\s+(\d+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)$',
  );
  final RegExp checksumPattern = RegExp(r'^checksum=');

  final List<ScenarioRun> result = <ScenarioRun>[];
  ScenarioRunBuilder? builder;

  for (final String rawLine in source.split('\n')) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final Match? scenarioMatch = scenarioPattern.firstMatch(line);
    if (scenarioMatch != null) {
      if (builder != null) {
        result.add(builder.build());
      }
      builder = ScenarioRunBuilder(
        nodeCount: int.parse(scenarioMatch.group(1)!),
        edgeCount: int.parse(scenarioMatch.group(2)!),
      );
      continue;
    }

    if (builder == null) {
      continue;
    }

    if (checksumPattern.hasMatch(line)) {
      result.add(builder.build());
      builder = null;
      continue;
    }

    final Match? metricMatch = metricPattern.firstMatch(line);
    if (metricMatch != null) {
      builder.metrics.add(
        MetricRun(
          name: metricMatch.group(1)!,
          operations: int.parse(metricMatch.group(2)!),
          totalMilliseconds: double.parse(metricMatch.group(3)!),
          microsecondsPerOperation: double.parse(metricMatch.group(4)!),
          operationsPerSecond: double.parse(metricMatch.group(5)!),
        ),
      );
    }
  }

  if (builder != null) {
    result.add(builder.build());
  }

  return result;
}

List<MetricSummary> _summarize(List<MetricSample> samples) {
  final Map<_SummaryKey, List<MetricSample>> grouped =
      <_SummaryKey, List<MetricSample>>{};
  for (final MetricSample sample in samples) {
    final _SummaryKey key = _SummaryKey(
      preset: sample.preset,
      nodeCount: sample.nodeCount,
      edgeCount: sample.edgeCount,
      metric: sample.metric,
    );
    grouped.putIfAbsent(key, () => <MetricSample>[]).add(sample);
  }

  final List<MetricSummary> summary = <MetricSummary>[];
  for (final MapEntry<_SummaryKey, List<MetricSample>> entry
      in grouped.entries) {
    final List<double> ops = entry.value
        .map((MetricSample item) => item.operationsPerSecond)
        .toList(growable: false);
    final List<double> us = entry.value
        .map((MetricSample item) => item.microsecondsPerOperation)
        .toList(growable: false);

    summary.add(
      MetricSummary(
        preset: entry.key.preset,
        nodeCount: entry.key.nodeCount,
        edgeCount: entry.key.edgeCount,
        metric: entry.key.metric,
        runs: entry.value.length,
        meanOperationsPerSecond: _mean(ops),
        p50OperationsPerSecond: _percentile(ops, 0.5),
        p95OperationsPerSecond: _percentile(ops, 0.95),
        stddevOperationsPerSecond: _stddev(ops),
        meanMicrosecondsPerOperation: _mean(us),
        p50MicrosecondsPerOperation: _percentile(us, 0.5),
        p95MicrosecondsPerOperation: _percentile(us, 0.95),
      ),
    );
  }
  return summary;
}

double _mean(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  double sum = 0;
  for (final double value in values) {
    sum += value;
  }
  return sum / values.length;
}

double _stddev(List<double> values) {
  if (values.length <= 1) {
    return 0;
  }
  final double mean = _mean(values);
  double variance = 0;
  for (final double value in values) {
    final double delta = value - mean;
    variance += delta * delta;
  }
  variance /= (values.length - 1);
  return sqrt(variance);
}

double _percentile(List<double> source, double percentile) {
  if (source.isEmpty) {
    return 0;
  }
  final List<double> values = source.toList(growable: true)..sort();
  final double p = percentile.clamp(0.0, 1.0);
  if (values.length == 1) {
    return values.first;
  }
  final double position = p * (values.length - 1);
  final int lower = position.floor();
  final int upper = position.ceil();
  if (lower == upper) {
    return values[lower];
  }
  final double weight = position - lower;
  return values[lower] + (values[upper] - values[lower]) * weight;
}

String _toCsv(List<MetricSummary> summary) {
  final StringBuffer buffer = StringBuffer()
    ..writeln(
      'preset,nodes,edges,metric,runs,'
      'mean_ops_s,p50_ops_s,p95_ops_s,stddev_ops_s,'
      'mean_us_op,p50_us_op,p95_us_op',
    );

  for (final MetricSummary item in summary) {
    buffer.writeln(
      '${item.preset},${item.nodeCount},${item.edgeCount},${item.metric},'
      '${item.runs},'
      '${item.meanOperationsPerSecond.toStringAsFixed(3)},'
      '${item.p50OperationsPerSecond.toStringAsFixed(3)},'
      '${item.p95OperationsPerSecond.toStringAsFixed(3)},'
      '${item.stddevOperationsPerSecond.toStringAsFixed(3)},'
      '${item.meanMicrosecondsPerOperation.toStringAsFixed(6)},'
      '${item.p50MicrosecondsPerOperation.toStringAsFixed(6)},'
      '${item.p95MicrosecondsPerOperation.toStringAsFixed(6)}',
    );
  }
  return buffer.toString();
}

String _toMarkdownReport({
  required RunnerConfig config,
  required List<MetricSummary> summary,
  required DateTime startedAt,
  required DateTime finishedAt,
  required Duration duration,
  required String dartVersion,
  required String jsonPath,
  required String csvPath,
}) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('# Taerae Paper Benchmark Report')
    ..writeln('')
    ..writeln('## Run Metadata')
    ..writeln('')
    ..writeln('- Started (UTC): ${startedAt.toIso8601String()}')
    ..writeln('- Finished (UTC): ${finishedAt.toIso8601String()}')
    ..writeln(
      '- Duration: ${(duration.inMilliseconds / 1000.0).toStringAsFixed(2)}s',
    )
    ..writeln('- Dart: $dartVersion')
    ..writeln(
      '- Platform: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
    )
    ..writeln('- CPU logical cores: ${Platform.numberOfProcessors}')
    ..writeln('')
    ..writeln('## Config')
    ..writeln('')
    ..writeln('- Presets: ${config.presets.join(", ")}')
    ..writeln('- Sizes: ${config.sizes.join(", ")}')
    ..writeln('- Warmup runs: ${config.warmupRuns}')
    ..writeln('- Measured runs: ${config.repeat}')
    ..writeln('- Base seed: ${config.seed}')
    ..writeln('')
    ..writeln('## Artifacts')
    ..writeln('')
    ..writeln('- JSON: `$jsonPath`')
    ..writeln('- CSV: `$csvPath`')
    ..writeln('')
    ..writeln('## Summary (mean ops/s)')
    ..writeln('')
    ..writeln(
      '| Preset | Nodes | Metric | Mean ops/s | p50 ops/s | p95 ops/s |',
    )
    ..writeln('| --- | ---: | --- | ---: | ---: | ---: |');

  for (final MetricSummary item in summary) {
    buffer.writeln(
      '| ${item.preset} | ${item.nodeCount} | ${item.metric} | '
      '${item.meanOperationsPerSecond.toStringAsFixed(0)} | '
      '${item.p50OperationsPerSecond.toStringAsFixed(0)} | '
      '${item.p95OperationsPerSecond.toStringAsFixed(0)} |',
    );
  }

  return buffer.toString();
}

Future<String> _readDartVersion() async {
  final ProcessResult result = await Process.run('dart', <String>['--version']);
  final String stdoutText = (result.stdout as String).trim();
  final String stderrText = (result.stderr as String).trim();
  final String text = stdoutText.isNotEmpty ? stdoutText : stderrText;
  return text.isNotEmpty ? text : 'unknown';
}

String _timestampForPath(DateTime value) {
  final String iso = value.toIso8601String();
  return iso.replaceAll(':', '-').replaceAll('.', '-');
}

void _printUsage() {
  stdout.writeln('Usage: dart run benchmark/paper_benchmark.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --presets=generic,social,delivery,notes_rag   Comma-separated presets.',
  );
  stdout.writeln(
    '  --sizes=10000,50000,100000                    Comma-separated node counts.',
  );
  stdout.writeln(
    '  --warmup-runs=1                                Warm-up runs per preset.',
  );
  stdout.writeln(
    '  --repeat=3                                     Measured runs per preset.',
  );
  stdout.writeln('  --seed=42                                      Base seed.');
  stdout.writeln(
    '  --edge-factor=INT                              Override edge factor.',
  );
  stdout.writeln(
    '  --label-count=INT                              Override label count.',
  );
  stdout.writeln(
    '  --property-cardinality=INT                     Override property cardinality.',
  );
  stdout.writeln(
    '  --lookup-queries=INT                           Override lookup queries.',
  );
  stdout.writeln(
    '  --path-queries=INT                             Override path queries.',
  );
  stdout.writeln(
    '  --output-dir=PATH                              Output directory.',
  );
  stdout.writeln(
    '  --save-raw-logs=(true|false)                  Save per-run raw logs (default true).',
  );
  stdout.writeln(
    '  --help                                         Print help.',
  );
}

class RunnerConfig {
  RunnerConfig({
    required this.presets,
    required this.sizes,
    required this.warmupRuns,
    required this.repeat,
    required this.seed,
    required this.edgeFactor,
    required this.labelCount,
    required this.propertyCardinality,
    required this.lookupQueries,
    required this.pathQueries,
    required this.outputDir,
    required this.saveRawLogs,
    required this.showHelp,
  });

  factory RunnerConfig.parse(List<String> args) {
    List<String> presets = <String>[
      'generic',
      'social',
      'delivery',
      'notes_rag',
    ];
    List<int> sizes = <int>[10000, 50000, 100000];
    int warmupRuns = 1;
    int repeat = 3;
    int seed = 42;
    int? edgeFactor;
    int? labelCount;
    int? propertyCardinality;
    int? lookupQueries;
    int? pathQueries;
    String? outputDir;
    bool saveRawLogs = true;
    bool showHelp = false;

    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];

      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }

      if (arg.startsWith('--presets=')) {
        presets = _parsePresetList(arg.substring('--presets='.length));
        continue;
      }
      if (arg == '--presets') {
        presets = _parsePresetList(_nextArgValue(args, i));
        i += 1;
        continue;
      }

      if (arg.startsWith('--sizes=')) {
        sizes = _parseIntList(arg.substring('--sizes='.length), 'sizes');
        continue;
      }
      if (arg == '--sizes') {
        sizes = _parseIntList(_nextArgValue(args, i), 'sizes');
        i += 1;
        continue;
      }

      if (arg.startsWith('--warmup-runs=')) {
        warmupRuns = _parseNonNegativeInt(
          arg.substring('--warmup-runs='.length),
          'warmup-runs',
        );
        continue;
      }
      if (arg == '--warmup-runs') {
        warmupRuns = _parseNonNegativeInt(
          _nextArgValue(args, i),
          'warmup-runs',
        );
        i += 1;
        continue;
      }

      if (arg.startsWith('--repeat=')) {
        repeat = _parsePositiveInt(arg.substring('--repeat='.length), 'repeat');
        continue;
      }
      if (arg == '--repeat') {
        repeat = _parsePositiveInt(_nextArgValue(args, i), 'repeat');
        i += 1;
        continue;
      }

      if (arg.startsWith('--seed=')) {
        seed = _parseNonNegativeInt(arg.substring('--seed='.length), 'seed');
        continue;
      }
      if (arg == '--seed') {
        seed = _parseNonNegativeInt(_nextArgValue(args, i), 'seed');
        i += 1;
        continue;
      }

      if (arg.startsWith('--edge-factor=')) {
        edgeFactor = _parsePositiveInt(
          arg.substring('--edge-factor='.length),
          'edge-factor',
        );
        continue;
      }
      if (arg == '--edge-factor') {
        edgeFactor = _parsePositiveInt(_nextArgValue(args, i), 'edge-factor');
        i += 1;
        continue;
      }

      if (arg.startsWith('--label-count=')) {
        labelCount = _parsePositiveInt(
          arg.substring('--label-count='.length),
          'label-count',
        );
        continue;
      }
      if (arg == '--label-count') {
        labelCount = _parsePositiveInt(_nextArgValue(args, i), 'label-count');
        i += 1;
        continue;
      }

      if (arg.startsWith('--property-cardinality=')) {
        propertyCardinality = _parsePositiveInt(
          arg.substring('--property-cardinality='.length),
          'property-cardinality',
        );
        continue;
      }
      if (arg == '--property-cardinality') {
        propertyCardinality = _parsePositiveInt(
          _nextArgValue(args, i),
          'property-cardinality',
        );
        i += 1;
        continue;
      }

      if (arg.startsWith('--lookup-queries=')) {
        lookupQueries = _parsePositiveInt(
          arg.substring('--lookup-queries='.length),
          'lookup-queries',
        );
        continue;
      }
      if (arg == '--lookup-queries') {
        lookupQueries = _parsePositiveInt(
          _nextArgValue(args, i),
          'lookup-queries',
        );
        i += 1;
        continue;
      }

      if (arg.startsWith('--path-queries=')) {
        pathQueries = _parseNonNegativeInt(
          arg.substring('--path-queries='.length),
          'path-queries',
        );
        continue;
      }
      if (arg == '--path-queries') {
        pathQueries = _parseNonNegativeInt(
          _nextArgValue(args, i),
          'path-queries',
        );
        i += 1;
        continue;
      }

      if (arg.startsWith('--output-dir=')) {
        outputDir = arg.substring('--output-dir='.length).trim();
        continue;
      }
      if (arg == '--output-dir') {
        outputDir = _nextArgValue(args, i).trim();
        i += 1;
        continue;
      }

      if (arg.startsWith('--save-raw-logs=')) {
        saveRawLogs = _parseBool(
          arg.substring('--save-raw-logs='.length),
          'save-raw-logs',
        );
        continue;
      }
      if (arg == '--save-raw-logs') {
        saveRawLogs = _parseBool(_nextArgValue(args, i), 'save-raw-logs');
        i += 1;
        continue;
      }

      throw FormatException('Unknown argument "$arg".');
    }

    if (presets.isEmpty) {
      throw const FormatException('presets must not be empty.');
    }
    if (sizes.isEmpty) {
      throw const FormatException('sizes must not be empty.');
    }

    return RunnerConfig(
      presets: presets,
      sizes: sizes,
      warmupRuns: warmupRuns,
      repeat: repeat,
      seed: seed,
      edgeFactor: edgeFactor,
      labelCount: labelCount,
      propertyCardinality: propertyCardinality,
      lookupQueries: lookupQueries,
      pathQueries: pathQueries,
      outputDir: outputDir,
      saveRawLogs: saveRawLogs,
      showHelp: showHelp,
    );
  }

  final List<String> presets;
  final List<int> sizes;
  final int warmupRuns;
  final int repeat;
  final int seed;
  final int? edgeFactor;
  final int? labelCount;
  final int? propertyCardinality;
  final int? lookupQueries;
  final int? pathQueries;
  final String? outputDir;
  final bool saveRawLogs;
  final bool showHelp;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'presets': presets,
      'sizes': sizes,
      'warmupRuns': warmupRuns,
      'repeat': repeat,
      'seed': seed,
      'edgeFactor': edgeFactor,
      'labelCount': labelCount,
      'propertyCardinality': propertyCardinality,
      'lookupQueries': lookupQueries,
      'pathQueries': pathQueries,
      'outputDir': outputDir,
      'saveRawLogs': saveRawLogs,
    };
  }
}

class ScenarioRunBuilder {
  ScenarioRunBuilder({required this.nodeCount, required this.edgeCount});

  final int nodeCount;
  final int edgeCount;
  final List<MetricRun> metrics = <MetricRun>[];

  ScenarioRun build() {
    return ScenarioRun(
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      metrics: List<MetricRun>.unmodifiable(metrics),
    );
  }
}

class ScenarioRun {
  ScenarioRun({
    required this.nodeCount,
    required this.edgeCount,
    required this.metrics,
  });

  final int nodeCount;
  final int edgeCount;
  final List<MetricRun> metrics;
}

class MetricRun {
  MetricRun({
    required this.name,
    required this.operations,
    required this.totalMilliseconds,
    required this.microsecondsPerOperation,
    required this.operationsPerSecond,
  });

  final String name;
  final int operations;
  final double totalMilliseconds;
  final double microsecondsPerOperation;
  final double operationsPerSecond;
}

class MetricSample {
  MetricSample({
    required this.preset,
    required this.runIndex,
    required this.nodeCount,
    required this.edgeCount,
    required this.metric,
    required this.operations,
    required this.totalMilliseconds,
    required this.microsecondsPerOperation,
    required this.operationsPerSecond,
  });

  final String preset;
  final int runIndex;
  final int nodeCount;
  final int edgeCount;
  final String metric;
  final int operations;
  final double totalMilliseconds;
  final double microsecondsPerOperation;
  final double operationsPerSecond;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'preset': preset,
      'runIndex': runIndex,
      'nodeCount': nodeCount,
      'edgeCount': edgeCount,
      'metric': metric,
      'operations': operations,
      'totalMilliseconds': totalMilliseconds,
      'microsecondsPerOperation': microsecondsPerOperation,
      'operationsPerSecond': operationsPerSecond,
    };
  }
}

class MetricSummary {
  MetricSummary({
    required this.preset,
    required this.nodeCount,
    required this.edgeCount,
    required this.metric,
    required this.runs,
    required this.meanOperationsPerSecond,
    required this.p50OperationsPerSecond,
    required this.p95OperationsPerSecond,
    required this.stddevOperationsPerSecond,
    required this.meanMicrosecondsPerOperation,
    required this.p50MicrosecondsPerOperation,
    required this.p95MicrosecondsPerOperation,
  });

  final String preset;
  final int nodeCount;
  final int edgeCount;
  final String metric;
  final int runs;
  final double meanOperationsPerSecond;
  final double p50OperationsPerSecond;
  final double p95OperationsPerSecond;
  final double stddevOperationsPerSecond;
  final double meanMicrosecondsPerOperation;
  final double p50MicrosecondsPerOperation;
  final double p95MicrosecondsPerOperation;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'preset': preset,
      'nodeCount': nodeCount,
      'edgeCount': edgeCount,
      'metric': metric,
      'runs': runs,
      'meanOperationsPerSecond': meanOperationsPerSecond,
      'p50OperationsPerSecond': p50OperationsPerSecond,
      'p95OperationsPerSecond': p95OperationsPerSecond,
      'stddevOperationsPerSecond': stddevOperationsPerSecond,
      'meanMicrosecondsPerOperation': meanMicrosecondsPerOperation,
      'p50MicrosecondsPerOperation': p50MicrosecondsPerOperation,
      'p95MicrosecondsPerOperation': p95MicrosecondsPerOperation,
    };
  }
}

class _SummaryKey {
  const _SummaryKey({
    required this.preset,
    required this.nodeCount,
    required this.edgeCount,
    required this.metric,
  });

  final String preset;
  final int nodeCount;
  final int edgeCount;
  final String metric;

  @override
  bool operator ==(Object other) {
    return other is _SummaryKey &&
        other.preset == preset &&
        other.nodeCount == nodeCount &&
        other.edgeCount == edgeCount &&
        other.metric == metric;
  }

  @override
  int get hashCode => Object.hash(preset, nodeCount, edgeCount, metric);
}

List<String> _parsePresetList(String raw) {
  final List<String> values = raw
      .split(',')
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
  for (final String value in values) {
    if (!_validPresets.contains(value)) {
      throw FormatException(
        'Unknown preset "$value". Allowed: ${_validPresets.join(", ")}',
      );
    }
  }
  return values;
}

List<int> _parseIntList(String raw, String name) {
  final List<String> values = raw
      .split(',')
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
  final List<int> result = <int>[];
  for (final String value in values) {
    result.add(_parsePositiveInt(value, name));
  }
  return result;
}

int _parsePositiveInt(String value, String name) {
  final int? parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw FormatException('$name must be a positive integer, got "$value".');
  }
  return parsed;
}

int _parseNonNegativeInt(String value, String name) {
  final int? parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw FormatException(
      '$name must be a non-negative integer, got "$value".',
    );
  }
  return parsed;
}

bool _parseBool(String raw, String name) {
  final String value = raw.trim().toLowerCase();
  if (value == 'true') {
    return true;
  }
  if (value == 'false') {
    return false;
  }
  throw FormatException('$name must be true or false, got "$raw".');
}

String _nextArgValue(List<String> args, int index) {
  if (index + 1 >= args.length) {
    throw FormatException('Missing value for ${args[index]}.');
  }
  return args[index + 1];
}

const List<String> _validPresets = <String>[
  'generic',
  'social',
  'delivery',
  'notes_rag',
];
