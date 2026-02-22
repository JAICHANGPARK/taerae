# persistent_graph_store

Demonstrates file-backed graph persistence:

- append-only mutation log (`graph.log.ndjson`)
- compact snapshot (`graph.snapshot.json`)
- restart recovery by replaying snapshot + log

## Run

```bash
dart pub get
dart run
```
