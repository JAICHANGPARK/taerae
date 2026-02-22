import 'package:taerae/taerae.dart';

Future<void> main() async {
  final TaeraeGraph notes = TaeraeGraph()
    ..upsertNode(
      'note_1',
      labels: const <String>['Note'],
      properties: const <String, Object?>{'category': 'work', 'urgent': true},
    )
    ..upsertNode(
      'note_2',
      labels: const <String>['Note'],
      properties: const <String, Object?>{
        'category': 'health',
        'urgent': false,
      },
    )
    ..upsertNode(
      'note_3',
      labels: const <String>['Note'],
      properties: const <String, Object?>{'category': 'work', 'urgent': false},
    )
    ..upsertEdge('rel_1', 'note_1', 'note_3', type: 'RELATED');

  final TaeraeGraphRag rag = TaeraeGraphRag(
    graph: notes,
    embedder: const _KeywordEmbedder(),
    vectorIndex: TaeraeInMemoryVectorIndex(),
    defaultReranker: const _UrgentFirstReranker(),
  );

  await rag.indexNodeText(
    'note_1',
    'prepare quarterly release plan and production checklist',
  );
  await rag.indexNodeText(
    'note_2',
    'book annual health check and blood test next week',
  );
  await rag.indexNodeText(
    'note_3',
    'review hiring pipeline and interview score rubric',
  );

  final List<TaeraeGraphRagHit> hits = await rag.retrieve(
    'work plan for next week',
    topK: 2,
    neighborhoodHops: 1,
    filter: const TaeraeGraphRagFilter(
      requiredLabels: <String>{'Note'},
      requiredProperties: <String, Object?>{'category': 'work'},
    ),
  );

  for (final TaeraeGraphRagHit hit in hits) {
    print(
      'Hit: ${hit.node.id} (score: ${hit.score.toStringAsFixed(4)}), '
      'urgent=${hit.node.properties['urgent']}',
    );
    print(
      'Related notes: '
      '${hit.neighborhood.map((TaeraeNode n) => n.id).toList()}',
    );
  }
}

class _KeywordEmbedder implements TaeraeTextEmbedder {
  const _KeywordEmbedder();

  @override
  Future<List<double>> embed(String text) async {
    final String normalized = text.toLowerCase();
    final double work =
        normalized.contains('work') ||
            normalized.contains('release') ||
            normalized.contains('hiring')
        ? 1
        : 0;
    final double health =
        normalized.contains('health') || normalized.contains('blood') ? 1 : 0;
    final double planning =
        normalized.contains('plan') || normalized.contains('checklist') ? 1 : 0;

    if (work == 0 && health == 0 && planning == 0) {
      return const <double>[1, 1, 1];
    }
    return <double>[work, health, planning];
  }
}

class _UrgentFirstReranker implements TaeraeGraphReranker {
  const _UrgentFirstReranker();

  @override
  Future<List<TaeraeGraphRagHit>> rerank(
    String query,
    List<TaeraeGraphRagHit> hits,
  ) async {
    final List<TaeraeGraphRagHit> sorted = hits
        .map((TaeraeGraphRagHit hit) {
          final bool urgent = hit.node.properties['urgent'] == true;
          return urgent ? hit.copyWith(score: hit.score + 0.2) : hit;
        })
        .toList(growable: true);

    sorted.sort((TaeraeGraphRagHit a, TaeraeGraphRagHit b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.node.id.compareTo(b.node.id);
    });

    return sorted;
  }
}
