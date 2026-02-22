import 'package:taerae_core/taerae_core.dart';

void main() {
  final TaeraeGraph city = TaeraeGraph()
    ..upsertNode(
      'home',
      labels: const <String>['Place'],
      properties: const <String, Object?>{
        'name': 'Home',
        'district': 'Mapo',
        'category': 'residence',
      },
    )
    ..upsertNode(
      'station_hapjeong',
      labels: const <String>['Place', 'Transit'],
      properties: const <String, Object?>{
        'name': 'Hapjeong Station',
        'district': 'Mapo',
        'category': 'station',
      },
    )
    ..upsertNode(
      'office',
      labels: const <String>['Place'],
      properties: const <String, Object?>{
        'name': 'Office',
        'district': 'Gangnam',
        'category': 'workplace',
      },
    )
    ..upsertNode(
      'cafe',
      labels: const <String>['Place'],
      properties: const <String, Object?>{
        'name': 'Morning Cafe',
        'district': 'Gangnam',
        'category': 'cafe',
      },
    )
    ..upsertNode(
      'gym',
      labels: const <String>['Place'],
      properties: const <String, Object?>{
        'name': 'Afterwork Gym',
        'district': 'Gangnam',
        'category': 'fitness',
      },
    )
    ..upsertEdge('r1', 'home', 'station_hapjeong', type: 'ROUTE')
    ..upsertEdge('r2', 'station_hapjeong', 'office', type: 'ROUTE')
    ..upsertEdge('r3', 'office', 'cafe', type: 'ROUTE')
    ..upsertEdge('r4', 'office', 'gym', type: 'ROUTE');

  final List<String>? commutePath = city.shortestPathBfs('home', 'office');
  final List<TaeraeNode> gangnamPlaces = city.nodesWhereProperty(
    'district',
    'Gangnam',
  );
  final List<TaeraeNode> nextStops = city.neighbors(
    'office',
    type: 'ROUTE',
    bothDirections: false,
  );

  print('Commute path home -> office: $commutePath');
  print(
    'Gangnam places: ${gangnamPlaces.map((TaeraeNode n) => n.properties['name']).toList()}',
  );
  print(
    'After-office stops: ${nextStops.map((TaeraeNode n) => n.properties['name']).toList()}',
  );
}
