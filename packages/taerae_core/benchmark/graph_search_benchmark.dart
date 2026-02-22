import 'dart:io';
import 'dart:math';

import 'package:taerae/taerae.dart';

void main(List<String> args) {
  final BenchmarkConfig config;
  try {
    config = BenchmarkConfig.parse(args);
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

  stdout.writeln('TaeraeGraph Core Benchmark');
  stdout.writeln(
    'preset=${config.preset.cliName} sizes=${config.sizes.join(",")} '
    'edgeFactor=${config.edgeFactor} labels=${config.labelCount} '
    'propertyCardinality=${config.propertyCardinality} '
    'lookupQueries=${config.lookupQueries} pathQueries=${config.pathQueries} '
    'seed=${config.seed}',
  );
  stdout.writeln(config.preset.description);

  final List<ScenarioResult> scenarios = <ScenarioResult>[];
  for (final int nodeCount in config.sizes) {
    scenarios.add(_runScenario(nodeCount, config));
  }

  for (final ScenarioResult scenario in scenarios) {
    _printScenario(scenario);
  }

  _printScaleSummary(scenarios);
}

ScenarioResult _runScenario(int nodeCount, BenchmarkConfig config) {
  switch (config.preset) {
    case BenchmarkPreset.generic:
      return _runGenericScenario(nodeCount, config);
    case BenchmarkPreset.social:
      return _runSocialScenario(nodeCount, config);
    case BenchmarkPreset.delivery:
      return _runDeliveryScenario(nodeCount, config);
    case BenchmarkPreset.notesRag:
      return _runNotesRagScenario(nodeCount, config);
  }
}

ScenarioResult _runGenericScenario(int nodeCount, BenchmarkConfig config) {
  final TaeraeGraph graph = TaeraeGraph();
  final List<BenchmarkMetric> metrics = <BenchmarkMetric>[];

  metrics.add(
    _measure(
      name: 'upsertNode',
      operations: nodeCount,
      run: () {
        for (int i = 0; i < nodeCount; i++) {
          graph.upsertNode(
            'n$i',
            labels: <String>['L${i % config.labelCount}'],
            properties: <String, Object?>{
              'bucket': i % config.propertyCardinality,
              'is_even': i.isEven,
              'score': i,
              'meta': <String, Object?>{'region': 'R${i % 16}', 'tier': i % 4},
            },
          );
        }
        return nodeCount;
      },
    ),
  );

  int edgeCount = 0;
  metrics.add(
    _measure(
      name: 'upsertEdge',
      operations: nodeCount * config.edgeFactor,
      run: () {
        int edgeId = 0;
        for (int from = 0; from < nodeCount; from++) {
          for (int hop = 1; hop <= config.edgeFactor; hop++) {
            final int to = (from + hop) % nodeCount;
            graph.upsertEdge(
              'e${edgeId++}',
              'n$from',
              'n$to',
              type: 'step_$hop',
            );
          }
        }
        edgeCount = edgeId;
        return edgeId;
      },
    ),
  );

  final int warmUp = min(config.lookupQueries, 500);
  for (int i = 0; i < warmUp; i++) {
    final int id = i % nodeCount;
    graph.nodeById('n$id');
    graph.nodesByLabel('L${id % config.labelCount}');
    graph.nodesWhereProperty('bucket', id % config.propertyCardinality);
    graph.outgoing('n$id');
  }

  final int pathWarmUp = min(config.pathQueries, 20);
  for (int i = 0; i < pathWarmUp; i++) {
    final int start = i % nodeCount;
    final int end = (start + (nodeCount ~/ 3)) % nodeCount;
    graph.shortestPathBfs('n$start', 'n$end');
  }

  metrics.add(
    _measure(
      name: 'nodeById',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 101);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final TaeraeNode? node = graph.nodeById(
            'n${random.nextInt(nodeCount)}',
          );
          if (node != null) {
            local += node.id.length;
          }
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesByLabel',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 202);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String label = 'L${random.nextInt(config.labelCount)}';
          local += graph.nodesByLabel(label).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesWhereProperty',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 303);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int bucket = random.nextInt(config.propertyCardinality);
          local += graph.nodesWhereProperty('bucket', bucket).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'outgoing',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 404);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int id = random.nextInt(nodeCount);
          local += graph.outgoing('n$id').length;
        }
        return local;
      },
    ),
  );

  if (config.pathQueries > 0) {
    metrics.add(
      _measure(
        name: 'shortestPathBfs',
        operations: config.pathQueries,
        run: () {
          final Random random = _rng(config.seed, nodeCount, 505);
          int local = 0;
          for (int i = 0; i < config.pathQueries; i++) {
            final int start = random.nextInt(nodeCount);
            final int end = (start + (nodeCount ~/ 2)) % nodeCount;
            final List<String>? path = graph.shortestPathBfs(
              'n$start',
              'n$end',
            );
            local += path?.length ?? 0;
          }
          return local;
        },
      ),
    );
  }

  return _finishScenario(nodeCount, edgeCount, metrics);
}

