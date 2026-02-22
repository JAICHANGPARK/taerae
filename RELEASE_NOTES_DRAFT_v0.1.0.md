# Taerae Release Notes Draft v0.1.0

Status: Draft  
Target release: v0.1.0  
Date: 2026-02-22

## 1. Summary

`Taerae v0.1.0` is the first public milestone of an embedded, local-first GraphDB stack for Dart and Flutter.
It introduces:

- core graph engine APIs (`taerae_core`)
- file durability with append-only log + snapshot
- Flutter-friendly controller API (`flutter_taerae`)
- GraphRAG extension interfaces
- runnable real-world examples

## 1.1 Positioning and differentiators

- No external GraphDB infrastructure required for core usage.
- Local-first runtime designed for offline-capable app scenarios.
- Flutter-native integration via `TaeraeGraphController`.
- Built-in durability options (WAL + snapshot + policy controls).
- GraphRAG-ready extension points without locking into one model/index vendor.

### Awesome points for user messaging

- `No Neo4j required`
- `Import and use in Dart/Flutter`
- `Offline graph queries`
- `Flutter-native graph state management`
- `GraphRAG-ready architecture`

## 2. Package: `taerae_core`

### Added

- Immutable graph models:
  - `TaeraeNode`
  - `TaeraeEdge`
- In-memory graph engine:
  - `TaeraeGraph`
- Core graph operations:
  - node/edge upsert and remove
  - label/property indexed queries
  - traversal APIs (`outgoing`, `incoming`, `neighbors`)
  - shortest-path BFS (`shortestPathBfs`)
- JSON APIs:
  - `toJson` / `fromJson`
  - graph copy/clear helpers

### Persistence

- `TaeraeGraphLog` (append-only NDJSON mutation log)
- `TaeraeGraphSnapshotStore` (snapshot save/load)
- `TaeraePersistentGraph` (integrated persistent graph workflow)
- Durability controls:
  - `TaeraeDurabilityOptions`
  - `TaeraeLogFlushPolicy`
  - `TaeraeWriteAtomicityPolicy`
  - atomic snapshot write option

### GraphRAG base + advanced hooks

- `TaeraeTextEmbedder`
- `TaeraeVectorIndex`
- `TaeraeInMemoryVectorIndex`
- `TaeraeGraphRag`
- `TaeraeTextChunker` and `TaeraeFixedSizeTextChunker`
- `TaeraeGraphRagFilter`
- `TaeraeGraphReranker`
- `TaeraeGraphRagHit`

## 3. Package: `flutter_taerae`

### Added

- Flutter state adapter:
  - `TaeraeGraphController extends ChangeNotifier`
- Controller capabilities:
  - CRUD
  - traversal/path query
  - JSON import/export
  - listener notifications on mutation
- Platform channel smoke API:
  - `TaeraeFlutter.getPlatformVersion()`
- Re-export of `taerae_core` APIs for unified import experience

## 4. Documentation

Added/updated documentation set:

- `DEVELOPER_DOCS.md` (root docs index)
- `PRD_BACKUP_2026-02-22.md`
- `packages/taerae_core/DEVELOPER_GUIDE.md`
- `packages/flutter_taerae/DEVELOPER_GUIDE.md`
- `packages/flutter_taerae/API_REFERENCE.md`
- `examples/README.md`

## 5. Examples

### Base examples
- `examples/basic_graph_queries`
- `examples/persistent_graph_store`
- `examples/graphrag_playground`

### Real-life scenario examples
- `examples/real_life_city_commute`
- `examples/real_life_delivery_ops`
- `examples/real_life_personal_notes_rag`
- `examples/real_life_social_recommendation`

## 6. Verification Status

- `taerae_core`
  - `dart analyze` passed
  - `dart test` passed
- `flutter_taerae`
  - `flutter analyze` passed
  - `flutter test` passed
- examples
  - major examples executed via `dart run`

## 7. Breaking Changes

- None (first public release draft).

## 8. Known Limitations (v0.1.0)

- No distributed clustering/replication/sharding.
- No Cypher-compatible query language.
- Persistence APIs rely on `dart:io` (not for Flutter Web runtime).
- In-memory vector index is baseline implementation (no ANN optimization).

## 9. Publish Plan

1. Publish `taerae_core` first.
2. Update `flutter_taerae` core dependency to published version.
3. Publish `flutter_taerae`.

## 10. Suggested Upgrade/Adoption Notes

- New adopters:
  - start from `examples/basic_graph_queries` and `packages/taerae_core/DEVELOPER_GUIDE.md`
- Flutter adopters:
  - start from `packages/flutter_taerae/DEVELOPER_GUIDE.md`
  - wire persistence as a single source-of-truth service
- GraphRAG adopters:
  - begin with deterministic embedder/index setup, then swap in production components
