/// In-memory graph primitives, GraphRAG helpers, and persistence utilities.
///
/// This library provides [TaeraeGraph] for graph mutations and traversal,
/// immutable graph entities such as [TaeraeNode] and [TaeraeEdge], GraphRAG
/// components such as [TaeraeGraphRag], and file-backed durability through
/// [TaeraePersistentGraph].
///
/// ```dart
/// final graph = TaeraeGraph();
/// graph.upsertNode('u1', labels: <String>{'User'});
/// graph.upsertNode('u2', labels: <String>{'User'});
/// graph.upsertEdge('f1', 'u1', 'u2', type: 'follows');
///
/// final path = graph.shortestPathBfs('u1', 'u2');
/// ```
library;

export 'src/taerae_edge.dart';
export 'src/taerae_graph.dart';
export 'src/taerae_node.dart';
export 'src/graphrag/taerae_graph_rag.dart';
export 'src/graphrag/taerae_text_embedder.dart';
export 'src/graphrag/taerae_vector_index.dart';
export 'src/persistence/taerae_graph_log.dart';
export 'src/persistence/taerae_graph_operation.dart';
export 'src/persistence/taerae_graph_snapshot.dart';
export 'src/persistence/taerae_persistent_graph.dart';
