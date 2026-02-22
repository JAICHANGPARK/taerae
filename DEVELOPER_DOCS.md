# Taerae Developer Docs

This is the entry point for detailed usage documentation.

## Core Package (`taerae_core`)

- Overview and quick start:
  - `packages/taerae_core/README.md`
- Detailed developer guide:
  - `packages/taerae_core/DEVELOPER_GUIDE.md`

Topics covered in the core guide:
- graph data model and CRUD behavior
- traversal/path APIs and query semantics
- JSON import/export patterns
- persistence (`TaeraePersistentGraph`) and durability tuning
- recovery/checkpoint strategy
- GraphRAG integration (embedder/index/chunker/filter/reranker)
- performance and testing patterns

## Flutter Package (`taerae_flutter`)

- Overview and quick start:
  - `packages/taerae_flutter/README.md`
- Detailed developer guide:
  - `packages/taerae_flutter/DEVELOPER_GUIDE.md`
- API inventory:
  - `packages/taerae_flutter/API_REFERENCE.md`

Topics covered in the Flutter guide:
- architecture and package layering
- installation (pub.dev + local monorepo)
- `TaeraeGraphController` lifecycle and UI patterns
- CRUD/traversal/path/import-export flows in Flutter
- error handling and async safety
- persistence service pattern for Flutter apps
- GraphRAG integration in app services
- testing and production checklist

## Runnable Examples

- Example index:
  - `examples/README.md`

Real-life scenario examples:
- `examples/real_life_city_commute`
- `examples/real_life_delivery_ops`
- `examples/real_life_personal_notes_rag`
- `examples/real_life_social_recommendation`
