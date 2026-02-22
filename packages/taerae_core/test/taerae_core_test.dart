import 'package:taerae/taerae.dart';
import 'package:test/test.dart';

void main() {
  group('immutable models', () {
    test('node and edge collections are immutable', () {
      final TaeraeNode node = TaeraeNode(
        id: 'n1',
        labels: const <String>['Person'],
        properties: const <String, Object?>{
          'name': 'Taerae',
          'skills': <Object?>['Dart'],
        },
      );
      final TaeraeEdge edge = TaeraeEdge(
        id: 'e1',
        from: 'n1',
        to: 'n2',
        properties: const <String, Object?>{
          'weights': <Object?>[1, 2, 3],
        },
      );

      expect(() => node.labels.add('Engineer'), throwsUnsupportedError);
      expect(() => node.properties['name'] = 'Other', throwsUnsupportedError);
      expect(
        () => (node.properties['skills'] as List<Object?>).add('Graph'),
        throwsUnsupportedError,
      );
      expect(() => edge.properties['cost'] = 2, throwsUnsupportedError);
      expect(
        () => (edge.properties['weights'] as List<Object?>).add(4),
        throwsUnsupportedError,
      );
    });
  });

  group('upsert and validation', () {
    test('upsertNode inserts and updates while retaining omitted fields', () {
      final TaeraeGraph graph = TaeraeGraph();

      graph.upsertNode(
        'n1',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'Taerae'},
      );
      final TaeraeNode updated = graph.upsertNode(
        'n1',
        properties: const <String, Object?>{'name': 'Terry'},
      );
      final TaeraeNode labelsOnly = graph.upsertNode(
        'n1',
        labels: const <String>['Human'],
      );

      expect(updated.labels, equals(const <String>{'Person'}));
      expect(updated.properties['name'], equals('Terry'));
      expect(labelsOnly.properties['name'], equals('Terry'));
    });

    test('upsertEdge validates endpoints exist', () {
      final TaeraeGraph graph = TaeraeGraph()..upsertNode('n1');

      expect(
        () => graph.upsertEdge('e1', 'n1', 'missing'),
        throwsA(isA<StateError>()),
      );
    });

    test('upsertEdge can move edge endpoints and reindexes adjacency', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertNode('n3')
        ..upsertEdge('e1', 'n1', 'n2', type: 'link');

      graph.upsertEdge('e1', 'n1', 'n3');

      expect(graph.outgoing('n1').single.to, equals('n3'));
      expect(graph.incoming('n2'), isEmpty);
      expect(graph.incoming('n3').single.id, equals('e1'));
      expect(graph.edgeById('e1')?.type, equals('link'));
    });
  });

  group('queries', () {
    late TaeraeGraph graph;

    setUp(() {
      graph = TaeraeGraph()
        ..upsertNode(
          'n1',
          labels: const <String>['Person'],
          properties: const <String, Object?>{
            'team': 'A',
            'meta': <String, Object?>{'tier': 1},
          },
        )
        ..upsertNode(
          'n2',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'team': 'A'},
        )
        ..upsertNode(
          'n3',
          labels: const <String>['Company'],
          properties: const <String, Object?>{'team': 'B'},
        )
        ..upsertEdge('e1', 'n1', 'n2', type: 'friend')
        ..upsertEdge('e2', 'n3', 'n1', type: 'employs')
        ..upsertEdge('e3', 'n1', 'n3', type: 'works_at');
    });

    test('outgoing and incoming support type filters', () {
      expect(
        graph.outgoing('n1').map((TaeraeEdge edge) => edge.id),
        unorderedEquals(const <String>['e1', 'e3']),
      );
      expect(graph.outgoing('n1', type: 'friend').single.id, equals('e1'));
      expect(graph.incoming('n1').single.id, equals('e2'));
      expect(graph.incoming('n1', type: 'friend'), isEmpty);
    });

    test('neighbors supports direction and type filtering', () {
      expect(
        graph.neighbors('n1').map((TaeraeNode node) => node.id),
        unorderedEquals(const <String>['n2', 'n3']),
      );
      expect(
        graph
            .neighbors('n1', bothDirections: false)
            .map((TaeraeNode node) => node.id),
        unorderedEquals(const <String>['n2', 'n3']),
      );
      expect(
        graph.neighbors('n1', type: 'friend').map((TaeraeNode node) => node.id),
        equals(const <String>['n2']),
      );
    });

    test('label and property indexes return matching nodes', () {
      expect(
        graph.nodesByLabel('Person').map((TaeraeNode node) => node.id),
        unorderedEquals(const <String>['n1', 'n2']),
      );
      expect(
        graph.nodesWhereProperty('team', 'A').map((TaeraeNode node) => node.id),
        unorderedEquals(const <String>['n1', 'n2']),
      );
      expect(
        graph
            .nodesWhereProperty('meta', const <String, Object?>{'tier': 1})
            .single
            .id,
        equals('n1'),
      );
    });
  });

  group('remove behavior', () {
    test('removeEdge updates adjacency indexes', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2', type: 'link');

      final bool removed = graph.removeEdge('e1');

      expect(removed, isTrue);
      expect(graph.containsEdge('e1'), isFalse);
      expect(graph.outgoing('n1'), isEmpty);
      expect(graph.incoming('n2'), isEmpty);
      expect(graph.removeEdge('e1'), isFalse);
    });

    test('removeNode deletes incident edges and indexes', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode(
          'n1',
          labels: const <String>['City'],
          properties: const <String, Object?>{'name': 'Seoul'},
        )
        ..upsertNode(
          'n2',
          labels: const <String>['City'],
          properties: const <String, Object?>{'name': 'Busan'},
        )
        ..upsertNode('n3')
        ..upsertEdge('e1', 'n1', 'n2', type: 'road')
        ..upsertEdge('e2', 'n3', 'n1', type: 'road');

      final bool removed = graph.removeNode('n1');

      expect(removed, isTrue);
      expect(graph.containsNode('n1'), isFalse);
      expect(graph.containsEdge('e1'), isFalse);
      expect(graph.containsEdge('e2'), isFalse);
      expect(
        graph.nodesByLabel('City').map((TaeraeNode node) => node.id),
        equals(const <String>['n2']),
      );
      expect(graph.nodesWhereProperty('name', 'Seoul'), isEmpty);
      expect(graph.removeNode('n1'), isFalse);
    });
  });

  group('shortestPathBfs', () {
    late TaeraeGraph graph;

    setUp(() {
      graph = TaeraeGraph()
        ..upsertNode('A')
        ..upsertNode('B')
        ..upsertNode('C')
        ..upsertNode('D')
        ..upsertEdge('ab', 'A', 'B', type: 'road')
        ..upsertEdge('bc', 'B', 'C', type: 'road')
        ..upsertEdge('ac', 'A', 'C', type: 'flight')
        ..upsertEdge('ad', 'A', 'D', type: 'road')
        ..upsertEdge('dc', 'D', 'C', type: 'road');
    });

    test('returns shortest directed path', () {
      expect(graph.shortestPathBfs('A', 'C'), equals(const <String>['A', 'C']));
      expect(
        graph.shortestPathBfs('A', 'C', edgeType: 'road'),
        equals(const <String>['A', 'B', 'C']),
      );
    });

    test('returns null when no path exists', () {
      expect(graph.shortestPathBfs('C', 'A'), isNull);
      expect(graph.shortestPathBfs('A', 'missing'), isNull);
    });

    test('returns single node path for same start and end', () {
      expect(graph.shortestPathBfs('A', 'A'), equals(const <String>['A']));
    });
  });

  group('copy, clear, and json', () {
    test('copy is independent from original graph mutations', () {
      final TaeraeGraph original = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2');

      final TaeraeGraph cloned = original.copy()..removeNode('n1');

      expect(original.containsNode('n1'), isTrue);
      expect(original.containsEdge('e1'), isTrue);
      expect(cloned.containsNode('n1'), isFalse);
      expect(cloned.containsEdge('e1'), isFalse);
    });

    test('toJson and fromJson round-trip graph data', () {
      final TaeraeGraph original = TaeraeGraph()
        ..upsertNode(
          'n1',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'name': 'Taerae'},
        )
        ..upsertNode('n2')
        ..upsertEdge(
          'e1',
          'n1',
          'n2',
          type: 'friend',
          properties: const <String, Object?>{'since': 2026},
        );

      final TaeraeGraph restored = TaeraeGraph.fromJson(original.toJson());

      expect(restored.nodeById('n1')?.labels, equals(const <String>{'Person'}));
      expect(restored.edgeById('e1')?.properties['since'], equals(2026));
      expect(
        restored.shortestPathBfs('n1', 'n2'),
        equals(const <String>['n1', 'n2']),
      );
    });

    test('clear removes all data', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2');

      graph.clear();

      expect(graph.containsNode('n1'), isFalse);
      expect(graph.containsNode('n2'), isFalse);
      expect(graph.containsEdge('e1'), isFalse);
      expect(graph.outgoing('n1'), isEmpty);
      expect(graph.nodesByLabel('missing'), isEmpty);
    });
  });
}
