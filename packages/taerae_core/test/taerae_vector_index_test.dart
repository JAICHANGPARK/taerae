import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  group('TaeraeInMemoryVectorIndex', () {
    test('validates upsert input', () async {
      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();

      expect(
        () => index.upsert('   ', const <double>[1, 2]),
        throwsArgumentError,
      );
      expect(() => index.upsert('n1', const <double>[]), throwsArgumentError);
      expect(
        () => index.upsert('n1', const <double>[1, double.nan]),
        throwsArgumentError,
      );
    });

    test('search handles edge cases and stable ordering', () async {
      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();

      expect(await index.search(const <double>[1, 0], topK: 0), isEmpty);
      expect(await index.search(const <double>[1, 0]), isEmpty);

      await index.upsert('b', const <double>[1, 0]);
      await index.upsert('a', const <double>[1, 0]);
      await index.upsert('zero', const <double>[0, 0]);

      final List<TaeraeScoredNode> ties = await index.search(const <double>[
        1,
        0,
      ], topK: 2);
      expect(ties.map((TaeraeScoredNode hit) => hit.nodeId), <String>[
        'a',
        'b',
      ]);

      final List<TaeraeScoredNode> zeroNorm = await index.search(const <double>[
        0,
        0,
      ], topK: 3);
      expect(
        zeroNorm
            .where((TaeraeScoredNode hit) => hit.nodeId == 'zero')
            .single
            .score,
        equals(0),
      );

      await index.upsert('bad_dim', const <double>[1, 0, 0]);
      expect(() => index.search(const <double>[1, 0]), throwsStateError);
    });

    test('supports remove, clear, and immutable embedding snapshots', () async {
      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();
      await index.upsert('n1', const <double>[1, 2]);
      await index.upsert('n2', const <double>[2, 1]);

      final Map<String, List<double>> snapshot = index.embeddings;
      expect(snapshot.keys, containsAll(<String>['n1', 'n2']));
      expect(() => snapshot['x'] = const <double>[1], throwsUnsupportedError);
      expect(() => snapshot['n1']!.add(3), throwsUnsupportedError);

      await index.remove('n1');
      expect(index.embeddings.keys, isNot(contains('n1')));

      await index.clear();
      expect(await index.search(const <double>[1, 0]), isEmpty);
    });

    test('validates query embedding values', () async {
      final TaeraeInMemoryVectorIndex index = TaeraeInMemoryVectorIndex();
      await index.upsert('n1', const <double>[1, 0]);

      expect(() => index.search(const <double>[]), throwsArgumentError);
      expect(
        () => index.search(const <double>[double.infinity]),
        throwsArgumentError,
      );
    });
  });
}
