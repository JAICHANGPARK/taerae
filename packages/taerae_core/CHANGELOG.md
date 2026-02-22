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
