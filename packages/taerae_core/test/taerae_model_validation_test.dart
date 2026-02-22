import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  group('TaeraeNode and TaeraeEdge validation', () {
    test('validate required and structured fields', () {
      expect(() => TaeraeNode(id: '   '), throwsArgumentError);
      expect(
        () => TaeraeNode(id: 'n1', labels: const <String>['']),
        throwsArgumentError,
      );
      expect(
        () => TaeraeNode.fromJson(<String, Object?>{'id': 'n1', 'labels': 1}),
        throwsFormatException,
      );
      expect(
        () => TaeraeNode.fromJson(<String, Object?>{}),
        throwsFormatException,
      );
      expect(
        () => TaeraeNode.fromJson(<String, Object?>{
          'id': 'n1',
          'labels': <Object?>['ok', ''],
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeNode.fromJson(<String, Object?>{
          'id': 'n1',
          'properties': <Object?>[],
        }),
        throwsFormatException,
      );

      expect(
        () => TaeraeEdge(id: 'e1', from: ' ', to: 'n2'),
        throwsArgumentError,
      );
      expect(
        () => TaeraeEdge.fromJson(<String, Object?>{
          'id': 'e1',
          'from': 'n1',
          'to': 'n2',
          'type': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => TaeraeEdge.fromJson(<String, Object?>{
          'id': 'e1',
          'from': 'n1',
          'to': 'n2',
          'properties': <Object?>[],
        }),
        throwsFormatException,
      );
    });

    test('copyWith keeps existing values when omitted', () {
      final TaeraeNode node = TaeraeNode(
        id: 'n1',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'A'},
      );
      final TaeraeNode updatedNode = node.copyWith(
        properties: const <String, Object?>{'name': 'B'},
      );

      expect(updatedNode.id, equals('n1'));
      expect(updatedNode.labels, equals(const <String>{'Person'}));
      expect(updatedNode.properties['name'], equals('B'));

      final TaeraeNode labelsOnly = node.copyWith(
        labels: const <String>['Engineer'],
      );
      expect(labelsOnly.properties['name'], equals('A'));

      final TaeraeEdge edge = TaeraeEdge(
        id: 'e1',
        from: 'n1',
        to: 'n2',
        type: 'KNOWS',
        properties: const <String, Object?>{'since': 2020},
      );
      final TaeraeEdge updatedEdge = edge.copyWith(to: 'n3');

      expect(updatedEdge.id, equals('e1'));
      expect(updatedEdge.from, equals('n1'));
      expect(updatedEdge.to, equals('n3'));
      expect(updatedEdge.type, equals('KNOWS'));
      expect(updatedEdge.properties['since'], equals(2020));

      final TaeraeEdge fromOnly = edge.copyWith(from: 'n0');
      expect(fromOnly.to, equals('n2'));
    });
  });

  group('TaeraeGraph parsing and property indexing', () {
    test('rejects malformed root JSON structures', () {
      expect(
        () => TaeraeGraph.fromJson(<String, Object?>{'nodes': 1}),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraph.fromJson(<String, Object?>{'edges': 1}),
        throwsFormatException,
      );
      expect(
        () => TaeraeGraph.fromJson(<String, Object?>{
          'nodes': <Object?>[
            <Object?, Object?>{'': 1},
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects edges whose endpoints do not exist', () {
      expect(
        () => TaeraeGraph.fromJson(<String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{'id': 'n1'},
          ],
          'edges': <Object?>[
            <String, Object?>{'id': 'e1', 'from': 'n2', 'to': 'n1'},
          ],
        }),
        throwsStateError,
      );
    });

    test('handles deep equality and hashing for list/map property values', () {
      final _HashCollisionValue v1 = _HashCollisionValue('v1');
      final _HashCollisionValue v2 = _HashCollisionValue('v2');
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode(
          'n1',
          properties: const <String, Object?>{
            'arr': <Object?>[1, 2],
            'meta': <String, Object?>{'score': 10},
            'bucket': 7,
          },
        )
        ..upsertNode(
          'n2',
          properties: <String, Object?>{
            'arr': const <Object?>[1],
            'meta': const <String, Object?>{'score': 11},
            'bucket': 8,
            'custom': v1,
          },
        );

      expect(
        graph.nodesWhereProperty('arr', const <Object?>[1, 2]).single.id,
        equals('n1'),
      );
      expect(
        graph.nodesWhereProperty('arr', const <Object?>[1, 2, 3]),
        isEmpty,
      );
      expect(graph.nodesWhereProperty('arr', const <Object?>[1, 3]), isEmpty);
      expect(
        graph
            .nodesWhereProperty('meta', const <String, Object?>{'score': 10})
            .single
            .id,
        equals('n1'),
      );
      expect(graph.nodesWhereProperty('bucket', 7).single.id, equals('n1'));
      expect(graph.nodesWhereProperty('custom', v2), isEmpty);
    });
  });
}

class _HashCollisionValue {
  const _HashCollisionValue(this.value);

  final String value;

  @override
  bool operator ==(Object other) {
    return other is _HashCollisionValue && other.value == value;
  }

  @override
  int get hashCode => 0;
}
