# Taerae Examples

This folder contains runnable example projects for different Taerae use-cases.

## Projects

- `basic_graph_queries`: in-memory graph modeling and path querying.
- `persistent_graph_store`: append-only log + snapshot persistence workflow.
- `graphrag_playground`: GraphRAG-style retrieval using custom embeddings.
- `real_life_city_commute`: real-life city commute/place relationship scenario.
- `real_life_delivery_ops`: delivery operation and package-tracking scenario.
- `real_life_personal_notes_rag`: personal notes search with GraphRAG filters/reranker.
- `real_life_social_recommendation`: social graph recommendation scenario.

## Run an Example

```bash
cd examples/basic_graph_queries
dart pub get
dart run
```

Replace `basic_graph_queries` with another project folder to run it.