ScenarioResult _runSocialScenario(int nodeCount, BenchmarkConfig config) {
  final TaeraeGraph graph = TaeraeGraph();
  final List<BenchmarkMetric> metrics = <BenchmarkMetric>[];

  int userCount = nodeCount;
  int interestCount = 0;
  if (nodeCount > 1) {
    userCount = (nodeCount * 0.7).round();
    userCount = _clampInt(userCount, 1, nodeCount - 1);
    interestCount = nodeCount - userCount;
  }

  metrics.add(
    _measure(
      name: 'upsertNode',
      operations: nodeCount,
      run: () {
        for (int i = 0; i < userCount; i++) {
          graph.upsertNode(
            'u$i',
            labels: const <String>['User'],
            properties: <String, Object?>{
              'segment': i % config.propertyCardinality,
              'active': i % 5 != 0,
              'tier': i % 4,
            },
          );
        }
        for (int i = 0; i < interestCount; i++) {
          graph.upsertNode(
            't$i',
            labels: const <String>['Interest'],
            properties: <String, Object?>{
              'topic': i % max(8, config.propertyCardinality ~/ 2),
            },
          );
        }
        return nodeCount;
      },
    ),
  );

  int edgeCount = 0;
  metrics.add(
    _measure(
      name: 'upsertEdge',
      operations: _socialEdgeOperationCount(
        userCount: userCount,
        interestCount: interestCount,
        edgeFactor: config.edgeFactor,
      ),
      run: () {
        int edgeId = 0;
        final int followsPerUser = userCount <= 1
            ? 0
            : min(config.edgeFactor, userCount - 1);
        final int interestsPerUser = interestCount == 0
            ? 0
            : min(3, interestCount);

        for (int user = 0; user < userCount; user++) {
          for (int hop = 1; hop <= followsPerUser; hop++) {
            final int to = (user + hop) % userCount;
            graph.upsertEdge('e${edgeId++}', 'u$user', 'u$to', type: 'FOLLOWS');
          }

          for (int slot = 0; slot < interestsPerUser; slot++) {
            final int topic = (user * 31 + slot * 7) % interestCount;
            graph.upsertEdge(
              'e${edgeId++}',
              'u$user',
              't$topic',
              type: 'HAS_INTEREST',
            );
          }
        }

        edgeCount = edgeId;
        return edgeId;
      },
    ),
  );

  final int warmUp = min(config.lookupQueries, 500);
  for (int i = 0; i < warmUp; i++) {
    if (userCount > 0) {
      graph.nodeById('u${i % userCount}');
      graph.nodesWhereProperty('segment', i % config.propertyCardinality);
      graph.outgoing('u${i % userCount}', type: 'FOLLOWS');
    }
    if (interestCount > 0) {
      graph.nodeById('t${i % interestCount}');
    }
    graph.nodesByLabel('User');
    graph.nodesByLabel('Interest');
  }

  final int pathWarmUp = min(config.pathQueries, 20);
  for (int i = 0; i < pathWarmUp; i++) {
    if (userCount <= 1) {
      break;
    }
    final int start = i % userCount;
    final int end = (start + (userCount ~/ 2)) % userCount;
    graph.shortestPathBfs('u$start', 'u$end', edgeType: 'FOLLOWS');
  }

  metrics.add(
    _measure(
      name: 'nodeById',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 1001);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final bool pickUser = interestCount == 0 || random.nextDouble() < 0.8;
          final TaeraeNode? node = pickUser
              ? graph.nodeById('u${random.nextInt(max(userCount, 1))}')
              : graph.nodeById('t${random.nextInt(interestCount)}');
          if (node != null) {
            local += node.id.length;
          }
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesByLabel',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 1002);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String label = (interestCount == 0 || random.nextDouble() < 0.8)
              ? 'User'
              : 'Interest';
          local += graph.nodesByLabel(label).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesWhereProperty',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 1003);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int segment = random.nextInt(config.propertyCardinality);
          local += graph.nodesWhereProperty('segment', segment).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'outgoing(FOLLOWS)',
      operations: config.lookupQueries,
      run: () {
        if (userCount == 0) {
          return 0;
        }

        final Random random = _rng(config.seed, nodeCount, 1004);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int user = random.nextInt(userCount);
          local += graph.outgoing('u$user', type: 'FOLLOWS').length;
        }
        return local;
      },
    ),
  );

  final int recQueries = max(1, config.lookupQueries ~/ 10);
  metrics.add(
    _measure(
      name: 'twoHopRecommend',
      operations: recQueries,
      run: () {
        if (userCount <= 1) {
          return 0;
        }

        final Random random = _rng(config.seed, nodeCount, 1005);
        int local = 0;
        for (int i = 0; i < recQueries; i++) {
          final int user = random.nextInt(userCount);
          final String userId = 'u$user';
          final Set<String> following = graph
              .outgoing(userId, type: 'FOLLOWS')
              .map((TaeraeEdge edge) => edge.to)
              .toSet();
          final Set<String> candidates = <String>{};
          for (final String friendId in following) {
            for (final TaeraeEdge edge in graph.outgoing(
              friendId,
              type: 'FOLLOWS',
            )) {
              if (edge.to == userId || following.contains(edge.to)) {
                continue;
              }
              candidates.add(edge.to);
            }
          }
          local += candidates.length;
        }
        return local;
      },
    ),
  );

  if (config.pathQueries > 0) {
    metrics.add(
      _measure(
        name: 'shortestPath(FOLLOWS)',
        operations: config.pathQueries,
        run: () {
          if (userCount <= 1) {
            return 0;
          }

          final Random random = _rng(config.seed, nodeCount, 1006);
          int local = 0;
          for (int i = 0; i < config.pathQueries; i++) {
            final int start = random.nextInt(userCount);
            final int end = random.nextInt(userCount);
            final List<String>? path = graph.shortestPathBfs(
              'u$start',
              'u$end',
              edgeType: 'FOLLOWS',
            );
            local += path?.length ?? 0;
          }
          return local;
        },
      ),
    );
  }

  return _finishScenario(nodeCount, edgeCount, metrics);
}

