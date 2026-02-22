import 'package:flutter_taerae/flutter_taerae.dart';
import 'package:flutter_taerae/flutter_taerae_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingBasePlatform extends TaeraeFlutterPlatform {}

void main() {
  group('TaeraeFlutterPlatform', () {
    test('base implementation throws for unimplemented API', () {
      final _ThrowingBasePlatform platform = _ThrowingBasePlatform();
      expect(platform.getPlatformVersion, throwsUnimplementedError);
    });
  });

  group('TaeraeGraphController', () {
    test('creates from json and returns a defensive graph copy', () {
      final TaeraeGraphController controller = TaeraeGraphController.fromJson(
        <String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{
              'id': 'n1',
              'labels': <Object?>['User'],
            },
            <String, Object?>{'id': 'n2'},
          ],
          'edges': <Object?>[
            <String, Object?>{'id': 'e1', 'from': 'n1', 'to': 'n2'},
          ],
        },
      );

      final TaeraeGraph detached = controller.graph..removeNode('n1');
      expect(detached.containsNode('n1'), isFalse);
      expect(controller.containsNode('n1'), isTrue);
      expect(controller.edgeById('e1')?.id, equals('e1'));
      expect(controller.nodeById('n1')?.id, equals('n1'));
    });

    test('nodes and edges getters are sorted and cache until invalidated', () {
      final TaeraeGraphController controller = TaeraeGraphController()
        ..upsertNode('b')
        ..upsertNode('a')
        ..upsertEdge('e2', 'a', 'b')
        ..upsertEdge('e1', 'b', 'a');

      final List<TaeraeNode> firstNodes = controller.nodes;
      final List<TaeraeNode> secondNodes = controller.nodes;
      final List<TaeraeEdge> firstEdges = controller.edges;
      final List<TaeraeEdge> secondEdges = controller.edges;

      expect(
        firstNodes.map((TaeraeNode node) => node.id),
        equals(<String>['a', 'b']),
      );
      expect(
        firstEdges.map((TaeraeEdge edge) => edge.id),
        equals(<String>['e1', 'e2']),
      );
      expect(identical(firstNodes, secondNodes), isTrue);
      expect(identical(firstEdges, secondEdges), isTrue);

      controller.upsertNode('c');
      final List<TaeraeNode> thirdNodes = controller.nodes;
      expect(identical(firstNodes, thirdNodes), isFalse);
      expect(
        thirdNodes.map((TaeraeNode node) => node.id),
        equals(<String>['a', 'b', 'c']),
      );
    });

    test('query helpers delegate to graph operations', () {
      final TaeraeGraphController controller = TaeraeGraphController()
        ..upsertNode('n1', labels: const <String>['User'])
        ..upsertNode(
          'n2',
          labels: const <String>['User'],
          properties: const <String, Object?>{'team': 'A'},
        )
        ..upsertNode('n3')
        ..upsertEdge('e1', 'n1', 'n2', type: 'friend')
        ..upsertEdge('e2', 'n3', 'n1', type: 'friend');

      expect(controller.nodesByLabel('User').length, equals(2));
      expect(
        controller.nodesWhereProperty('team', 'A').single.id,
        equals('n2'),
      );
      expect(controller.outgoing('n1').single.id, equals('e1'));
      expect(controller.incoming('n1').single.id, equals('e2'));
      expect(
        controller.neighbors('n1').map((TaeraeNode node) => node.id),
        unorderedEquals(<String>['n2', 'n3']),
      );
      expect(
        controller.shortestPathBfs('n3', 'n2'),
        equals(const <String>['n3', 'n1', 'n2']),
      );
    });

    test('notifies only on effective mutations and clear behavior', () {
      final TaeraeGraphController controller = TaeraeGraphController();
      int notifyCount = 0;
      controller.addListener(() {
        notifyCount += 1;
      });

      expect(controller.removeNode('missing'), isFalse);
      expect(controller.removeEdge('missing'), isFalse);
      controller.clear(); // Empty no-op.
      expect(notifyCount, equals(0));

      controller
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2');
      expect(notifyCount, equals(3));

      expect(controller.removeEdge('e1'), isTrue);
      expect(notifyCount, equals(4));
      expect(controller.removeNode('n1'), isTrue);
      expect(notifyCount, equals(5));

      controller.clear();
      expect(notifyCount, equals(6));
      controller.clear(); // Already empty.
      expect(notifyCount, equals(6));
    });

    test(
      'replace/import/export helpers work with pretty json and validation',
      () {
        final TaeraeGraph replacement = TaeraeGraph()
          ..upsertNode('r1')
          ..upsertNode('r2')
          ..upsertEdge('re1', 'r1', 'r2');

        final TaeraeGraphController controller = TaeraeGraphController();
        int notifyCount = 0;
        controller.addListener(() {
          notifyCount += 1;
        });

        controller.replaceGraph(replacement);
        expect(controller.containsEdge('re1'), isTrue);
        expect(notifyCount, equals(1));

        final Map<String, Object?> exported = controller.exportToJson();
        expect(exported['nodes'], isA<List<Object?>>());
        final String pretty = controller.exportToJsonString(pretty: true);
        expect(pretty.contains('\n'), isTrue);

        controller.importFromJson(<String, Object?>{
          'nodes': <Object?>[
            <String, Object?>{'id': 'i1'},
          ],
          'edges': <Object?>[],
        });
        expect(controller.containsNode('i1'), isTrue);
        expect(notifyCount, equals(2));

        controller.importFromJsonString('{"nodes":[{"id":"s1"}],"edges":[]}');
        expect(controller.containsNode('s1'), isTrue);
        expect(notifyCount, equals(3));

        expect(
          () => controller.importFromJsonString('[]'),
          throwsFormatException,
        );
      },
    );
  });
}
