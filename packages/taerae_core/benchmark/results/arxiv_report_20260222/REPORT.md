# Taerae Paper Benchmark Report

## Run Metadata

- Started (UTC): 2026-02-22T10:53:39.581221Z
- Finished (UTC): 2026-02-22T10:53:45.671430Z
- Duration: 6.09s
- Dart: Dart SDK version: 3.11.0 (stable) (Mon Feb 9 00:38:07 2026 -0800) on "macos_arm64"
- Platform: macos (Version 15.7.4 (Build 24G517))
- CPU logical cores: 10

## Config

- Presets: generic, notes_rag
- Sizes: 5000
- Warmup runs: 1
- Measured runs: 2
- Base seed: 42

## Artifacts

- JSON: `benchmark/results/arxiv_report_20260222/results.json`
- CSV: `benchmark/results/arxiv_report_20260222/summary.csv`

## Summary (mean ops/s)

| Preset | Nodes | Metric | Mean ops/s | p50 ops/s | p95 ops/s |
| --- | ---: | --- | ---: | ---: | ---: |
| generic | 5000 | nodeById | 2538283 | 2538283 | 2559156 |
| generic | 5000 | nodesByLabel | 63647 | 63647 | 64066 |
| generic | 5000 | nodesWhereProperty | 1341225 | 1341225 | 1361618 |
| generic | 5000 | outgoing | 1982344 | 1982344 | 2012750 |
| generic | 5000 | shortestPathBfs | 1249 | 1249 | 1257 |
| generic | 5000 | upsertEdge | 1055513 | 1055513 | 1061930 |
| generic | 5000 | upsertNode | 117343 | 117343 | 119977 |
| notes_rag | 5000 | neighbors(RELATED) | 785275 | 785275 | 831036 |
| notes_rag | 5000 | nodeById | 1801344 | 1801344 | 1881458 |
| notes_rag | 5000 | nodesByLabel | 10753 | 10753 | 10945 |
| notes_rag | 5000 | nodesWhereProperty | 273532 | 273532 | 276716 |
| notes_rag | 5000 | outgoing(RELATED) | 2248437 | 2248437 | 2346485 |
| notes_rag | 5000 | shortestPath(RELATED) | 1539 | 1539 | 1580 |
| notes_rag | 5000 | upsertEdge | 986199 | 986199 | 988362 |
| notes_rag | 5000 | upsertNode | 165988 | 165988 | 167961 |
| notes_rag | 5000 | urgentFilter | 95206 | 95206 | 95760 |