ScenarioResult _runDeliveryScenario(int nodeCount, BenchmarkConfig config) {
  final TaeraeGraph graph = TaeraeGraph();
  final List<BenchmarkMetric> metrics = <BenchmarkMetric>[];

  int placeCount;
  int packageCount;
  if (nodeCount <= 1) {
    placeCount = nodeCount;
    packageCount = 0;
  } else if (nodeCount == 2) {
    placeCount = 1;
    packageCount = 1;
  } else {
    placeCount = (nodeCount * 0.35).round();
    placeCount = _clampInt(placeCount, 2, nodeCount - 1);
    packageCount = nodeCount - placeCount;
  }

  const List<String> statuses = <String>[
    'pending',
    'in_transit',
    'delivered',
    'exception',
  ];
  const List<String> priorities = <String>['normal', 'high', 'critical'];

  metrics.add(
    _measure(
      name: 'upsertNode',
      operations: nodeCount,
      run: () {
        for (int i = 0; i < placeCount; i++) {
          graph.upsertNode(
            'place$i',
            labels: const <String>['Place'],
            properties: <String, Object?>{
              'zone': i % max(4, config.labelCount),
              'hub': i % 11 == 0,
            },
          );
        }
        for (int i = 0; i < packageCount; i++) {
          graph.upsertNode(
            'pkg$i',
            labels: const <String>['Package'],
            properties: <String, Object?>{
              'status': statuses[i % statuses.length],
              'priority': priorities[i % priorities.length],
              'bucket': i % config.propertyCardinality,
            },
          );
        }
        return nodeCount;
      },
    ),
  );

  int edgeCount = 0;
  metrics.add(
    _measure(
      name: 'upsertEdge',
      operations: _deliveryEdgeOperationCount(
        placeCount: placeCount,
        packageCount: packageCount,
        edgeFactor: config.edgeFactor,
      ),
      run: () {
        int edgeId = 0;

        final int routePerPlace = placeCount <= 1
            ? 0
            : min(config.edgeFactor, placeCount - 1);
        for (int place = 0; place < placeCount; place++) {
          for (int hop = 1; hop <= routePerPlace; hop++) {
            final int to = (place + hop) % placeCount;
            graph.upsertEdge(
              'e${edgeId++}',
              'place$place',
              'place$to',
              type: 'ROUTE',
            );
          }
        }

        for (int pkg = 0; pkg < packageCount; pkg++) {
          if (placeCount == 0) {
            break;
          }
          graph.upsertEdge(
            'e${edgeId++}',
            'pkg$pkg',
            'place${pkg % placeCount}',
            type: 'DELIVERS_TO',
          );
        }

        edgeCount = edgeId;
        return edgeId;
      },
    ),
  );

  final int warmUp = min(config.lookupQueries, 500);
  for (int i = 0; i < warmUp; i++) {
    if (placeCount > 0) {
      graph.nodeById('place${i % placeCount}');
      graph.outgoing('place${i % placeCount}', type: 'ROUTE');
    }
    if (packageCount > 0) {
      graph.nodeById('pkg${i % packageCount}');
    }
    graph.nodesWhereProperty('status', statuses[i % statuses.length]);
    graph.nodesByLabel('Package');
  }

  final int pathWarmUp = min(config.pathQueries, 20);
  for (int i = 0; i < pathWarmUp; i++) {
    if (placeCount <= 1) {
      break;
    }
    final int start = i % placeCount;
    final int end = (start + (placeCount ~/ 2)) % placeCount;
    graph.shortestPathBfs('place$start', 'place$end', edgeType: 'ROUTE');
  }

  metrics.add(
    _measure(
      name: 'nodeById',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 2001);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final bool pickPlace = packageCount == 0 || random.nextDouble() < 0.4;
          final TaeraeNode? node = pickPlace
              ? graph.nodeById('place${random.nextInt(max(placeCount, 1))}')
              : graph.nodeById('pkg${random.nextInt(packageCount)}');
          if (node != null) {
            local += node.id.length;
          }
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesByLabel',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 2002);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String label = (packageCount == 0 || random.nextDouble() < 0.3)
              ? 'Place'
              : 'Package';
          local += graph.nodesByLabel(label).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesWhereProperty',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 2003);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String status = statuses[random.nextInt(statuses.length)];
          local += graph.nodesWhereProperty('status', status).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'outgoing(ROUTE)',
      operations: config.lookupQueries,
      run: () {
        if (placeCount == 0) {
          return 0;
        }

        final Random random = _rng(config.seed, nodeCount, 2004);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int place = random.nextInt(placeCount);
          local += graph.outgoing('place$place', type: 'ROUTE').length;
        }
        return local;
      },
    ),
  );

  final int pendingQueries = max(1, config.lookupQueries ~/ 10);
  metrics.add(
    _measure(
      name: 'pendingPackages',
      operations: pendingQueries,
      run: () {
        int local = 0;
        for (int i = 0; i < pendingQueries; i++) {
          local += graph.nodesWhereProperty('status', 'pending').length;
        }
        return local;
      },
    ),
  );

  if (config.pathQueries > 0) {
    metrics.add(
      _measure(
        name: 'shortestPath(ROUTE)',
        operations: config.pathQueries,
        run: () {
          if (placeCount <= 1) {
            return 0;
          }

          final Random random = _rng(config.seed, nodeCount, 2005);
          int local = 0;
          for (int i = 0; i < config.pathQueries; i++) {
            final int start = random.nextInt(placeCount);
            final int end = random.nextInt(placeCount);
            final List<String>? path = graph.shortestPathBfs(
              'place$start',
              'place$end',
              edgeType: 'ROUTE',
            );
            local += path?.length ?? 0;
          }
          return local;
        },
      ),
    );
  }

  return _finishScenario(nodeCount, edgeCount, metrics);
}

