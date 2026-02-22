import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taerae_flutter/taerae_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TaeraeFlutter _plugin = TaeraeFlutter();
  final TaeraeGraphController _controller = TaeraeGraphController();
  String _platformVersion = 'loading...';
  int _nextNodeIndex = 3;

  @override
  void initState() {
    super.initState();
    _seedGraph();
    _loadPlatformVersion();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seedGraph() {
    _controller
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
      ..upsertNode(
        'seoul',
        labels: const <String>['City'],
        properties: const <String, Object?>{'name': 'Seoul'},
      )
      ..upsertEdge('knows', 'alice', 'bob', type: 'KNOWS')
      ..upsertEdge('lives_in', 'alice', 'seoul', type: 'LIVES_IN');
  }

  Future<void> _loadPlatformVersion() async {
    String platformVersion = 'unknown';
    try {
      platformVersion = await _plugin.getPlatformVersion() ?? 'unknown';
    } on PlatformException {
      platformVersion = 'unavailable';
    }

    if (!mounted) return;
    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void _addPersonConnectedToAlice() {
    final int index = _nextNodeIndex;
    final String nodeId = 'person_$index';
    _nextNodeIndex += 1;
    _controller.upsertNode(
      nodeId,
      labels: const <String>['Person'],
      properties: <String, Object?>{'name': 'Person #$index'},
    );
    _controller.upsertEdge('knows_$nodeId', 'alice', nodeId, type: 'KNOWS');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final List<TaeraeNode> nodes = _controller.nodes;
          final List<TaeraeEdge> edges = _controller.edges;
          final List<String>? path = _controller.shortestPathBfs(
            'alice',
            'seoul',
          );

          return Scaffold(
            appBar: AppBar(title: const Text('Taerae Flutter Example')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _addPersonConnectedToAlice,
              label: const Text('Add Person'),
              icon: const Icon(Icons.add),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Platform: $_platformVersion'),
                  const SizedBox(height: 12),
                  Text(
                    'Path alice -> seoul: ${path?.join(' -> ') ?? 'not found'}',
                  ),
                  const SizedBox(height: 12),
                  Text('Nodes (${nodes.length})'),
                  Text(
                    nodes
                        .map(
                          (TaeraeNode node) =>
                              '${node.id} ${node.labels.join(',')}',
                        )
                        .join('\n'),
                  ),
                  const SizedBox(height: 12),
                  Text('Edges (${edges.length})'),
                  Text(
                    edges
                        .map(
                          (TaeraeEdge edge) =>
                              '${edge.id}: ${edge.from} -[${edge.type ?? 'EDGE'}]-> ${edge.to}',
                        )
                        .join('\n'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
