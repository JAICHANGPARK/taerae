# taerae_core Developer Guide

This guide is for engineers integrating `taerae_core` into production code.
It focuses on API behavior, safe usage patterns, and operational trade-offs.

## Contents

1. [Core concepts](#1-core-concepts-node-edge-graph)
2. [CRUD patterns and gotchas](#2-crud-patterns-and-gotchas)
3. [Query, traversal, and path APIs](#3-query-traversal-and-path-apis)
4. [JSON serialization and import/export](#4-json-serialization-and-importexport)
5. [Persistence workflow with `TaeraePersistentGraph`](#5-persistence-workflow-with-taeraepersistentgraph)
6. [Recovery and checkpoint strategy](#6-recovery-and-checkpoint-strategy)
7. [GraphRAG workflow](#7-graphrag-workflow-embedder-index-chunker-filter-reranker)
8. [Error handling and defensive coding](#8-error-handling-and-defensive-coding)
9. [Performance tips and anti-patterns](#9-performance-tips-and-anti-patterns)
10. [Testing patterns](#10-testing-patterns)

## 1) Core concepts (node, edge, graph)

`taerae_core` is centered on three immutable model types and one mutable engine.

- `TaeraeNode`: immutable node with `id`, `labels`, and `properties`.
- `TaeraeEdge`: immutable directed edge with `id`, `from`, `to`, optional `type`, and `properties`.
- `TaeraeGraph`: mutable in-memory graph that stores nodes and edges and maintains indexes.

### Node and edge are immutable value objects

```dart
import 'package:taerae_core/taerae_core.dart';

void main() {
  final TaeraeNode node = TaeraeNode(
    id: 'alice',
    labels: const <String>['Person'],
    properties: const <String, Object?>{
      'name': 'Alice',
      'skills': <Object?>['Dart', 'Graphs'],
    },
  );

  // Throws UnsupportedError because model collections are frozen.
  // node.labels.add('Engineer');
  // node.properties['name'] = 'Other';
}
```

Practical implication:

- Treat `TaeraeNode` and `TaeraeEdge` as snapshots.
- Update by creating a new value (`copyWith`) or using graph upsert APIs.

### The graph is directed and indexed

```dart
import 'package:taerae_core/taerae_core.dart';

void main() {
  final TaeraeGraph graph = TaeraeGraph()
    ..upsertNode('alice', labels: const <String>['Person'])
    ..upsertNode('bob', labels: const <String>['Person'])
    ..upsertEdge('e1', 'alice', 'bob', type: 'KNOWS');

  print(graph.outgoing('alice').single.to); // bob
  print(graph.incoming('bob').single.from); // alice
}
```

The graph maintains internal indexes for:

- adjacency (`outgoing`, `incoming`, `neighbors`)
- label lookup (`nodesByLabel`)
- exact property lookup (`nodesWhereProperty`)

## 2) CRUD patterns and gotchas

### Create and update nodes with upsert semantics

```dart
final TaeraeGraph graph = TaeraeGraph();

graph.upsertNode(
  'u1',
  labels: const <String>['User'],
  properties: const <String, Object?>{'name': 'Ada', 'level': 1},
);

// Omitted fields are retained for existing nodes.
graph.upsertNode('u1', properties: const <String, Object?>{'level': 2});

final TaeraeNode node = graph.nodeById('u1')!;
print(node.labels); // {User}
print(node.properties); // {level: 2}
```

Gotcha:

- If you omit `labels` or `properties`, existing values are preserved.
- To clear values, pass an explicit empty collection.

```dart
graph.upsertNode(
  'u1',
  labels: const <String>[],
  properties: const <String, Object?>{},
);
```

### Create and update edges with endpoint validation

```dart
final TaeraeGraph graph = TaeraeGraph()
  ..upsertNode('u1')
  ..upsertNode('u2')
  ..upsertNode('u3')
  ..upsertEdge('f1', 'u1', 'u2', type: 'FOLLOWS');

// Move existing edge to another endpoint.
// Omitted type/properties are retained.
graph.upsertEdge('f1', 'u1', 'u3');
```

Gotchas:

- `upsertEdge` throws `StateError` when `from` or `to` node is missing.
- Changing edge endpoints reindexes adjacency automatically.

### Remove operations

```dart
final TaeraeGraph graph = TaeraeGraph()
  ..upsertNode('a')
  ..upsertNode('b')
  ..upsertNode('c')
  ..upsertEdge('e1', 'a', 'b')
  ..upsertEdge('e2', 'c', 'a');

final bool removedNode = graph.removeNode('a');
print(removedNode); // true
print(graph.containsEdge('e1')); // false (incident edge removed)
print(graph.containsEdge('e2')); // false (incident edge removed)
```

Behavior summary:

- `removeNode` deletes the node and all incident edges.
- `removeEdge` deletes only that edge.
- Both return `false` when target does not exist.

### Recommended CRUD wrapper for safer service code

```dart
TaeraeEdge? safeUpsertEdge(
  TaeraeGraph graph,
  String id,
  String from,
  String to,
) {
  if (!graph.containsNode(from) || !graph.containsNode(to)) {
    return null;
  }

  try {
    return graph.upsertEdge(id, from, to);
  } on StateError {
    return null;
  }
}
```

## 3) Query, traversal, and path APIs

### Direct lookup APIs

```dart
final TaeraeNode? node = graph.nodeById('alice');
final TaeraeEdge? edge = graph.edgeById('e1');
final bool hasNode = graph.containsNode('alice');
final bool hasEdge = graph.containsEdge('e1');
```

### Edge traversal APIs

```dart
final List<TaeraeEdge> out = graph.outgoing('alice');
final List<TaeraeEdge> knowsOnly = graph.outgoing('alice', type: 'KNOWS');
final List<TaeraeEdge> incoming = graph.incoming('bob');
```

### Neighbor APIs

```dart
final List<TaeraeNode> bothWays = graph.neighbors('alice');
final List<TaeraeNode> outgoingOnly = graph.neighbors(
  'alice',
  bothDirections: false,
);
final List<TaeraeNode> typed = graph.neighbors('alice', type: 'KNOWS');
```

Important detail:

- `neighbors` returns unique nodes in encounter order.
- Missing node id returns an empty list, not an exception.

### Indexed search APIs

```dart
final List<TaeraeNode> people = graph.nodesByLabel('Person');

final List<TaeraeNode> teamA = graph.nodesWhereProperty('team', 'A');

final List<TaeraeNode> nestedMatch = graph.nodesWhereProperty(
  'meta',
  const <String, Object?>{'tier': 1},
);
```

Property matching details:

- Matching is exact by key and value.
- Nested lists/maps are compared structurally.
- Partial map matching is not supported.

### Shortest path API (directed BFS)

```dart
final List<String>? path = graph.shortestPathBfs('A', 'C');
final List<String>? roadPath = graph.shortestPathBfs(
  'A',
  'C',
  edgeType: 'road',
);
```

Path semantics:

- Traversal follows outgoing edges only.
- Returns `null` when either node is missing or unreachable.
- Returns `[startId]` when start and end are equal.

## 4) JSON serialization and import/export

All core models expose `toJson` and `fromJson`.

- `TaeraeNode.toJson()` / `TaeraeNode.fromJson(...)`
- `TaeraeEdge.toJson()` / `TaeraeEdge.fromJson(...)`
- `TaeraeGraph.toJson()` / `TaeraeGraph.fromJson(...)`

### Export a graph to disk

```dart
import 'dart:convert';
import 'dart:io';

Future<void> exportGraph(TaeraeGraph graph, File file) async {
  final String payload = jsonEncode(graph.toJson());
  await file.writeAsString(payload, flush: true);
}
```

### Import a graph from disk (defensive parsing)

```dart
import 'dart:convert';
import 'dart:io';

Future<TaeraeGraph> importGraph(File file) async {
  final String payload = await file.readAsString();
  final Object? decoded = jsonDecode(payload);

  if (decoded is! Map<Object?, Object?>) {
    throw const FormatException('Expected top-level JSON object.');
  }

  final Map<String, Object?> json = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in decoded.entries) {
    if (entry.key is! String || (entry.key as String).isEmpty) {
      throw const FormatException('JSON object keys must be non-empty strings.');
    }
    json[entry.key as String] = entry.value;
  }

  return TaeraeGraph.fromJson(json);
}
```

### Import/export with persistent graph

```dart
import 'dart:convert';
import 'dart:io';

Future<void> exportPersistent(TaeraePersistentGraph persistent, File file) async {
  await file.writeAsString(jsonEncode(persistent.toJson()), flush: true);
}

Future<void> importPersistent(
  TaeraePersistentGraph persistent,
  File file,
) async {
  final Object? decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<Object?, Object?>) {
    throw const FormatException('Expected top-level JSON object.');
  }

  final Map<String, Object?> json = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in decoded.entries) {
    if (entry.key is! String || (entry.key as String).isEmpty) {
      throw const FormatException('JSON object keys must be non-empty strings.');
    }
    json[entry.key as String] = entry.value;
  }

  await persistent.restoreFromJson(json);
}
```

`restoreFromJson` replaces current state and checkpoints immediately.

## 5) Persistence workflow with `TaeraePersistentGraph`

`TaeraePersistentGraph` combines:

- an in-memory `TaeraeGraph`
- append-only NDJSON mutation log (`TaeraeGraphLog`)
- snapshot file store (`TaeraeGraphSnapshotStore`)

### Full end-to-end workflow

```dart
import 'dart:io';

import 'package:taerae_core/taerae_core.dart';

Future<void> main() async {
  final Directory storeDir = Directory('./taerae_store');

  final TaeraePersistentGraph persistent = await TaeraePersistentGraph.open(
    directory: storeDir,
    autoCheckpointEvery: 200,
    durability: const TaeraeDurabilityOptions(
      logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
      flushEveryNOperations: 8,
      writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
      atomicSnapshotWrite: true,
    ),
  );

  await persistent.upsertNode(
    'alice',
    labels: const <String>['Person'],
    properties: const <String, Object?>{'name': 'Alice'},
  );
  await persistent.upsertNode('seoul', labels: const <String>['City']);
  await persistent.upsertEdge('e1', 'alice', 'seoul', type: 'LIVES_IN');

  final List<String>? path = persistent.shortestPathBfs('alice', 'seoul');
  print(path); // [alice, seoul]

  // Explicit checkpoint for deterministic compaction boundaries.
  await persistent.checkpoint();

  print('Snapshot: ${persistent.snapshotPath}');
  print('Log: ${persistent.logPath}');
}
```

Operational notes:

- `open` creates directory and files if they do not exist.
- On startup, it reads snapshot then replays all log operations.
- `checkpoint` flushes log, writes snapshot, truncates log.
- There is no explicit `close` API. For shutdown safety, call `checkpoint`.

### Durability option reference

| Option | Values | Effect |
| --- | --- | --- |
| `logFlushPolicy` | `immediate`, `everyNOperations`, `onCheckpoint` | Controls append flush frequency. |
| `flushEveryNOperations` | `int > 0` when using `everyNOperations` | Batching size for flush. |
| `writeAtomicityPolicy` | `writeAhead`, `inMemoryFirst` | Chooses WAL-before-memory or memory-before-WAL ordering. |
| `atomicSnapshotWrite` | `true` / `false` | `true` uses temp-file rename for safer snapshot commits. |

### Durability trade-offs

- `writeAhead + immediate`: strongest crash consistency, slower writes.
- `writeAhead + everyNOperations`: balanced default for many apps.
- `onCheckpoint`: fastest steady-state writes, highest crash window.
- `inMemoryFirst`: can expose post-crash data loss for recent operations.

## 6) Recovery and checkpoint strategy

### How recovery works

`TaeraePersistentGraph.open(...)` performs this sequence:

1. Read snapshot (`graph.snapshot.json`) or start empty.
2. Replay log (`graph.log.ndjson`) in order.
3. Build ready-to-use in-memory graph.

This means recent operations survive restart as long as they are present in log.

### Recommended checkpoint triggers

Use both policy and event triggers:

- Keep `autoCheckpointEvery` enabled for continuous compaction.
- Call `checkpoint()` before app shutdown.
- Call `checkpoint()` before backup/export operations.
- Call `checkpoint()` after bulk imports.

### Recommended settings profiles

#### Profile A: safety-first (critical local data)

```dart
const TaeraeDurabilityOptions durability = TaeraeDurabilityOptions(
  logFlushPolicy: TaeraeLogFlushPolicy.immediate,
  writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
  atomicSnapshotWrite: true,
);
```

Recommended with:

- `autoCheckpointEvery`: `100` to `300` depending on write volume.

#### Profile B: balanced default

```dart
const TaeraeDurabilityOptions durability = TaeraeDurabilityOptions(
  logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
  flushEveryNOperations: 8,
  writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
  atomicSnapshotWrite: true,
);
```

Recommended with:

- `autoCheckpointEvery`: `200` to `1000`.

#### Profile C: throughput-first (rebuildable data)

```dart
const TaeraeDurabilityOptions durability = TaeraeDurabilityOptions(
  logFlushPolicy: TaeraeLogFlushPolicy.onCheckpoint,
  writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.inMemoryFirst,
  atomicSnapshotWrite: false,
);
```

Recommended only when:

- data can be regenerated
- some loss on crash is acceptable

### Recovery fallback example for corrupted log input

```dart
import 'dart:io';

import 'package:taerae_core/taerae_core.dart';

Future<TaeraePersistentGraph> openWithRecovery(Directory directory) async {
  try {
    return await TaeraePersistentGraph.open(
      directory: directory,
      autoCheckpointEvery: 200,
      durability: const TaeraeDurabilityOptions(
        logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
        flushEveryNOperations: 8,
        writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
        atomicSnapshotWrite: true,
      ),
    );
  } on FormatException {
    final File logFile = File(
      directory.uri.resolve('graph.log.ndjson').toFilePath(),
    );

    if (await logFile.exists()) {
      final String backupName =
          'graph.log.ndjson.corrupt.${DateTime.now().toUtc().millisecondsSinceEpoch}';
      await logFile.rename(directory.uri.resolve(backupName).toFilePath());
    }

    final TaeraeGraphSnapshotStore snapshotStore = TaeraeGraphSnapshotStore(
      File(directory.uri.resolve('graph.snapshot.json').toFilePath()),
    );
    final TaeraeGraph snapshotGraph = await snapshotStore.readOrEmpty();

    final TaeraePersistentGraph recovered = await TaeraePersistentGraph.open(
      directory: directory,
      autoCheckpointEvery: 200,
    );

    await recovered.restoreFromJson(snapshotGraph.toJson());
    return recovered;
  }
}
```

This preserves the last valid snapshot and isolates unreadable log data.

## 7) GraphRAG workflow (embedder, index, chunker, filter, reranker)

`TaeraeGraphRag` composes five extension points:

- `TaeraeTextEmbedder`: converts text to vectors.
- `TaeraeVectorIndex`: stores vectors and performs similarity search.
- `TaeraeTextChunker`: splits long text before indexing.
- `TaeraeGraphRagFilter`: applies label/property constraints.
- `TaeraeGraphReranker`: optional final ranking stage.

### Step 1: model your graph data

```dart
final TaeraeGraph graph = TaeraeGraph()
  ..upsertNode(
    'doc-1',
    labels: const <String>['Document'],
    properties: const <String, Object?>{
      'topic': 'databases',
      'lang': 'en',
      'text': 'Graph persistence and checkpoint strategy for mobile apps.',
    },
  )
  ..upsertNode('tag-ops', labels: const <String>['Tag'])
  ..upsertEdge('r1', 'doc-1', 'tag-ops', type: 'TAGGED_AS');
```

### Step 2: provide embedder, chunker, and reranker

```dart
import 'dart:math' as math;

import 'package:taerae_core/taerae_core.dart';

class DemoEmbedder implements TaeraeTextEmbedder {
  @override
  Future<List<double>> embed(String text) async {
    final String normalized = text.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Text must not be empty.');
    }

    double a = 0;
    double b = 0;
    for (final int unit in normalized.codeUnits) {
      a += unit;
      b += unit.isEven ? 1 : -1;
    }

    return <double>[a / math.max(1, normalized.length), b];
  }
}

class ParagraphChunker implements TaeraeTextChunker {
  const ParagraphChunker();

  @override
  List<String> split(String text) {
    return text
        .split('\n\n')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }
}

class ScoreBoostReranker implements TaeraeGraphReranker {
  const ScoreBoostReranker();

  @override
  Future<List<TaeraeGraphRagHit>> rerank(
    String query,
    List<TaeraeGraphRagHit> hits,
  ) async {
    final List<TaeraeGraphRagHit> sorted = hits.toList(growable: true)
      ..sort((TaeraeGraphRagHit a, TaeraeGraphRagHit b) {
        final bool aIsDoc = a.node.labels.contains('Document');
        final bool bIsDoc = b.node.labels.contains('Document');
        if (aIsDoc != bIsDoc) {
          return aIsDoc ? -1 : 1;
        }
        return b.score.compareTo(a.score);
      });
    return List<TaeraeGraphRagHit>.unmodifiable(sorted);
  }
}
```

### Step 3: build and index

```dart
final TaeraeGraphRag rag = TaeraeGraphRag(
  graph: graph,
  embedder: DemoEmbedder(),
  vectorIndex: TaeraeInMemoryVectorIndex(),
  chunker: const ParagraphChunker(),
  defaultReranker: const ScoreBoostReranker(),
);

await rag.indexNodeText(
  'doc-1',
  graph.nodeById('doc-1')!.properties['text'] as String,
);
```

### Step 4: retrieve with filters and neighborhood context

```dart
final List<TaeraeGraphRagHit> hits = await rag.retrieve(
  'durable graph checkpointing',
  topK: 5,
  neighborhoodHops: 1,
  edgeType: 'TAGGED_AS',
  filter: const TaeraeGraphRagFilter(
    requiredLabels: <String>{'Document'},
    requiredProperties: <String, Object?>{'lang': 'en'},
  ),
);

for (final TaeraeGraphRagHit hit in hits) {
  print('${hit.node.id}: ${hit.score}');
  print('Neighbors: ${hit.neighborhood.map((n) => n.id).toList()}');
}
```

### Step 5: keep vector index in sync with graph lifecycle

```dart
Future<void> deleteDocument(
  TaeraeGraph graph,
  TaeraeGraphRag rag,
  String nodeId,
) async {
  await rag.removeNodeFromIndex(nodeId);
  graph.removeNode(nodeId);
}
```

GraphRAG gotchas:

- `indexNodeText` throws `StateError` if node does not exist.
- Empty text after chunking throws `ArgumentError`.
- `TaeraeInMemoryVectorIndex` requires consistent vector dimensions.
- `retrieve` returns empty list when `topK <= 0`.
- `retrieve` throws `ArgumentError` when `neighborhoodHops < 0`.

## 8) Error handling and defensive coding

### Common exception surfaces

| Exception | Typical source | Suggested handling |
| --- | --- | --- |
| `ArgumentError` | empty ids, invalid durability configuration, invalid chunk settings | Validate inputs early and fail fast. |
| `StateError` | missing edge endpoints, missing GraphRAG node/index invariants, embedding dimension mismatch | Guard preconditions and log operational context. |
| `FormatException` | malformed JSON, snapshot, or NDJSON log data | Treat as data-corruption signal and trigger recovery flow. |
| `UnsupportedError` | mutating frozen node/edge collections | Copy values before mutation. |

### Defensive wrapper for import path

```dart
import 'dart:convert';

Future<TaeraeGraph?> tryImportGraph(String payload) async {
  try {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! Map<Object?, Object?>) {
      return null;
    }

    final Map<String, Object?> json = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in decoded.entries) {
      if (entry.key is! String || (entry.key as String).isEmpty) {
        return null;
      }
      json[entry.key as String] = entry.value;
    }

    return TaeraeGraph.fromJson(json);
  } on FormatException {
    return null;
  }
}
```

### Defensive wrapper for persistent mutation

```dart
Future<bool> tryLinkUsers(
  TaeraePersistentGraph persistent,
  String edgeId,
  String from,
  String to,
) async {
  final TaeraeGraph snapshot = persistent.graph;
  if (!snapshot.containsNode(from) || !snapshot.containsNode(to)) {
    return false;
  }

  try {
    await persistent.upsertEdge(edgeId, from, to, type: 'KNOWS');
    return true;
  } on StateError {
    return false;
  }
}
```

Important:

- `persistent.graph` returns a defensive copy.
- Do not treat it as a live mutable reference.

## 9) Performance tips and anti-patterns

### Do this

- Use indexed lookups (`nodesByLabel`, `nodesWhereProperty`) before custom scans.
- Batch persistence writes with `everyNOperations` when immediate flush is unnecessary.
- Keep `atomicSnapshotWrite` enabled for production durability.
- Run explicit `checkpoint()` after bulk imports to compact logs.
- Keep GraphRAG `topK` and `neighborhoodHops` bounded.
- Reuse embedder and index instances across requests.

### Avoid this

- Calling `persistent.graph` in tight loops.
- Setting `onCheckpoint` flush policy for crash-sensitive user data.
- Using very small chunk sizes that explode vector index entries.
- Storing highly volatile data in node properties when frequent reindex is expected.
- Running broad GraphRAG retrieval (`topK` high + large `neighborhoodHops`) on hot paths.

### Hot path checklist

- Are you using `writeAhead` for important mutations?
- Is `flushEveryNOperations` tuned to storage latency?
- Is checkpoint cadence preventing unbounded log growth?
- Are embedding dimensions stable across model changes?

## 10) Testing patterns

### 1. Core invariants and CRUD behavior

```dart
import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  test('removeNode cascades incident edges', () {
    final TaeraeGraph graph = TaeraeGraph()
      ..upsertNode('a')
      ..upsertNode('b')
      ..upsertEdge('e1', 'a', 'b');

    expect(graph.removeNode('a'), isTrue);
    expect(graph.containsEdge('e1'), isFalse);
  });
}
```

### 2. JSON round-trip tests

```dart
test('graph JSON round-trip preserves structure', () {
  final TaeraeGraph original = TaeraeGraph()
    ..upsertNode('n1', labels: const <String>['Person'])
    ..upsertNode('n2')
    ..upsertEdge('e1', 'n1', 'n2', type: 'KNOWS');

  final TaeraeGraph restored = TaeraeGraph.fromJson(original.toJson());
  expect(restored.toJson(), equals(original.toJson()));
});
```

### 3. Persistence integration tests with temporary directories

```dart
import 'dart:io';

import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

test('persistent graph recovers from snapshot + log replay', () async {
  final Directory dir = await Directory.systemTemp.createTemp('taerae-');
  addTearDown(() => dir.delete(recursive: true));

  final TaeraePersistentGraph first = await TaeraePersistentGraph.open(
    directory: dir,
    autoCheckpointEvery: 0,
  );
  await first.upsertNode('a');
  await first.upsertNode('b');
  await first.upsertEdge('e1', 'a', 'b');

  final TaeraePersistentGraph reopened = await TaeraePersistentGraph.open(
    directory: dir,
    autoCheckpointEvery: 0,
  );

  expect(reopened.shortestPathBfs('a', 'b'), equals(const <String>['a', 'b']));
});
```

### 4. Durability policy tests

```dart
test('everyNOperations requires flushEveryNOperations > 0', () async {
  final Directory dir = await Directory.systemTemp.createTemp('taerae-');
  addTearDown(() => dir.delete(recursive: true));

  expect(
    () => TaeraePersistentGraph.open(
      directory: dir,
      durability: const TaeraeDurabilityOptions(
        logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
        flushEveryNOperations: 0,
      ),
    ),
    throwsArgumentError,
  );
});
```

### 5. GraphRAG tests with deterministic fake embedder

```dart
class FakeEmbedder implements TaeraeTextEmbedder {
  FakeEmbedder(this.vectors);

  final Map<String, List<double>> vectors;

  @override
  Future<List<double>> embed(String text) async {
    final List<double>? vector = vectors[text];
    if (vector == null) {
      throw StateError('Missing vector for "$text".');
    }
    return vector;
  }
}
```

Testing guidance:

- Keep embeddings deterministic for stable assertions.
- Assert both hit ordering and neighborhood contents.
- Add cases for filters, chunking, and reranker hooks.

## Additional API notes

- `TaeraeGraph.copy()` returns an independent graph instance.
- `TaeraeGraph.clear()` removes all nodes, edges, and indexes.
- `TaeraePersistentGraph.restoreFromJson(...)` performs an immediate checkpoint.
- `TaeraeGraphSnapshotStore.readOrEmpty()` accepts both snapshot envelope and raw graph JSON for backward compatibility.

Use this guide with `README.md` for quick onboarding and keep operational defaults explicit in your app code.