ScenarioResult _runNotesRagScenario(int nodeCount, BenchmarkConfig config) {
  final TaeraeGraph graph = TaeraeGraph();
  final List<BenchmarkMetric> metrics = <BenchmarkMetric>[];

  int noteCount = nodeCount;
  int topicCount = 0;
  if (nodeCount > 1) {
    noteCount = (nodeCount * 0.85).round();
    noteCount = _clampInt(noteCount, 1, nodeCount - 1);
    topicCount = nodeCount - noteCount;
  }
  final int categoryCount = max(4, min(32, config.propertyCardinality));

  metrics.add(
    _measure(
      name: 'upsertNode',
      operations: nodeCount,
      run: () {
        for (int i = 0; i < noteCount; i++) {
          graph.upsertNode(
            'note$i',
            labels: const <String>['Note'],
            properties: <String, Object?>{
              'category': 'c${i % categoryCount}',
              'urgent': i % 10 == 0,
              'bucket': i % config.propertyCardinality,
            },
          );
        }

        for (int i = 0; i < topicCount; i++) {
          graph.upsertNode(
            'topic$i',
            labels: const <String>['Topic'],
            properties: <String, Object?>{'name': 't${i % categoryCount}'},
          );
        }
        return nodeCount;
      },
    ),
  );

  int edgeCount = 0;
  metrics.add(
    _measure(
      name: 'upsertEdge',
      operations: _notesEdgeOperationCount(
        noteCount: noteCount,
        topicCount: topicCount,
        edgeFactor: config.edgeFactor,
      ),
      run: () {
        int edgeId = 0;
        final int relatedPerNote = noteCount <= 1
            ? 0
            : min(config.edgeFactor, noteCount - 1);
        for (int note = 0; note < noteCount; note++) {
          for (int hop = 1; hop <= relatedPerNote; hop++) {
            final int target = (note + hop) % noteCount;
            graph.upsertEdge(
              'e${edgeId++}',
              'note$note',
              'note$target',
              type: 'RELATED',
            );
          }

          if (topicCount > 0) {
            graph.upsertEdge(
              'e${edgeId++}',
              'note$note',
              'topic${note % topicCount}',
              type: 'TAGGED_AS',
            );
          }
        }

        edgeCount = edgeId;
        return edgeId;
      },
    ),
  );

  final int warmUp = min(config.lookupQueries, 500);
  for (int i = 0; i < warmUp; i++) {
    if (noteCount > 0) {
      graph.nodeById('note${i % noteCount}');
      graph.outgoing('note${i % noteCount}', type: 'RELATED');
      graph.neighbors('note${i % noteCount}', type: 'RELATED');
    }
    if (topicCount > 0) {
      graph.nodeById('topic${i % topicCount}');
    }
    graph.nodesByLabel('Note');
    graph.nodesWhereProperty('category', 'c${i % categoryCount}');
    graph.nodesWhereProperty('urgent', true);
  }

  final int pathWarmUp = min(config.pathQueries, 20);
  for (int i = 0; i < pathWarmUp; i++) {
    if (noteCount <= 1) {
      break;
    }
    final int start = i % noteCount;
    final int end = (start + (noteCount ~/ 2)) % noteCount;
    graph.shortestPathBfs('note$start', 'note$end', edgeType: 'RELATED');
  }

  metrics.add(
    _measure(
      name: 'nodeById',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 3001);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final bool pickNote = topicCount == 0 || random.nextDouble() < 0.85;
          final TaeraeNode? node = pickNote
              ? graph.nodeById('note${random.nextInt(max(noteCount, 1))}')
              : graph.nodeById('topic${random.nextInt(topicCount)}');
          if (node != null) {
            local += node.id.length;
          }
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesByLabel',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 3002);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String label = (topicCount == 0 || random.nextDouble() < 0.9)
              ? 'Note'
              : 'Topic';
          local += graph.nodesByLabel(label).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'nodesWhereProperty',
      operations: config.lookupQueries,
      run: () {
        final Random random = _rng(config.seed, nodeCount, 3003);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final String category = 'c${random.nextInt(categoryCount)}';
          local += graph.nodesWhereProperty('category', category).length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'outgoing(RELATED)',
      operations: config.lookupQueries,
      run: () {
        if (noteCount == 0) {
          return 0;
        }

        final Random random = _rng(config.seed, nodeCount, 3004);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int note = random.nextInt(noteCount);
          local += graph.outgoing('note$note', type: 'RELATED').length;
        }
        return local;
      },
    ),
  );

  metrics.add(
    _measure(
      name: 'neighbors(RELATED)',
      operations: config.lookupQueries,
      run: () {
        if (noteCount == 0) {
          return 0;
        }

        final Random random = _rng(config.seed, nodeCount, 3005);
        int local = 0;
        for (int i = 0; i < config.lookupQueries; i++) {
          final int note = random.nextInt(noteCount);
          local += graph.neighbors('note$note', type: 'RELATED').length;
        }
        return local;
      },
    ),
  );

  final int urgentQueries = max(1, config.lookupQueries ~/ 10);
  metrics.add(
    _measure(
      name: 'urgentFilter',
      operations: urgentQueries,
      run: () {
        int local = 0;
        for (int i = 0; i < urgentQueries; i++) {
          local += graph.nodesWhereProperty('urgent', true).length;
        }
        return local;
      },
    ),
  );

  if (config.pathQueries > 0) {
    metrics.add(
      _measure(
        name: 'shortestPath(RELATED)',
        operations: config.pathQueries,
        run: () {
          if (noteCount <= 1) {
            return 0;
          }

          final Random random = _rng(config.seed, nodeCount, 3006);
          int local = 0;
          for (int i = 0; i < config.pathQueries; i++) {
            final int start = random.nextInt(noteCount);
            final int end = random.nextInt(noteCount);
            final List<String>? path = graph.shortestPathBfs(
              'note$start',
              'note$end',
              edgeType: 'RELATED',
            );
            local += path?.length ?? 0;
          }
          return local;
        },
      ),
    );
  }

  return _finishScenario(nodeCount, edgeCount, metrics);
}

