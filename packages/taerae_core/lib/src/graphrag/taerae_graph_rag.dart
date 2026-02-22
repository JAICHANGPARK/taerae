import 'dart:collection';

import '../taerae_graph.dart';
import '../taerae_node.dart';
import 'taerae_text_embedder.dart';
import 'taerae_vector_index.dart';

const String _chunkIdDelimiter = '::chunk::';

/// Text chunking strategy for GraphRAG indexing.
abstract interface class TaeraeTextChunker {
  /// Splits [text] into chunks.
  List<String> split(String text);
}

/// Fixed-size character chunker.
class TaeraeFixedSizeTextChunker implements TaeraeTextChunker {
  /// Creates a chunker with [maxChunkLength] characters per chunk.
  const TaeraeFixedSizeTextChunker({this.maxChunkLength = 280});

  /// Maximum characters per chunk.
  final int maxChunkLength;

  @override
  List<String> split(String text) {
    if (maxChunkLength <= 0) {
      throw ArgumentError.value(
        maxChunkLength,
        'maxChunkLength',
        'Must be > 0.',
      );
    }

    final String normalized = text.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    if (normalized.length <= maxChunkLength) {
      return <String>[normalized];
    }

    final List<String> chunks = <String>[];
    int start = 0;
    while (start < normalized.length) {
      final int end = (start + maxChunkLength < normalized.length)
          ? start + maxChunkLength
          : normalized.length;
      chunks.add(normalized.substring(start, end));
      start = end;
    }
    return chunks;
  }
}

/// Optional node-level filter for GraphRAG retrieval.
class TaeraeGraphRagFilter {
  /// Creates a retrieval filter.
  const TaeraeGraphRagFilter({
    this.requiredLabels,
    this.requiredProperties = const <String, Object?>{},
  });

  /// Node must include all labels when provided.
  final Set<String>? requiredLabels;

  /// Node properties must exactly match all key/value pairs.
  final Map<String, Object?> requiredProperties;

