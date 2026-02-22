import 'package:taerae_core/taerae_core.dart';

void main() {
  final TaeraeGraph graph = TaeraeGraph()
    ..upsertNode(
      'alice',
      labels: const <String>['Person'],
      properties: const <String, Object?>{'team': 'platform'},
    )
    ..upsertNode(
      'bob',
      labels: const <String>['Person'],
      properties: const <String, Object?>{'team': 'ai'},
    )
    ..upsertNode('taerae', labels: const <String>['Project'])
    ..upsertEdge('e1', 'alice', 'bob', type: 'KNOWS')
    ..upsertEdge('e2', 'bob', 'taerae', type: 'WORKS_ON');

  final List<TaeraeNode> people = graph.nodesByLabel('Person');
  final List<TaeraeNode> aiTeam = graph.nodesWhereProperty('team', 'ai');
  final List<String>? path = graph.shortestPathBfs('alice', 'taerae');

  print('People: ${people.map((TaeraeNode n) => n.id).toList()}');
  print('AI team: ${aiTeam.map((TaeraeNode n) => n.id).toList()}');
  print('Path alice -> taerae: $path');
}