ScenarioResult _finishScenario(
  int nodeCount,
  int edgeCount,
  List<BenchmarkMetric> metrics,
) {
  int checksum = 0;
  for (final BenchmarkMetric metric in metrics) {
    checksum ^= metric.checksum;
  }

  return ScenarioResult(
    nodeCount: nodeCount,
    edgeCount: edgeCount,
    metrics: metrics,
    checksum: checksum,
    rssBytes: ProcessInfo.currentRss,
  );
}

BenchmarkMetric _measure({
  required String name,
  required int operations,
  required int Function() run,
}) {
  final Stopwatch stopwatch = Stopwatch()..start();
  final int checksum = run();
  stopwatch.stop();

  return BenchmarkMetric(
    name: name,
    operations: operations,
    elapsed: stopwatch.elapsed,
    checksum: checksum,
  );
}

Random _rng(int seed, int nodeCount, int salt) {
  return Random(seed ^ (nodeCount * 31) ^ salt);
}

int _socialEdgeOperationCount({
  required int userCount,
  required int interestCount,
  required int edgeFactor,
}) {
  final int followsPerUser = userCount <= 1
      ? 0
      : min(edgeFactor, userCount - 1);
  final int interestsPerUser = interestCount == 0 ? 0 : min(3, interestCount);
  return userCount * (followsPerUser + interestsPerUser);
}

