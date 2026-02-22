# Taerae

`Taerae` is an embedded, lightweight graph database project for Dart and Flutter.
It is designed to run without an external GraphDB server (for example, no Neo4j dependency),
so apps can model and query graph relations fully on-device.

Build graph-powered apps in Dart/Flutter without running a graph server.  
Use local-first graph queries with durability controls for real app data.  
Extend naturally into on-device AI and GraphRAG workflows.

[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.11-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.3-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Analyze](https://github.com/taerae-dev/taerae/actions/workflows/analyze.yml/badge.svg)](https://github.com/taerae-dev/taerae/actions/workflows/analyze.yml)
[![Test](https://github.com/taerae-dev/taerae/actions/workflows/test.yml/badge.svg)](https://github.com/taerae-dev/taerae/actions/workflows/test.yml)
[![Runtime](https://img.shields.io/badge/GraphDB-Embedded%20%2F%20Local--First-1f6feb)](#why-taerae)
[![AI](https://img.shields.io/badge/GraphRAG-Ready-0a7f5a)](packages/taerae_core/README.md)

## Get Started

- Build with pure Dart core: [`packages/taerae_core`](packages/taerae_core)
- Build Flutter apps: [`packages/taerae_flutter`](packages/taerae_flutter)
- Run practical examples: [`examples`](examples)
- Dive into full docs: [`DEVELOPER_DOCS.md`](DEVELOPER_DOCS.md)

## Why Taerae

Taerae is optimized for app-embedded graph workloads, not server-cluster workloads.

| Perspective | Typical server GraphDB usage | Taerae |
| --- | --- | --- |
| Infrastructure | Separate DB server and operations | In-app embedded graph runtime |
| Connectivity | Usually network-dependent | Local-first, offline-capable |
| Flutter UX | Custom adapter required | `TaeraeGraphController` ready for UI state |
| AI extension | External wiring required | Built-in GraphRAG extension points |
| Operational cost | DB hosting and maintenance overhead | Lower infra/ops burden for app-local use cases |

### Awesome Points

- `No Neo4j required`: run graph features without external GraphDB infrastructure.
- `Import and use`: single Dart/Flutter stack for graph modeling and querying.
- `Offline-ready`: graph queries keep working without network dependency.
- `Flutter-native DX`: `ChangeNotifier`-based controller for immediate UI integration.
- `GraphRAG ready`: embedder/index/chunker/filter/reranker hooks included.
- `Durability control`: WAL + snapshot with configurable flush/atomicity strategy.
- `Prototype-to-product`: consistent API from local prototype to production app features.

## Packages

- `packages/taerae_core`: pure Dart graph engine and query core.
- `packages/taerae_flutter`: Flutter plugin/package that wraps `taerae_core` with Flutter-friendly APIs.
- `examples/`: standalone example projects for common usage patterns.

## Documentation

- Detailed docs index: `DEVELOPER_DOCS.md`
- Core guide: `packages/taerae_core/DEVELOPER_GUIDE.md`
- Flutter guide: `packages/taerae_flutter/DEVELOPER_GUIDE.md`
- Flutter API reference: `packages/taerae_flutter/API_REFERENCE.md`

## Vision

- Local-first graph modeling for mobile, desktop, and web.
- Expand toward on-device AI workflows and GraphRAG pipelines.
- Keep the core lightweight so it can run in resource-constrained environments.

## Local Development

```bash
cd packages/taerae_core
dart test

cd ../taerae_flutter
flutter test
```

## Examples

```bash
cd examples/basic_graph_queries
dart pub get
dart run
```

See `examples/README.md` for all sample projects.
Real-life scenario samples include:
- `examples/real_life_city_commute`
- `examples/real_life_delivery_ops`
- `examples/real_life_personal_notes_rag`
- `examples/real_life_social_recommendation`

## Pub.dev Publishing Plan

1. Publish `taerae_core` first.
2. Update `taerae_flutter` dependency from local path to the published `taerae_core` version.
3. Publish `taerae_flutter`.
