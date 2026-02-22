import 'package:taerae/taerae.dart';

void main() {
  final TaeraeGraph graph = TaeraeGraph()
    ..upsertNode(
      'alice',
      labels: const <String>['Person'],
      properties: const <String, Object?>{'name': 'Alice'},
    )
    ..upsertNode(
      'bob',
      labels: const <String>['Person'],
      properties: const <String, Object?>{'name': 'Bob'},
    )
    ..upsertNode('seoul', labels: const <String>['City'])
    ..upsertEdge('e1', 'alice', 'bob', type: 'KNOWS')
    ..upsertEdge('e2', 'alice', 'seoul', type: 'LIVES_IN');

  final List<String>? path = graph.shortestPathBfs('alice', 'seoul');
  print('Path alice -> seoul: $path');
}