int _deliveryEdgeOperationCount({
  required int placeCount,
  required int packageCount,
  required int edgeFactor,
}) {
  final int routePerPlace = placeCount <= 1
      ? 0
      : min(edgeFactor, placeCount - 1);
  return (placeCount * routePerPlace) + packageCount;
}

int _notesEdgeOperationCount({
  required int noteCount,
  required int topicCount,
  required int edgeFactor,
}) {
  final int relatedPerNote = noteCount <= 1
      ? 0
      : min(edgeFactor, noteCount - 1);
  return (noteCount * relatedPerNote) + (topicCount > 0 ? noteCount : 0);
}

int _clampInt(int value, int minValue, int maxValue) {
  if (maxValue < minValue) {
    return minValue;
  }
  if (value < minValue) {
    return minValue;
  }
  if (value > maxValue) {
    return maxValue;
  }
  return value;
}

void _printScenario(ScenarioResult scenario) {
  stdout.writeln('');
  stdout.writeln(
    'Scenario: nodes=${scenario.nodeCount}, edges=${scenario.edgeCount}',
  );
  stdout.writeln(
    'Operation                     Ops        Total(ms)    us/op       ops/s',
  );

  for (final BenchmarkMetric metric in scenario.metrics) {
    final String totalMs = (metric.elapsed.inMicroseconds / 1000.0)
        .toStringAsFixed(2)
        .padLeft(12);
    final String usPerOp = metric.microsecondsPerOperation
        .toStringAsFixed(2)
        .padLeft(9);
    final String opsPerSec = metric.operationsPerSecond
        .toStringAsFixed(0)
        .padLeft(10);

    stdout.writeln(
      '${metric.name.padRight(28)} '
      '${metric.operations.toString().padLeft(10)} '
      '$totalMs '
      '$usPerOp '
      '$opsPerSec',
    );
  }

  stdout.writeln(
    'checksum=${scenario.checksum} rss=${_formatBytes(scenario.rssBytes)}',
  );
}

