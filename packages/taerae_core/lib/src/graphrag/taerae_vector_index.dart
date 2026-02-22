import 'dart:collection';
import 'dart:math' as math;

/// Search result item for vector similarity lookup.
class TaeraeScoredNode {
  /// Creates a scored node hit.
  const TaeraeScoredNode({required this.nodeId, required this.score});

  /// Node identifier.
  final String nodeId;

  /// Similarity score (higher is better).
  final double score;
}

/// Interface for node-vector indexing used by GraphRAG retrieval.
abstract interface class TaeraeVectorIndex {
  /// Upserts a vector for [nodeId].
  Future<void> upsert(String nodeId, List<double> embedding);

  /// Removes vector data for [nodeId].
  Future<void> remove(String nodeId);

  /// Searches for similar nodes given [queryEmbedding].
  Future<List<TaeraeScoredNode>> search(
    List<double> queryEmbedding, {
    int topK = 5,
  });

  /// Clears all indexed vectors.
  Future<void> clear();
}

/// In-memory cosine-similarity vector index.
class TaeraeInMemoryVectorIndex implements TaeraeVectorIndex {
  final Map<String, List<double>> _embeddings = <String, List<double>>{};

  @override
  Future<void> upsert(String nodeId, List<double> embedding) async {
    if (nodeId.trim().isEmpty) {
      throw ArgumentError.value(nodeId, 'nodeId', 'Must not be empty.');
    }
    _validateEmbedding(embedding, 'embedding');
    _embeddings[nodeId] = List<double>.unmodifiable(embedding);
  }

  @override
  Future<void> remove(String nodeId) async {
    _embeddings.remove(nodeId);
  }

  @override
  Future<List<TaeraeScoredNode>> search(
    List<double> queryEmbedding, {
    int topK = 5,
  }) async {
    if (topK <= 0 || _embeddings.isEmpty) {
      return const <TaeraeScoredNode>[];
    }
    _validateEmbedding(queryEmbedding, 'queryEmbedding');

    final List<TaeraeScoredNode> scored = <TaeraeScoredNode>[];

    for (final MapEntry<String, List<double>> entry in _embeddings.entries) {
      final List<double> currentEmbedding = entry.value;
      if (currentEmbedding.length != queryEmbedding.length) {
        throw StateError(
          'Embedding dimension mismatch for node "${entry.key}". '
          'Expected ${queryEmbedding.length} but got ${currentEmbedding.length}.',
        );
      }

      scored.add(
        TaeraeScoredNode(
          nodeId: entry.key,
          score: _cosineSimilarity(queryEmbedding, currentEmbedding),
        ),
      );
    }

    scored.sort((TaeraeScoredNode a, TaeraeScoredNode b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.nodeId.compareTo(b.nodeId);
    });

    return List<TaeraeScoredNode>.unmodifiable(scored.take(topK));
  }

  @override
  Future<void> clear() async {
    _embeddings.clear();
  }

  /// Snapshot of current embeddings.
  UnmodifiableMapView<String, List<double>> get embeddings =>
      UnmodifiableMapView<String, List<double>>(_embeddings);

  static void _validateEmbedding(List<double> embedding, String fieldName) {
    if (embedding.isEmpty) {
      throw ArgumentError.value(embedding, fieldName, 'Must not be empty.');
    }
    if (embedding.any((double value) => !value.isFinite)) {
      throw ArgumentError.value(
        embedding,
        fieldName,
        'All values must be finite numbers.',
      );
    }
  }

  static double _cosineSimilarity(List<double> left, List<double> right) {
    double dot = 0;
    double leftNorm = 0;
    double rightNorm = 0;

    for (int i = 0; i < left.length; i++) {
      dot += left[i] * right[i];
      leftNorm += left[i] * left[i];
      rightNorm += right[i] * right[i];
    }

    if (leftNorm == 0 || rightNorm == 0) {
      return 0;
    }
    return dot / (math.sqrt(leftNorm) * math.sqrt(rightNorm));
  }
}
