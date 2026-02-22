import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  group('TaeraeInMemoryVectorIndex', () {
    test('returns top results by cosine similarity', () async {
      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();
      await index.upsert('alice', const <double>[1, 0]);
      await index.upsert('bob', const <double>[0, 1]);
      await index.upsert('charlie', const <double>[0.8, 0.2]);

      final List<TaeraeScoredNode> hits = await index.search(const <double>[
        0.9,
        0.1,
      ], topK: 2);

      expect(hits.length, equals(2));
      expect(hits.first.nodeId, equals('alice'));
      expect(hits.last.nodeId, equals('charlie'));
    });
  });

  group('TaeraeGraphRag', () {
    test('retrieves node hits with neighborhood context', () async {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode(
          'alice',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'text': 'flutter developer'},
        )
        ..upsertNode(
          'dart',
          labels: const <String>['Skill'],
          properties: const <String, Object?>{'text': 'dart language'},
        )
        ..upsertNode(
          'graph',
          labels: const <String>['Skill'],
          properties: const <String, Object?>{'text': 'graph database'},
        )
        ..upsertEdge('e1', 'alice', 'dart', type: 'HAS_SKILL')
        ..upsertEdge('e2', 'alice', 'graph', type: 'HAS_SKILL');

      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();
      final _FakeEmbedder embedder = _FakeEmbedder(<String, List<double>>{
        'flutter developer': const <double>[1, 0],
        'dart language': const <double>[0.8, 0.2],
        'graph database': const <double>[0.2, 0.8],
        'best flutter engineer': const <double>[0.95, 0.05],
      });

      final TaeraeGraphRag rag = TaeraeGraphRag(
        graph: graph,
        embedder: embedder,
        vectorIndex: index,
      );

      await rag.indexNodeText('alice', 'flutter developer');
      await rag.indexNodeText('dart', 'dart language');
      await rag.indexNodeText('graph', 'graph database');

      final List<TaeraeGraphRagHit> hits = await rag.retrieve(
        'best flutter engineer',
        topK: 2,
        neighborhoodHops: 1,
      );

      expect(hits.length, equals(2));
      expect(hits.first.node.id, equals('alice'));
      expect(
        hits.first.neighborhood.map((TaeraeNode node) => node.id),
        unorderedEquals(const <String>['dart', 'graph']),
      );
    });

    test(
      'supports chunk indexing and deduplicates chunk hits per node',
      () async {
        final TaeraeGraph graph = TaeraeGraph()
          ..upsertNode(
            'n1',
            labels: const <String>['Doc'],
            properties: const <String, Object?>{'text': 'alpha|beta'},
          )
          ..upsertNode(
            'n2',
            labels: const <String>['Doc'],
            properties: const <String, Object?>{'text': 'gamma'},
          );

        final _FakeEmbedder embedder = _FakeEmbedder(<String, List<double>>{
          'alpha': const <double>[1, 0],
          'beta': const <double>[0.9, 0.1],
          'gamma': const <double>[0.1, 0.9],
          'find alpha topic': const <double>[0.95, 0.05],
        });

        final TaeraeGraphRag rag = TaeraeGraphRag(
          graph: graph,
          embedder: embedder,
          vectorIndex: TaeraeInMemoryVectorIndex(),
          chunker: const _PipeChunker(),
        );

        await rag.indexNodeText('n1', 'alpha|beta');
        await rag.indexNodeText('n2', 'gamma');

        final List<TaeraeGraphRagHit> hits = await rag.retrieve(
          'find alpha topic',
          topK: 1,
        );

        expect(hits.length, equals(1));
        expect(hits.single.node.id, equals('n1'));
      },
    );

    test('supports node metadata filtering', () async {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode(
          'doc_ai',
          labels: const <String>['Document'],
          properties: const <String, Object?>{'topic': 'ai'},
        )
        ..upsertNode(
          'doc_food',
          labels: const <String>['Document'],
          properties: const <String, Object?>{'topic': 'food'},
        );

      final _FakeEmbedder embedder = _FakeEmbedder(<String, List<double>>{
        'ai text': const <double>[1, 0],
        'food text': const <double>[0.95, 0.05],
        'smart cooking': const <double>[0.9, 0.1],
      });

      final TaeraeGraphRag rag = TaeraeGraphRag(
        graph: graph,
        embedder: embedder,
        vectorIndex: TaeraeInMemoryVectorIndex(),
      );

      await rag.indexNodeText('doc_ai', 'ai text');
      await rag.indexNodeText('doc_food', 'food text');

      final List<TaeraeGraphRagHit> hits = await rag.retrieve(
        'smart cooking',
        topK: 2,
        filter: const TaeraeGraphRagFilter(
          requiredLabels: <String>{'Document'},
          requiredProperties: <String, Object?>{'topic': 'ai'},
        ),
      );

      expect(hits.length, equals(1));
      expect(hits.single.node.id, equals('doc_ai'));
    });

    test('supports custom reranker hook', () async {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('a')
        ..upsertNode('b');

      final _FakeEmbedder embedder = _FakeEmbedder(<String, List<double>>{
        'A': const <double>[1, 0],
        'B': const <double>[0.8, 0.2],
        'query': const <double>[0.95, 0.05],
      });

      final TaeraeGraphRag rag = TaeraeGraphRag(
        graph: graph,
        embedder: embedder,
        vectorIndex: TaeraeInMemoryVectorIndex(),
        defaultReranker: const _ReverseReranker(),
      );

      await rag.indexNodeText('a', 'A');
      await rag.indexNodeText('b', 'B');

      final List<TaeraeGraphRagHit> hits = await rag.retrieve('query', topK: 2);
      expect(hits.map((TaeraeGraphRagHit hit) => hit.node.id), ['b', 'a']);
    });
  });
}

class _FakeEmbedder implements TaeraeTextEmbedder {
  _FakeEmbedder(this._vectors);

  final Map<String, List<double>> _vectors;

  @override
  Future<List<double>> embed(String text) async {
    final List<double>? vector = _vectors[text];
    if (vector == null) {
      throw StateError('Missing embedding for "$text".');
    }
    return vector;
  }
}

class _PipeChunker implements TaeraeTextChunker {
  const _PipeChunker();

  @override
  List<String> split(String text) => text.split('|');
}

class _ReverseReranker implements TaeraeGraphReranker {
  const _ReverseReranker();

  @override
  Future<List<TaeraeGraphRagHit>> rerank(
    String query,
    List<TaeraeGraphRagHit> hits,
  ) async {
    return hits.reversed.toList(growable: false);
  }
}
