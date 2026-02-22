# taerae_flutter API Reference

Import once to access both Flutter-layer APIs and re-exported `taerae_core` APIs:

```dart
import 'package:taerae_flutter/taerae_flutter.dart';
```

## 1) Flutter package APIs

### `class TaeraeFlutter`

Platform-channel smoke test API.

- `Future<String?> getPlatformVersion()`

### `class TaeraeGraphController extends ChangeNotifier`

Flutter state-friendly graph controller.

#### Constructors

- `TaeraeGraphController({TaeraeGraph? graph})`
- `factory TaeraeGraphController.fromJson(Map<String, Object?> json)`

#### Query APIs

- `TaeraeGraph get graph`
- `List<TaeraeNode> get nodes`
- `List<TaeraeEdge> get edges`
- `bool containsNode(String id)`
- `bool containsEdge(String id)`
- `TaeraeNode? nodeById(String id)`
- `TaeraeEdge? edgeById(String id)`
- `List<TaeraeEdge> outgoing(String nodeId, {String? type})`
- `List<TaeraeEdge> incoming(String nodeId, {String? type})`
- `List<TaeraeNode> neighbors(String nodeId, {String? type, bool bothDirections = true})`
- `List<TaeraeNode> nodesByLabel(String label)`
- `List<TaeraeNode> nodesWhereProperty(String key, Object? value)`
- `List<String>? shortestPathBfs(String startId, String endId, {String? edgeType})`

#### Mutation APIs (auto `notifyListeners()`)

- `TaeraeNode upsertNode(String id, {Iterable<String>? labels, Map<String, Object?>? properties})`
- `bool removeNode(String id)`
- `TaeraeEdge upsertEdge(String id, String from, String to, {String? type, Map<String, Object?>? properties})`
- `bool removeEdge(String id)`
- `void clear()`
- `void replaceGraph(TaeraeGraph graph)`

#### JSON import/export APIs

- `Map<String, Object?> exportToJson()`
- `String exportToJsonString({bool pretty = false})`
- `void importFromJson(Map<String, Object?> json)`
- `void importFromJsonString(String source)`

## 2) Re-exported `taerae_core` APIs

### Graph model and engine

- `TaeraeNode`
- `TaeraeEdge`
- `TaeraeGraph`

### Persistence

- `TaeraePersistentGraph`
- `TaeraeDurabilityOptions`
- `TaeraeLogFlushPolicy`
- `TaeraeWriteAtomicityPolicy`
- `TaeraeGraphLog`
- `TaeraeGraphOperation`
- `TaeraeGraphSnapshotStore`

### GraphRAG

- `TaeraeTextEmbedder`
- `TaeraeVectorIndex`
- `TaeraeInMemoryVectorIndex`
- `TaeraeScoredNode`
- `TaeraeTextChunker`
- `TaeraeFixedSizeTextChunker`
- `TaeraeGraphRagFilter`
- `TaeraeGraphReranker`
- `TaeraeGraphRagHit`
- `TaeraeGraphRag`

## Related docs

- Quick start: [`README.md`](README.md)
- Detailed usage guide: [`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md)
- Core package details: [`../taerae_core/README.md`](../taerae_core/README.md)
