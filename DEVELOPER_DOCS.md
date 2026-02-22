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

## Flutter Package (`flutter_taerae`)

- Overview and quick start:
  - `packages/flutter_taerae/README.md`
- Detailed developer guide:
  - `packages/flutter_taerae/DEVELOPER_GUIDE.md`
- API inventory:
  - `packages/flutter_taerae/API_REFERENCE.md`

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

## Standard Checks and Learning Resources

Run the standard monorepo checks from repository root:

```bash
./scripts/dev-checks.sh
```

Fast iteration mode:

```bash
./scripts/dev-checks.sh --skip-examples
```

Equivalent package-level commands:

```bash
cd packages/taerae_core
dart analyze
dart test

cd ../flutter_taerae
flutter analyze
flutter test
```

Primary docs for learning and runnable flows:
- Core package:
  - `packages/taerae_core/README.md`
  - `packages/taerae_core/DEVELOPER_GUIDE.md`
- Flutter package:
  - `packages/flutter_taerae/README.md`
  - `packages/flutter_taerae/DEVELOPER_GUIDE.md`
  - `packages/flutter_taerae/API_REFERENCE.md`
- Examples:
  - `examples/README.md`
