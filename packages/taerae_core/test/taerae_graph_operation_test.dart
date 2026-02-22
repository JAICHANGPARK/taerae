import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  group('TaeraeGraphOperation', () {
    test('round-trips each operation kind through JSON', () {
      final TaeraeNode node = TaeraeNode(
        id: 'n1',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'A'},
      );
      final TaeraeEdge edge = TaeraeEdge(
        id: 'e1',
        from: 'n1',
        to: 'n2',
        type: 'KNOWS',
      );

      final List<TaeraeGraphOperation> operations = <TaeraeGraphOperation>[
        TaeraeGraphOperation.upsertNode(node),
        TaeraeGraphOperation.removeNode('n1'),
        TaeraeGraphOperation.upsertEdge(edge),
        TaeraeGraphOperation.removeEdge('e1'),
        const TaeraeGraphOperation.clear(),
      ];

      final List<TaeraeGraphOperationType> parsedTypes = operations
          .map((TaeraeGraphOperation operation) {
            final Map<String, Object?> json = operation.toJson();
            return TaeraeGraphOperation.fromJson(json).type;
          })
          .toList(growable: false);

      expect(
        parsedTypes,
        equals(<TaeraeGraphOperationType>[
          TaeraeGraphOperationType.upsertNode,
          TaeraeGraphOperationType.removeNode,
          TaeraeGraphOperationType.upsertEdge,
          TaeraeGraphOperationType.removeEdge,
          TaeraeGraphOperationType.clear,
        ]),
      );
    });

    test('applies remove and clear mutations', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2');

      TaeraeGraphOperation.removeEdge('e1').applyTo(graph);
      expect(graph.containsEdge('e1'), isFalse);

      TaeraeGraphOperation.removeNode('n2').applyTo(graph);
      expect(graph.containsNode('n2'), isFalse);

      const TaeraeGraphOperation.clear().applyTo(graph);
      expect(graph.toJson()['nodes'], equals(const <Object?>[]));
      expect(graph.toJson()['edges'], equals(const <Object?>[]));
    });

    test('validates malformed input JSON payloads', () {
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{'op': 1}),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{'op': ''}),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{'op': 'unknown'}),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{
          'op': 'remove_node',
          'id': '',
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{
          'op': 'remove_edge',
          'id': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{
          'op': 'upsert_node',
          'node': <Object?>[],
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{
          'op': 'upsert_node',
          'node': <Object?, Object?>{'': 'bad'},
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraphOperation.fromJson(<String, Object?>{
          'op': 'upsert_edge',
          'edge': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test(
      'requires non-empty id for remove operations when applying/serializing',
      () {
        final TaeraeGraphOperation removeNode = TaeraeGraphOperation.removeNode(
          '',
        );
        final TaeraeGraphOperation removeEdge = TaeraeGraphOperation.removeEdge(
          '',
        );

        expect(() => removeNode.toJson(), throwsStateError);
        expect(() => removeEdge.toJson(), throwsStateError);
        expect(() => removeNode.applyTo(TaeraeGraph()), throwsStateError);
        expect(() => removeEdge.applyTo(TaeraeGraph()), throwsStateError);
      },
    );
  });
}
