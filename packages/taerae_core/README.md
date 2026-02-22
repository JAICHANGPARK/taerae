# taerae_core

`taerae_core` is an embedded graph database core for Dart.
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
import 'package:taerae_core/taerae_core.dart';

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
