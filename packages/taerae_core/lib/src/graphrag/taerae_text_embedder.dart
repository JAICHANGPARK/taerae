/// Interface for generating vector embeddings from text.
abstract interface class TaeraeTextEmbedder {
  /// Returns an embedding vector for [text].
  Future<List<double>> embed(String text);
}
