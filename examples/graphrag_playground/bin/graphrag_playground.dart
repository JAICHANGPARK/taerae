import 'package:taerae/taerae.dart';

Future<void> main() async {
  final TaeraeGraph graph = TaeraeGraph()
    ..upsertNode(
      'doc_flutter',
      labels: const <String>['Document'],
      properties: const <String, Object?>{
        'text': 'Flutter on-device application architecture',
      },
    )
    ..upsertNode(
      'doc_graph',
      labels: const <String>['Document'],
      properties: const <String, Object?>{
        'text': 'Graph database and traversal patterns',
      },
    )
    ..upsertNode(
      'doc_ai',
      labels: const <String>['Document'],
      properties: const <String, Object?>{
        'text': 'On-device AI inference and model routing',
      },
    )
    ..upsertEdge('e1', 'doc_ai', 'doc_graph', type: 'RELATES_TO')
    ..upsertEdge('e2', 'doc_graph', 'doc_flutter', type: 'RELATES_TO');

  final TaeraeGraphRag rag = TaeraeGraphRag(
    graph: graph,
    embedder: _KeywordEmbedder(),
    vectorIndex: TaeraeInMemoryVectorIndex(),
  );

  for (final TaeraeNode node in graph.nodesByLabel('Document')) {
    await rag.indexNodeText(node.id, node.properties['text']! as String);
  }

  final List<TaeraeGraphRagHit> hits = await rag.retrieve(
    'graph rag for mobile ai app',
    topK: 2,
    neighborhoodHops: 1,
  );

  for (final TaeraeGraphRagHit hit in hits) {
    print('Hit: ${hit.node.id} (score: ${hit.score.toStringAsFixed(4)})');
    print('Context: ${hit.neighborhood.map((TaeraeNode n) => n.id).toList()}');
  }
}

class _KeywordEmbedder implements TaeraeTextEmbedder {
  @override
  Future<List<double>> embed(String text) async {
    final String normalized = text.toLowerCase();
    double flutter = 0;
    double graph = 0;
    double ai = 0;

    if (normalized.contains('flutter') || normalized.contains('mobile')) {
      flutter += 1;
    }
    if (normalized.contains('graph') || normalized.contains('rag')) {
      graph += 1;
    }
    if (normalized.contains('ai') || normalized.contains('model')) {
      ai += 1;
    }

    if (flutter == 0 && graph == 0 && ai == 0) {
      return const <double>[1, 1, 1];
    }
    return <double>[flutter, graph, ai];
  }
}
