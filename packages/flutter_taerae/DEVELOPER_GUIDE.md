# flutter_taerae Developer Guide

This guide explains how to use `flutter_taerae` in production Flutter apps.
It focuses on `TaeraeGraphController` usage patterns and how to integrate re-exported `taerae_core` features (persistence and GraphRAG).

## Table of Contents

1. [Package purpose and architecture](#1-package-purpose-and-architecture)
2. [Installation](#2-installation)
3. [TaeraeGraphController lifecycle in Flutter widgets](#3-taeraegraphcontroller-lifecycle-in-flutter-widgets)
4. [UI flow: CRUD, traversal, path, import/export](#4-ui-flow-crud-traversal-path-importexport)
5. [State management patterns](#5-state-management-patterns)
6. [Error handling and safe async usage](#6-error-handling-and-safe-async-usage)
7. [Persistence integration pattern](#7-persistence-integration-pattern)
8. [GraphRAG from Flutter with custom embedder/index](#8-graphrag-from-flutter-with-custom-embedderindex)
9. [Testing patterns](#9-testing-patterns)
10. [Production checklist](#10-production-checklist)

## 1. Package purpose and architecture

`flutter_taerae` is the Flutter-facing package for the Taerae graph stack.

With one import:

```dart
import 'package:flutter_taerae/flutter_taerae.dart';
```

You get:

- Flutter plugin API:
  - `TaeraeFlutter.getPlatformVersion()` for platform channel smoke tests.
- Flutter state adapter:
  - `TaeraeGraphController` (`ChangeNotifier`) for UI-friendly graph reads/writes.
- Re-exported `taerae_core` APIs:
  - Graph model/engine (`TaeraeGraph`, `TaeraeNode`, `TaeraeEdge`)
  - Persistence (`TaeraePersistentGraph`, durability options, log/snapshot classes)
  - GraphRAG (`TaeraeGraphRag`, `TaeraeTextEmbedder`, `TaeraeVectorIndex`, etc.)

Architecture in typical app code:

```text
Flutter Widgets
  -> TaeraeGraphController (ChangeNotifier)
    -> TaeraeGraph (in-memory graph operations)
      -> Optional: TaeraePersistentGraph (disk durability)
      -> Optional: TaeraeGraphRag (retrieval over graph nodes)
```

Important controller behavior:

- Mutation APIs (`upsertNode`, `removeNode`, `upsertEdge`, `removeEdge`, `clear`, `replaceGraph`) call `notifyListeners()`.
- Query APIs are synchronous.
- `graph` returns a defensive copy (`_graph.copy()`), so callers cannot mutate controller internals accidentally.

## 2. Installation

### 2.1 From pub.dev

In your Flutter app `pubspec.yaml`:

```yaml
dependencies:
  flutter_taerae: ^0.1.0
```

Then run:

```bash
flutter pub get
```

### 2.2 Local monorepo override

If your app is in the same monorepo and you want local package changes immediately:

```yaml
dependencies:
  flutter_taerae:
    path: ../packages/flutter_taerae

dependency_overrides:
  taerae_core:
    path: ../packages/taerae_core
```

If `flutter_taerae` is already path-based and its own `pubspec_overrides.yaml` resolves `taerae_core`, you can keep only the `flutter_taerae` path dependency in your app.
Adjust relative paths to your app directory.

## 3. TaeraeGraphController lifecycle in Flutter widgets

`TaeraeGraphController` should be treated like any long-lived `ChangeNotifier`.

Recommended rules:

- Create once per widget lifecycle, not inside `build`.
- Dispose in `dispose()`.
- If parent input changes should replace graph data, handle it explicitly in `didUpdateWidget`.

Example:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphScreen extends StatefulWidget {
  const GraphScreen({
    super.key,
    required this.initialGraphJson,
  });

  final Map<String, Object?> initialGraphJson;

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late final TaeraeGraphController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TaeraeGraphController.fromJson(widget.initialGraphJson);
  }

  @override
  void didUpdateWidget(covariant GraphScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Replace state only when parent supplies a different payload.
    if (!identical(oldWidget.initialGraphJson, widget.initialGraphJson)) {
      _controller.importFromJson(widget.initialGraphJson);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Text('Node count: ${_controller.nodes.length}');
      },
    );
  }
}
```

## 4. UI flow: CRUD, traversal, path, import/export

The controller API is designed for direct event-handler usage.

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphEditorCard extends StatefulWidget {
  const GraphEditorCard({super.key});

  @override
  State<GraphEditorCard> createState() => _GraphEditorCardState();
}

class _GraphEditorCardState extends State<GraphEditorCard> {
  final TaeraeGraphController _controller = TaeraeGraphController();
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _controller
      ..upsertNode(
        'alice',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'Alice'},
      )
      ..upsertNode(
        'bob',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'Bob'},
      );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addCityAndEdge() {
    try {
      _controller.upsertNode(
        'seoul',
        labels: const <String>['City'],
        properties: const <String, Object?>{'country': 'KR'},
      );
      _controller.upsertEdge(
        'alice_lives_in_seoul',
        'alice',
        'seoul',
        type: 'LIVES_IN',
      );
      setState(() => _status = 'Added city + edge');
    } on StateError catch (error) {
      setState(() => _status = 'Edge creation failed: $error');
    }
  }

  void _removeBob() {
    final bool removed = _controller.removeNode('bob');
    setState(() => _status = removed ? 'Removed bob' : 'bob not found');
  }

  void _runTraversalQueries() {
    final List<TaeraeNode> people = _controller.nodesByLabel('Person');
    final List<TaeraeNode> neighbors = _controller.neighbors('alice');
    final List<String>? path = _controller.shortestPathBfs('alice', 'seoul');

    setState(() {
      _status = [
        'people=${people.map((TaeraeNode n) => n.id).join(',')}',
        'neighbors(alice)=${neighbors.map((TaeraeNode n) => n.id).join(',')}',
        'path(alice->seoul)=${path?.join(' -> ') ?? 'unreachable'}',
      ].join(' | ');
    });
  }

  void _exportPrettyJson() {
    final String jsonText = _controller.exportToJsonString(pretty: true);
    setState(() => _status = jsonText);
  }

  void _importSeedJson() {
    const String seedJson = '''
{
  "nodes": [
    {"id": "doc1", "labels": ["Document"], "properties": {"title": "Spec"}},
    {"id": "tag1", "labels": ["Tag"], "properties": {"name": "flutter"}}
  ],
  "edges": [
    {"id": "e1", "from": "doc1", "to": "tag1", "type": "HAS_TAG", "properties": {}}
  ]
}
''';

    try {
      _controller.importFromJsonString(seedJson);
      setState(() => _status = 'Imported seed graph');
    } on FormatException catch (error) {
      setState(() => _status = 'Import failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final String compact = jsonEncode(_controller.exportToJson());

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton(
                      onPressed: _addCityAndEdge,
                      child: const Text('Create / Upsert'),
                    ),
                    FilledButton(
                      onPressed: _removeBob,
                      child: const Text('Delete'),
                    ),
                    FilledButton(
                      onPressed: _runTraversalQueries,
                      child: const Text('Traverse / Path'),
                    ),
                    FilledButton(
                      onPressed: _exportPrettyJson,
                      child: const Text('Export JSON'),
                    ),
                    FilledButton(
                      onPressed: _importSeedJson,
                      child: const Text('Import JSON'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Nodes: ${_controller.nodes.length}'),
                Text('Edges: ${_controller.edges.length}'),
                const SizedBox(height: 8),
                Text('Status: $_status'),
                const SizedBox(height: 8),
                Text('Snapshot: $compact'),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

## 5. State management patterns

### 5.1 Baseline: `AnimatedBuilder` with controller as `Listenable`

Use when the whole widget subtree can rebuild from controller state:

```dart
AnimatedBuilder(
  animation: controller,
  builder: (BuildContext context, Widget? child) {
    return Text('Edges: ${controller.edges.length}');
  },
)
```

### 5.2 `ValueListenable` bridge for derived state

Use when one small computed value should update independently.

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class PersonCountBridge {
  PersonCountBridge(this.controller)
    : personCount = ValueNotifier<int>(0) {
    _listener = () {
      personCount.value = controller.nodesByLabel('Person').length;
    };
    controller.addListener(_listener);
    _listener();
  }

  final TaeraeGraphController controller;
  final ValueNotifier<int> personCount;
  late final VoidCallback _listener;

  void dispose() {
    controller.removeListener(_listener);
    personCount.dispose();
  }
}
```

And in UI:

```dart
ValueListenableBuilder<int>(
  valueListenable: bridge.personCount,
  builder: (BuildContext context, int value, Widget? child) {
    return Text('People: $value');
  },
)
```

### 5.3 Provider guidance (`provider` package)

Use Provider when controller ownership should be handled at app/module scope.
Add `provider` to your app dependencies first.

```yaml
dependencies:
  provider: ^6.1.0
```

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphScope extends StatelessWidget {
  const GraphScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TaeraeGraphController>(
      create: (_) => TaeraeGraphController(),
      child: child,
    );
  }
}

class NodeCountText extends StatelessWidget {
  const NodeCountText({super.key});

  @override
  Widget build(BuildContext context) {
    final int nodeCount = context.select<TaeraeGraphController, int>(
      (TaeraeGraphController c) => c.nodes.length,
    );
    return Text('Nodes: $nodeCount');
  }
}
```

Guidance:

- Use `context.select` to reduce rebuild scope.
- If controller is created elsewhere, provide it with `ChangeNotifierProvider.value`.
- Do not create controller instances inside `build` methods.

## 6. Error handling and safe async usage

Common error sources:

- `StateError`
  - `upsertEdge` when `from`/`to` node ids are missing.
  - GraphRAG index/retrieval operations when graph/index assumptions are violated.
- `FormatException`
  - `importFromJson` / `importFromJsonString` with invalid payload shape.
- `PlatformException`
  - Plugin platform channel calls (`getPlatformVersion`) can fail on device/runtime issues.
- `ArgumentError`
  - Invalid GraphRAG chunker/index/embedder inputs (empty text, invalid dimensions, etc.).

Safe async pattern inside widgets:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphImportButton extends StatefulWidget {
  const GraphImportButton({super.key, required this.controller});

  final TaeraeGraphController controller;

  @override
  State<GraphImportButton> createState() => _GraphImportButtonState();
}

class _GraphImportButtonState extends State<GraphImportButton> {
  bool _busy = false;
  String _message = '';

  Future<void> _importFromFile() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = 'Importing...';
    });

    try {
      final File file = File('/path/to/graph.json');
      final String source = await file.readAsString();
      if (!mounted) return;

      widget.controller.importFromJsonString(source);

      if (!mounted) return;
      setState(() => _message = 'Import completed');
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() => _message = 'File error: $error');
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Invalid graph JSON: $error');
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        FilledButton(
          onPressed: _busy ? null : _importFromFile,
          child: const Text('Import graph'),
        ),
        Text(_message),
      ],
    );
  }
}
```

## 7. Persistence integration pattern

`TaeraePersistentGraph` is re-exported from `taerae_core` and is the recommended durable storage layer for mobile/desktop/server Dart environments.

Note:

- `TaeraePersistentGraph` depends on `dart:io`; it is not for Flutter Web.
- The example uses `path_provider` to choose an app-scoped directory.

```yaml
dependencies:
  path_provider: ^2.1.0
```

Pattern: keep persistence as source of truth, mirror state to UI controller.

```dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphPersistenceService {
  GraphPersistenceService(this.controller);

  final TaeraeGraphController controller;
  TaeraePersistentGraph? _persistent;

  Future<void> open() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory graphDir = Directory('${appDir.path}/graph_store');

    _persistent = await TaeraePersistentGraph.open(
      directory: graphDir,
      autoCheckpointEvery: 200,
      durability: const TaeraeDurabilityOptions(
        logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
        flushEveryNOperations: 8,
        writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
        atomicSnapshotWrite: true,
      ),
    );

    // Hydrate UI from durable graph.
    controller.replaceGraph(_persistent!.graph);
  }

  Future<void> upsertNode(
    String id, {
    Iterable<String>? labels,
    Map<String, Object?>? properties,
  }) async {
    final TaeraePersistentGraph store = _requireStore();
    await store.upsertNode(id, labels: labels, properties: properties);
    controller.replaceGraph(store.graph);
  }

  Future<void> upsertEdge(
    String id,
    String from,
    String to, {
    String? type,
    Map<String, Object?>? properties,
  }) async {
    final TaeraePersistentGraph store = _requireStore();
    await store.upsertEdge(id, from, to, type: type, properties: properties);
    controller.replaceGraph(store.graph);
  }

  Future<void> removeNode(String id) async {
    final TaeraePersistentGraph store = _requireStore();
    await store.removeNode(id);
    controller.replaceGraph(store.graph);
  }

  Future<void> checkpoint() async {
    await _requireStore().checkpoint();
  }

  TaeraePersistentGraph _requireStore() {
    final TaeraePersistentGraph? store = _persistent;
    if (store == null) {
      throw StateError('GraphPersistenceService.open() must be called first.');
    }
    return store;
  }
}
```

This approach avoids split-brain state because all writes pass through persistence first, then controller is refreshed.

## 8. GraphRAG from Flutter with custom embedder/index

`TaeraeGraphRag` is also re-exported and can be composed in Flutter services.

### 8.1 Custom embedder and index wrapper

```dart
import 'package:flutter_taerae/flutter_taerae.dart';

class CharacterHashEmbedder implements TaeraeTextEmbedder {
  CharacterHashEmbedder({required this.dimension});

  final int dimension;

  @override
  Future<List<double>> embed(String text) async {
    final String normalized = text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Must not be empty.');
    }

    final List<double> vector = List<double>.filled(dimension, 0);
    for (final int unit in normalized.codeUnits) {
      vector[unit % dimension] += 1;
    }
    return vector;
  }
}

class DimensionCheckedIndex implements TaeraeVectorIndex {
  DimensionCheckedIndex({required this.dimension, TaeraeVectorIndex? delegate})
    : _delegate = delegate ?? TaeraeInMemoryVectorIndex();

  final int dimension;
  final TaeraeVectorIndex _delegate;

  @override
  Future<void> upsert(String nodeId, List<double> embedding) async {
    _assertDimension(embedding, 'embedding');
    await _delegate.upsert(nodeId, embedding);
  }

  @override
  Future<void> remove(String nodeId) {
    return _delegate.remove(nodeId);
  }

  @override
  Future<List<TaeraeScoredNode>> search(
    List<double> queryEmbedding, {
    int topK = 5,
  }) {
    _assertDimension(queryEmbedding, 'queryEmbedding');
    return _delegate.search(queryEmbedding, topK: topK);
  }

  @override
  Future<void> clear() {
    return _delegate.clear();
  }

  void _assertDimension(List<double> vector, String fieldName) {
    if (vector.length != dimension) {
      throw ArgumentError.value(
        vector,
        fieldName,
        'Expected $dimension dimensions but got ${vector.length}.',
      );
    }
  }
}
```

### 8.2 Service integration with controller graph snapshots

```dart
import 'package:flutter_taerae/flutter_taerae.dart';

class GraphRagService {
  GraphRagService({required TaeraeGraphController controller})
    : _controller = controller,
      _embedder = CharacterHashEmbedder(dimension: 16),
      _index = DimensionCheckedIndex(dimension: 16);

  final TaeraeGraphController _controller;
  final TaeraeTextEmbedder _embedder;
  final TaeraeVectorIndex _index;

  TaeraeGraphRag _buildRag() {
    return TaeraeGraphRag(
      graph: _controller.graph,
      embedder: _embedder,
      vectorIndex: _index,
      chunker: const TaeraeFixedSizeTextChunker(maxChunkLength: 240),
    );
  }

  Future<void> indexNodeText(String nodeId, String text) async {
    await _buildRag().indexNodeText(nodeId, text);
  }

  Future<List<TaeraeGraphRagHit>> searchDocuments(String query) async {
    return _buildRag().retrieve(
      query,
      topK: 5,
      neighborhoodHops: 2,
      filter: const TaeraeGraphRagFilter(
        requiredLabels: <String>{'Document'},
      ),
    );
  }

  Future<void> clearIndex() => _index.clear();
}
```

Operational guidance:

- Index nodes after they exist in the graph.
- Re-index when indexed text changes.
- If you use multi-chunk indexing heavily and need chunk-level removal, keep a long-lived `TaeraeGraphRag` instance with a stable graph source rather than rebuilding each call.

## 9. Testing patterns

### 9.1 Controller unit tests

Focus on mutation notifications, graph correctness, and import/export behavior.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

void main() {
  test('controller notifies listeners on mutation', () {
    final TaeraeGraphController controller = TaeraeGraphController();
    int notifyCount = 0;
    controller.addListener(() => notifyCount += 1);

    controller.upsertNode('n1', labels: const <String>['Person']);
    controller.upsertNode('n2', labels: const <String>['Person']);
    controller.upsertEdge('e1', 'n1', 'n2', type: 'KNOWS');

    expect(notifyCount, 3);
    expect(controller.shortestPathBfs('n1', 'n2'), <String>['n1', 'n2']);
  });

  test('controller import/export round-trip', () {
    final TaeraeGraphController source = TaeraeGraphController()
      ..upsertNode('alice', labels: const <String>['Person'])
      ..upsertNode('seoul', labels: const <String>['City'])
      ..upsertEdge('e1', 'alice', 'seoul', type: 'LIVES_IN');

    final TaeraeGraphController restored = TaeraeGraphController()
      ..importFromJsonString(source.exportToJsonString());

    expect(restored.containsNode('alice'), isTrue);
    expect(restored.edgeById('e1')?.type, 'LIVES_IN');
  });
}
```

Also include negative tests:

- `upsertEdge` without existing nodes should throw `StateError`.
- `importFromJsonString` invalid payload should throw `FormatException`.

### 9.2 Platform channel tests

Use mock method call handlers to isolate plugin behavior:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_taerae/flutter_taerae_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('flutter_taerae');
  final MethodChannelTaeraeFlutter plugin = MethodChannelTaeraeFlutter();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      if (methodCall.method == 'getPlatformVersion') {
        return 'test-version';
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion delegates to method channel', () async {
    expect(await plugin.getPlatformVersion(), 'test-version');
  });
}
```

### 9.3 Widget tests

For UI layers, prefer pumping widgets that read `TaeraeGraphController` through `AnimatedBuilder` or Provider, then mutate controller and assert rendered text updates.

## 10. Production checklist

Use this before shipping:

- Controller lifecycle:
  - `TaeraeGraphController` is not recreated in `build`.
  - Controller is disposed exactly once.
- Mutation safety:
  - Edge writes are guarded so `from` and `to` nodes exist.
  - Import payloads are validated and wrapped in `FormatException` handling.
- Async safety:
  - All async UI handlers check `mounted` before `setState`.
  - Re-entrancy is prevented for long-running import/sync actions.
- State management:
  - `AnimatedBuilder`, Provider selectors, or `ValueListenableBuilder` are used to constrain rebuild scope.
- Persistence (if enabled):
  - Writes go through one source of truth (`TaeraePersistentGraph` service).
  - Checkpoint strategy (`autoCheckpointEvery`, durability policy) is explicitly chosen.
  - Storage directory is app-scoped and survives app restarts.
- GraphRAG (if enabled):
  - Embedding dimension is consistent between embedder and index.
  - Re-indexing strategy exists for node text changes/removals.
  - Retrieval filters/rerankers are validated in tests.
- Platform plugin:
  - Method channel smoke test exists in CI (`getPlatformVersion`).
- Testing:
  - Unit tests cover CRUD + path + import/export + error cases.
  - Widget tests verify expected rebuild behavior.
- Observability:
  - Import/persistence/GraphRAG failures are logged with actionable messages.
