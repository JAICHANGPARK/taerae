import 'package:taerae_core/taerae_core.dart';

void main() {
  final TaeraeGraph ops = TaeraeGraph()
    ..upsertNode('hub', labels: const <String>['Place'])
    ..upsertNode('station_a', labels: const <String>['Place'])
    ..upsertNode('customer_1', labels: const <String>['Place'])
    ..upsertNode(
      'pkg_1001',
      labels: const <String>['Package'],
      properties: const <String, Object?>{
        'status': 'in_transit',
        'priority': 'high',
      },
    )
    ..upsertNode(
      'pkg_1002',
      labels: const <String>['Package'],
      properties: const <String, Object?>{
        'status': 'pending',
        'priority': 'normal',
      },
    )
    ..upsertEdge('r1', 'hub', 'station_a', type: 'ROUTE')
    ..upsertEdge('r2', 'station_a', 'customer_1', type: 'ROUTE')
    ..upsertEdge('e_pkg_1', 'pkg_1001', 'customer_1', type: 'DELIVERS_TO')
    ..upsertEdge('e_pkg_2', 'pkg_1002', 'customer_1', type: 'DELIVERS_TO');

  final List<String>? route = ops.shortestPathBfs('hub', 'customer_1');
  final List<TaeraeNode> pendingPackages = ops.nodesWhereProperty(
    'status',
    'pending',
  );

  print('Route hub -> customer_1: $route');
  print(
    'Pending packages: '
    '${pendingPackages.map((TaeraeNode n) => n.id).toList()}',
  );

  // CRUD update: delivery completed for pkg_1002.
  ops.upsertNode(
    'pkg_1002',
    properties: const <String, Object?>{
      'status': 'delivered',
      'priority': 'normal',
    },
  );
  final List<TaeraeNode> delivered = ops.nodesWhereProperty(
    'status',
    'delivered',
  );
  print(
    'Delivered packages: ${delivered.map((TaeraeNode n) => n.id).toList()}',
  );
}