void _printScaleSummary(List<ScenarioResult> scenarios) {
  if (scenarios.length <= 1) {
    return;
  }

  final ScenarioResult first = scenarios.first;
  final ScenarioResult last = scenarios.last;

  stdout.writeln('');
  stdout.writeln(
    'Scale summary (${first.nodeCount} -> ${last.nodeCount} nodes):',
  );
  for (final BenchmarkMetric firstMetric in first.metrics) {
    final BenchmarkMetric? lastMetric = last.metricByName(firstMetric.name);
    if (lastMetric == null) {
      continue;
    }
    final double ratio =
        lastMetric.operationsPerSecond /
        max(firstMetric.operationsPerSecond, 1e-9);
    stdout.writeln(
      '${firstMetric.name.padRight(28)} '
      'ops/s ratio=${ratio.toStringAsFixed(2)}x',
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run benchmark/graph_search_benchmark.dart [options]',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --preset=generic             Workload preset: '
    'generic|social|delivery|notes_rag',
  );
  stdout.writeln('  --sizes=10000,50000,100000   Comma-separated node counts.');
  stdout.writeln(
    '  --edge-factor=4              Outgoing edge fan-out per primary node.',
  );
  stdout.writeln(
    '  --label-count=8              Label/topic cardinality hint.',
  );
  stdout.writeln(
    '  --property-cardinality=256   Distinct property value cardinality.',
  );
  stdout.writeln(
    '  --lookup-queries=50000       Queries per lookup benchmark.',
  );
  stdout.writeln(
    '  --path-queries=200           Queries for path/traversal benchmarks.',
  );
  stdout.writeln(
    '  --seed=42                    Seed for deterministic sampling.',
  );
  stdout.writeln('  --help                       Print this help message.');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln(
    '  dart run benchmark/graph_search_benchmark.dart '
    '--preset=social --sizes=20000,100000',
  );
  stdout.writeln(
    '  dart run benchmark/graph_search_benchmark.dart '
    '--preset=delivery --sizes=20000 --path-queries=500',
  );
  stdout.writeln(
    '  dart run benchmark/graph_search_benchmark.dart '
    '--preset=notes_rag --sizes=50000',
  );
}

enum BenchmarkPreset {
  generic,
  social,
  delivery,
  notesRag;

  String get cliName {
    switch (this) {
      case BenchmarkPreset.generic:
        return 'generic';
      case BenchmarkPreset.social:
        return 'social';
      case BenchmarkPreset.delivery:
        return 'delivery';
      case BenchmarkPreset.notesRag:
        return 'notes_rag';
    }
  }

  String get description {
    switch (this) {
      case BenchmarkPreset.generic:
        return 'Generic indexed graph workload.';
      case BenchmarkPreset.social:
        return 'Social recommendation workload (User/FOLLOWS/HAS_INTEREST).';
      case BenchmarkPreset.delivery:
        return 'Delivery routing workload (Place/Package/ROUTE/DELIVERS_TO).';
      case BenchmarkPreset.notesRag:
        return 'Notes + GraphRAG-like workload (Note/Topic/RELATED/TAGGED_AS).';
    }
  }

  static BenchmarkPreset parse(String raw) {
    final String value = raw.trim().toLowerCase();
    switch (value) {
      case 'generic':
        return BenchmarkPreset.generic;
      case 'social':
      case 'social_recommendation':
        return BenchmarkPreset.social;
      case 'delivery':
      case 'delivery_ops':
        return BenchmarkPreset.delivery;
      case 'notes_rag':
      case 'notes':
        return BenchmarkPreset.notesRag;
      default:
        throw FormatException(
          'Unknown preset "$raw". Use one of: generic, social, delivery, notes_rag.',
        );
    }
  }
}

class PresetDefaults {
  const PresetDefaults({
    required this.sizes,
    required this.edgeFactor,
    required this.labelCount,
    required this.propertyCardinality,
    required this.lookupQueries,
    required this.pathQueries,
  });

  final List<int> sizes;
  final int edgeFactor;
  final int labelCount;
  final int propertyCardinality;
  final int lookupQueries;
  final int pathQueries;
}

PresetDefaults _presetDefaults(BenchmarkPreset preset) {
  switch (preset) {
    case BenchmarkPreset.generic:
      return const PresetDefaults(
        sizes: <int>[10000, 50000, 100000],
        edgeFactor: 4,
        labelCount: 8,
        propertyCardinality: 256,
        lookupQueries: 50000,
        pathQueries: 200,
      );
    case BenchmarkPreset.social:
      return const PresetDefaults(
        sizes: <int>[10000, 50000, 100000],
        edgeFactor: 12,
        labelCount: 2,
        propertyCardinality: 128,
        lookupQueries: 50000,
        pathQueries: 300,
      );
    case BenchmarkPreset.delivery:
      return const PresetDefaults(
        sizes: <int>[10000, 50000, 100000],
        edgeFactor: 6,
        labelCount: 2,
        propertyCardinality: 64,
        lookupQueries: 40000,
        pathQueries: 500,
      );
    case BenchmarkPreset.notesRag:
      return const PresetDefaults(
        sizes: <int>[10000, 50000, 100000],
        edgeFactor: 3,
        labelCount: 2,
        propertyCardinality: 48,
        lookupQueries: 40000,
        pathQueries: 200,
      );
  }
}

class BenchmarkConfig {
  BenchmarkConfig({
    required this.preset,
    required this.sizes,
    required this.edgeFactor,
    required this.labelCount,
    required this.propertyCardinality,
    required this.lookupQueries,
    required this.pathQueries,
    required this.seed,
    required this.showHelp,
  });

  factory BenchmarkConfig.parse(List<String> args) {
    BenchmarkPreset preset = BenchmarkPreset.generic;
    bool showHelp = false;

    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }

      if (arg.startsWith('--preset=')) {
        preset = BenchmarkPreset.parse(arg.substring('--preset='.length));
        continue;
      }
      if (arg == '--preset') {
        preset = BenchmarkPreset.parse(_nextArgValue(args, i));
        i += 1;
        continue;
      }
    }

    final PresetDefaults defaults = _presetDefaults(preset);
    List<int> sizes = defaults.sizes;
    int edgeFactor = defaults.edgeFactor;
    int labelCount = defaults.labelCount;
    int propertyCardinality = defaults.propertyCardinality;
    int lookupQueries = defaults.lookupQueries;
    int pathQueries = defaults.pathQueries;
    int seed = 42;

    for (int i = 0; i < args.length; i++) {
      final String arg = args[i];
      if (arg == '--help' || arg == '-h') {
        continue;
      }

      if (arg.startsWith('--preset=')) {
        continue;
      }
      if (arg == '--preset') {
        i += 1;
        continue;
      }

      if (arg.startsWith('--sizes=')) {
        sizes = _parseSizes(arg.substring('--sizes='.length));
        continue;
      }
      if (arg == '--sizes') {
        sizes = _parseSizes(_nextArgValue(args, i));
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

      if (arg.startsWith('--seed=')) {
        seed = _parseNonNegativeInt(arg.substring('--seed='.length), 'seed');
        continue;
      }
      if (arg == '--seed') {
        seed = _parseNonNegativeInt(_nextArgValue(args, i), 'seed');
        i += 1;
        continue;
      }

      throw FormatException('Unknown argument "$arg".');
    }

    return BenchmarkConfig(
      preset: preset,
      sizes: sizes,
      edgeFactor: edgeFactor,
      labelCount: labelCount,
      propertyCardinality: propertyCardinality,
      lookupQueries: lookupQueries,
      pathQueries: pathQueries,
      seed: seed,
      showHelp: showHelp,
    );
  }

  final BenchmarkPreset preset;
  final List<int> sizes;
  final int edgeFactor;
  final int labelCount;
  final int propertyCardinality;
  final int lookupQueries;
  final int pathQueries;
  final int seed;
  final bool showHelp;
}