  /// Returns `true` if [node] satisfies this filter.
  bool matches(TaeraeNode node) {
    if (requiredLabels != null && !node.labels.containsAll(requiredLabels!)) {
      return false;
    }

    for (final MapEntry<String, Object?> entry in requiredProperties.entries) {
      if (node.properties[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }
}

/// Hook interface for re-ranking retrieval hits.
abstract interface class TaeraeGraphReranker {
  /// Re-orders or rescored [hits] for [query].
  Future<List<TaeraeGraphRagHit>> rerank(
    String query,
    List<TaeraeGraphRagHit> hits,
  );
}

/// Retrieval result with graph context.
class TaeraeGraphRagHit {
  /// Creates a GraphRAG hit.
  const TaeraeGraphRagHit({
    required this.node,
    required this.score,
    required this.neighborhood,
  });

  /// Matched node.
  final TaeraeNode node;

  /// Vector similarity score.
  final double score;

  /// Neighboring context nodes collected around [node].
  final List<TaeraeNode> neighborhood;

  /// Returns a copy with updated fields.
  TaeraeGraphRagHit copyWith({
    TaeraeNode? node,
    double? score,
    List<TaeraeNode>? neighborhood,
  }) {
    return TaeraeGraphRagHit(
      node: node ?? this.node,
      score: score ?? this.score,
      neighborhood: neighborhood ?? this.neighborhood,
    );
  }
}

/// Lightweight GraphRAG helper built on [TaeraeGraph].
class TaeraeGraphRag {
  /// Creates a GraphRAG helper with external embedding/index components.
  TaeraeGraphRag({
    required this.graph,
    required this.embedder,
    required this.vectorIndex,
    TaeraeTextChunker? chunker,
    this.defaultReranker,
  }) : chunker = chunker ?? const TaeraeFixedSizeTextChunker();

  /// Graph source for node lookup and neighborhood expansion.
  final TaeraeGraph graph;

  /// Text embedding provider.
  final TaeraeTextEmbedder embedder;

  /// Vector index implementation.
  final TaeraeVectorIndex vectorIndex;

  /// Chunking strategy for indexed text.
  final TaeraeTextChunker chunker;

  /// Optional reranker used when `retrieve` does not provide one.
  final TaeraeGraphReranker? defaultReranker;

  final Map<String, String> _chunkToNodeId = <String, String>{};
  final Map<String, Set<String>> _chunkIdsByNodeId = <String, Set<String>>{};

  /// Indexes [text] for [nodeId] using chunk embeddings when needed.
  Future<void> indexNodeText(String nodeId, String text) async {
    if (!graph.containsNode(nodeId)) {
      throw StateError('Cannot index node "$nodeId": node does not exist.');
    }

    await removeNodeFromIndex(nodeId);

    final List<String> chunks = chunker
        .split(text)
        .map((String chunk) => chunk.trim())
        .where((String chunk) => chunk.isNotEmpty)
        .toList(growable: false);

    if (chunks.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Text must not be empty.');
    }

    if (chunks.length == 1) {
      final List<double> embedding = await embedder.embed(chunks.single);
      await vectorIndex.upsert(nodeId, embedding);
      return;
    }

    final Set<String> chunkIds = <String>{};
    for (int index = 0; index < chunks.length; index++) {
      final String chunkId = '$nodeId$_chunkIdDelimiter$index';
      final List<double> embedding = await embedder.embed(chunks[index]);
      await vectorIndex.upsert(chunkId, embedding);
      _chunkToNodeId[chunkId] = nodeId;
      chunkIds.add(chunkId);
    }
    _chunkIdsByNodeId[nodeId] = chunkIds;
  }

  /// Removes vector index entries for [nodeId], including chunk entries.
  Future<void> removeNodeFromIndex(String nodeId) async {
    await vectorIndex.remove(nodeId);
    final Set<String>? chunkIds = _chunkIdsByNodeId.remove(nodeId);
    if (chunkIds == null) {
      return;
    }

    for (final String chunkId in chunkIds) {
      await vectorIndex.remove(chunkId);
      _chunkToNodeId.remove(chunkId);
    }
  }

  /// Retrieves graph-aware results from [query].
  Future<List<TaeraeGraphRagHit>> retrieve(
    String query, {
    int topK = 5,
    int neighborhoodHops = 1,
    String? edgeType,
    TaeraeGraphRagFilter? filter,
    TaeraeGraphReranker? reranker,
  }) async {
    if (neighborhoodHops < 0) {
      throw ArgumentError.value(
        neighborhoodHops,
        'neighborhoodHops',
        'Must be >= 0.',
      );
    }
    if (topK <= 0) {
      return const <TaeraeGraphRagHit>[];
    }

    final List<double> queryEmbedding = await embedder.embed(query);
    final List<TaeraeScoredNode> scored = await vectorIndex.search(
      queryEmbedding,
      topK: topK * 4,
    );

    final Map<String, double> bestScoreByNode = <String, double>{};
    for (final TaeraeScoredNode scoreItem in scored) {
      final String nodeId = _resolveNodeId(scoreItem.nodeId);
      final double? existing = bestScoreByNode[nodeId];
      if (existing == null || scoreItem.score > existing) {
        bestScoreByNode[nodeId] = scoreItem.score;
      }
    }

    final List<MapEntry<String, double>> sortedEntries =
        bestScoreByNode.entries.toList(growable: true)
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) {
            final int scoreCompare = b.value.compareTo(a.value);
            if (scoreCompare != 0) {
              return scoreCompare;
            }
            return a.key.compareTo(b.key);
          });

    final List<TaeraeGraphRagHit> hits = <TaeraeGraphRagHit>[];
    for (final MapEntry<String, double> entry in sortedEntries) {
      final TaeraeNode? node = graph.nodeById(entry.key);
      if (node == null) {
        continue;
      }
      if (filter != null && !filter.matches(node)) {
        continue;
      }

      hits.add(
        TaeraeGraphRagHit(
          node: node,
          score: entry.value,
          neighborhood: _collectNeighborhood(
            node.id,
            hops: neighborhoodHops,
            edgeType: edgeType,
          ),
        ),
      );

      if (hits.length == topK) {
        break;
      }
    }

    final TaeraeGraphReranker? selectedReranker = reranker ?? defaultReranker;
    if (selectedReranker == null) {
      return List<TaeraeGraphRagHit>.unmodifiable(hits);
    }

    final List<TaeraeGraphRagHit> reranked = await selectedReranker.rerank(
      query,
      List<TaeraeGraphRagHit>.unmodifiable(hits),
    );
    return List<TaeraeGraphRagHit>.unmodifiable(reranked.take(topK));
  }

  List<TaeraeNode> _collectNeighborhood(
    String centerNodeId, {
    required int hops,
    String? edgeType,
  }) {
    if (hops == 0 || !graph.containsNode(centerNodeId)) {
      return const <TaeraeNode>[];
    }

    final Queue<_HopNode> queue = Queue<_HopNode>()
      ..add(_HopNode(centerNodeId, 0));
    final Set<String> visited = <String>{centerNodeId};
    final LinkedHashSet<String> neighborIds = LinkedHashSet<String>();

    while (queue.isNotEmpty) {
      final _HopNode current = queue.removeFirst();
      if (current.depth >= hops) {
        continue;
      }

      for (final TaeraeNode neighbor in graph.neighbors(
        current.nodeId,
        type: edgeType,
        bothDirections: true,
      )) {
        if (!visited.add(neighbor.id)) {
          continue;
        }
        neighborIds.add(neighbor.id);
        queue.add(_HopNode(neighbor.id, current.depth + 1));
      }
    }

    final List<TaeraeNode> result = <TaeraeNode>[];
    for (final String id in neighborIds) {
      final TaeraeNode? node = graph.nodeById(id);
      if (node != null) {
        result.add(node);
      }
    }
    return List<TaeraeNode>.unmodifiable(result);
  }

  String _resolveNodeId(String indexedId) {
    final String? mapped = _chunkToNodeId[indexedId];
    if (mapped != null) {
      return mapped;
    }

    final int delimiterIndex = indexedId.indexOf(_chunkIdDelimiter);
    if (delimiterIndex > 0) {
      return indexedId.substring(0, delimiterIndex);
    }
    return indexedId;
  }
}

class _HopNode {
  const _HopNode(this.nodeId, this.depth);

  final String nodeId;
  final int depth;
}
