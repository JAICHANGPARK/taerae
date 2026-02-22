# taerae

`taerae` is an embedded graph database core for Dart.
It provides an in-memory graph engine, file-backed persistence, and GraphRAG integration points.

## Highlights

- Immutable models: `TaeraeNode`, `TaeraeEdge`
- In-memory graph APIs: `TaeraeGraph`
- File persistence with log + snapshot: `TaeraePersistentGraph`
- GraphRAG components: `TaeraeGraphRag`, `TaeraeTextEmbedder`, `TaeraeVectorIndex`

## Core Differentiators

- Embedded-first: no external graph server dependency for core graph features.
- Local-first durability: append-only log + snapshot with configurable durability policy.
- Dart-native API: no query language bridge required for common graph operations.
- GraphRAG extension ready: structured hooks for embedding, indexing, filtering, and reranking.

## Quick start

```dart
import 'package:taerae/taerae.dart';

void main() {
  final TaeraeGraph graph = TaeraeGraph()
    ..upsertNode('alice', labels: const <String>['Person'])
    ..upsertNode('bob', labels: const <String>['Person'])
    ..upsertEdge('e1', 'alice', 'bob', type: 'KNOWS');

  final List<String>? path = graph.shortestPathBfs('alice', 'bob');
  print(path); // [alice, bob]
}
```

## Detailed guide

- [Developer Guide](DEVELOPER_GUIDE.md)
  Detailed usage guide covering CRUD, traversal, JSON import/export,
  persistence durability, recovery strategy, GraphRAG workflows,
  defensive coding, performance, and testing patterns.

## Benchmark

Measure core performance for larger datasets with the bundled benchmark script.

```bash
dart run benchmark/graph_search_benchmark.dart --preset=generic
```

Workload presets:

- `generic`: balanced indexed graph workload.
- `social`: user follow/recommendation pattern (`FOLLOWS`, `HAS_INTEREST`).
- `delivery`: route + package tracking pattern (`ROUTE`, `DELIVERS_TO`).
- `notes_rag`: note-link + filter-heavy pattern (`RELATED`, `TAGGED_AS`).

Example runs:

```bash
dart run benchmark/graph_search_benchmark.dart \
  --preset=social \
  --sizes=20000,100000 \
  --path-queries=300

dart run benchmark/graph_search_benchmark.dart \
  --preset=delivery \
  --sizes=20000 \
  --path-queries=500
```

The benchmark reports build throughput (`upsertNode`, `upsertEdge`) and search
performance (label/property lookup, adjacency traversal, and shortest-path style
queries) for each dataset size.

For paper-grade reporting (repeated runs + statistics), use the runner:

```bash
dart run benchmark/paper_benchmark.dart \
  --presets=social,delivery,notes_rag \
  --sizes=20000,100000 \
  --warmup-runs=1 \
  --repeat=5
```

It writes:

- `benchmark/results/<timestamp>/results.json`
- `benchmark/results/<timestamp>/summary.csv`
- `benchmark/results/<timestamp>/REPORT.md`