class BenchmarkMetric {
  BenchmarkMetric({
    required this.name,
    required this.operations,
    required this.elapsed,
    required this.checksum,
  });

  final String name;
  final int operations;
  final Duration elapsed;
  final int checksum;

  double get operationsPerSecond {
    if (elapsed.inMicroseconds == 0) {
      return operations.toDouble();
    }
    return operations / (elapsed.inMicroseconds / 1000000.0);
  }

  double get microsecondsPerOperation {
    if (operations == 0) {
      return 0;
    }
    return elapsed.inMicroseconds / operations;
  }
}

class ScenarioResult {
  ScenarioResult({
    required this.nodeCount,
    required this.edgeCount,
    required this.metrics,
    required this.checksum,
    required this.rssBytes,
  });

  final int nodeCount;
  final int edgeCount;
  final List<BenchmarkMetric> metrics;
  final int checksum;
  final int rssBytes;

  BenchmarkMetric? metricByName(String name) {
    for (final BenchmarkMetric metric in metrics) {
      if (metric.name == name) {
        return metric;
      }
    }
    return null;
  }
}

List<int> _parseSizes(String value) {
  final List<String> parts = value
      .split(',')
      .map((String token) => token.trim())
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    throw const FormatException('sizes must not be empty.');
  }

  final List<int> result = <int>[];
  for (final String part in parts) {
    result.add(_parsePositiveInt(part, 'sizes'));
  }
  return List<int>.unmodifiable(result);
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

String _nextArgValue(List<String> args, int currentIndex) {
  if (currentIndex + 1 >= args.length) {
    throw FormatException('Missing value for ${args[currentIndex]}.');
  }
  return args[currentIndex + 1];
}
