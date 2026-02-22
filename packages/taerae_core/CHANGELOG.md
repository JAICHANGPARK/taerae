## 0.1.2

- Add tolerant replay mode for crash-truncated trailing log lines in
  `TaeraeGraphLog.replayInto(...)` while keeping strict replay available.
- Update `TaeraePersistentGraph.open(...)` to enable tolerant trailing-line
  recovery by default with an explicit strict-mode toggle.
- Add `TaeraePersistentGraph.close(...)` and `isClosed`, and reject mutating
  persistence calls after close with `StateError`.
- Add persistence regression tests for truncated-log recovery modes and close
  lifecycle behavior.

## 0.1.1

- Optimize `TaeraeGraphLog` replay/read paths to stream NDJSON operations.
- Add broad branch and validation tests for graph core, persistence, and GraphRAG.
- Raise `lib/` statement coverage to 100% with additional regression coverage.

## 0.1.0

- Introduced immutable graph models: `TaeraeNode` and `TaeraeEdge`.
- Added `TaeraeGraph` in-memory engine with node/edge upsert and remove APIs.
- Added indexed queries for labels, properties, and edge traversal.
- Added BFS shortest path search with optional edge type filtering.
- Added graph utility APIs: `copy`, `clear`, `toJson`, and `fromJson`.
- Replaced template tests with comprehensive graph behavior tests.
- Added file persistence primitives:
  `TaeraeGraphLog`, `TaeraeGraphSnapshotStore`, and `TaeraePersistentGraph`.
- Added durability controls for persistent graph:
  log flush policy, write atomicity policy, and atomic snapshot write.
- Added GraphRAG extension interfaces:
  `TaeraeTextEmbedder`, `TaeraeVectorIndex`, and `TaeraeGraphRag`.
- Added GraphRAG enhancements:
  text chunking, metadata filtering, and custom reranker hook.
