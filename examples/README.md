# Taerae Examples

This folder contains runnable example projects for different Taerae use-cases.

## Project Index

| Project | Scenario |
| --- | --- |
| `basic_graph_queries` | In-memory graph modeling and path querying |
| `persistent_graph_store` | Append-only log + snapshot persistence workflow |
| `graphrag_playground` | GraphRAG-style retrieval with custom embeddings |
| `real_life_city_commute` | City commute/place relationship modeling |
| `real_life_delivery_ops` | Delivery operations and package tracking |
| `real_life_personal_notes_rag` | Personal notes search with GraphRAG filters/reranker |
| `real_life_social_recommendation` | Social graph recommendation scenario |

## Run Any Example

```bash
cd examples/<project_name>
dart pub get
dart run
```

## Quick Commands

```bash
cd examples/basic_graph_queries && dart pub get && dart run
cd examples/persistent_graph_store && dart pub get && dart run
cd examples/graphrag_playground && dart pub get && dart run
cd examples/real_life_city_commute && dart pub get && dart run
cd examples/real_life_delivery_ops && dart pub get && dart run
cd examples/real_life_personal_notes_rag && dart pub get && dart run
cd examples/real_life_social_recommendation && dart pub get && dart run
```
