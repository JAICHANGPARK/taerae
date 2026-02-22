import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

void main() {
  runApp(const TaeraeCrudExampleApp());
}

class TaeraeCrudExampleApp extends StatelessWidget {
  const TaeraeCrudExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const GraphCrudHomePage(),
    );
  }
}

class GraphCrudHomePage extends StatefulWidget {
  const GraphCrudHomePage({super.key});

  @override
  State<GraphCrudHomePage> createState() => _GraphCrudHomePageState();
}

class _GraphCrudHomePageState extends State<GraphCrudHomePage> {
  final TaeraeFlutter _plugin = TaeraeFlutter();
  final TaeraeGraphController _controller = TaeraeGraphController();

  final TextEditingController _nodeIdController = TextEditingController();
  final TextEditingController _nodeLabelsController = TextEditingController();
  final TextEditingController _nodePropertiesController =
      TextEditingController();

  final TextEditingController _edgeIdController = TextEditingController();
  final TextEditingController _edgeFromController = TextEditingController();
  final TextEditingController _edgeToController = TextEditingController();
  final TextEditingController _edgeTypeController = TextEditingController();
  final TextEditingController _edgePropertiesController =
      TextEditingController();

  final TextEditingController _searchNodeIdController = TextEditingController();
  final TextEditingController _searchLabelController = TextEditingController();
  final TextEditingController _searchPropertyKeyController =
      TextEditingController();
  final TextEditingController _searchPropertyValueController =
      TextEditingController();

  String _platformVersion = 'loading...';
  String _status = 'Ready';

  bool _searchActive = false;
  String _searchSummary = 'No search executed.';
  List<TaeraeNode> _searchResults = const <TaeraeNode>[];
  String _searchNodeId = '';
  String _searchLabel = '';
  String _searchPropertyKey = '';
  Object? _searchPropertyValue;
  bool _searchPropertyHasValue = false;

  @override
  void initState() {
    super.initState();
    _seedGraph();
    unawaited(_loadPlatformVersion());
  }

  @override
  void dispose() {
    _nodeIdController.dispose();
    _nodeLabelsController.dispose();
    _nodePropertiesController.dispose();
    _edgeIdController.dispose();
    _edgeFromController.dispose();
    _edgeToController.dispose();
    _edgeTypeController.dispose();
    _edgePropertiesController.dispose();
    _searchNodeIdController.dispose();
    _searchLabelController.dispose();
    _searchPropertyKeyController.dispose();
    _searchPropertyValueController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _seedGraph() {
    _controller
      ..upsertNode(
        'alice',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'Alice', 'team': 'core'},
      )
      ..upsertNode(
        'bob',
        labels: const <String>['Person'],
        properties: const <String, Object?>{'name': 'Bob', 'team': 'flutter'},
      )
      ..upsertNode(
        'seoul',
        labels: const <String>['City'],
        properties: const <String, Object?>{'name': 'Seoul', 'country': 'KR'},
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

  void _upsertNode() {
    final String id = _nodeIdController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _status = 'Node id is required.';
      });
      return;
    }

    try {
      final bool existed = _controller.containsNode(id);
      _controller.upsertNode(
        id,
        labels: _parseOptionalLabels(_nodeLabelsController.text),
        properties: _parseOptionalProperties(_nodePropertiesController.text),
      );

      setState(() {
        _status = existed ? 'Updated node "$id".' : 'Created node "$id".';
        _refreshSearchResultsIfNeeded();
      });
    } on FormatException catch (error) {
      setState(() {
        _status = 'Invalid node properties JSON: ${error.message}';
      });
    }
  }

  void _deleteNode() {
    final String id = _nodeIdController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _status = 'Enter node id to delete.';
      });
      return;
    }

    final bool removed = _controller.removeNode(id);
    setState(() {
      _status = removed ? 'Deleted node "$id".' : 'Node "$id" not found.';
      _refreshSearchResultsIfNeeded();
    });
  }

  void _loadNodeToEditor(TaeraeNode node) {
    _nodeIdController.text = node.id;
    _nodeLabelsController.text = node.labels.join(', ');
    _nodePropertiesController.text = _jsonEncodeSafely(node.properties);
    setState(() {
      _status = 'Loaded node "${node.id}" for editing.';
    });
  }

  void _clearNodeEditor() {
    _nodeIdController.clear();
    _nodeLabelsController.clear();
    _nodePropertiesController.clear();
    setState(() {
      _status = 'Node editor cleared.';
    });
  }

  void _upsertEdge() {
    final String id = _edgeIdController.text.trim();
    final String from = _edgeFromController.text.trim();
    final String to = _edgeToController.text.trim();
    if (id.isEmpty || from.isEmpty || to.isEmpty) {
      setState(() {
        _status = 'Edge id, from, to are required.';
      });
      return;
    }

    try {
      final bool existed = _controller.containsEdge(id);
      final String? type = _edgeTypeController.text.trim().isEmpty
          ? null
          : _edgeTypeController.text.trim();
      _controller.upsertEdge(
        id,
        from,
        to,
        type: type,
        properties: _parseOptionalProperties(_edgePropertiesController.text),
      );
      setState(() {
        _status = existed ? 'Updated edge "$id".' : 'Created edge "$id".';
        _refreshSearchResultsIfNeeded();
      });
    } on FormatException catch (error) {
      setState(() {
        _status = 'Invalid edge properties JSON: ${error.message}';
      });
    } on StateError catch (error) {
      setState(() {
        _status = 'Cannot create edge: $error';
      });
    }
  }

  void _deleteEdge() {
    final String id = _edgeIdController.text.trim();
    if (id.isEmpty) {
      setState(() {
        _status = 'Enter edge id to delete.';
      });
      return;
    }

    final bool removed = _controller.removeEdge(id);
    setState(() {
      _status = removed ? 'Deleted edge "$id".' : 'Edge "$id" not found.';
      _refreshSearchResultsIfNeeded();
    });
  }

  void _loadEdgeToEditor(TaeraeEdge edge) {
    _edgeIdController.text = edge.id;
    _edgeFromController.text = edge.from;
    _edgeToController.text = edge.to;
    _edgeTypeController.text = edge.type ?? '';
    _edgePropertiesController.text = _jsonEncodeSafely(edge.properties);
    setState(() {
      _status = 'Loaded edge "${edge.id}" for editing.';
    });
  }

  void _clearEdgeEditor() {
    _edgeIdController.clear();
    _edgeFromController.clear();
    _edgeToController.clear();
    _edgeTypeController.clear();
    _edgePropertiesController.clear();
    setState(() {
      _status = 'Edge editor cleared.';
    });
  }

  void _runSearch() {
    final String nodeId = _searchNodeIdController.text.trim();
    final String label = _searchLabelController.text.trim();
    final String propertyKey = _searchPropertyKeyController.text.trim();
    final String propertyValueInput = _searchPropertyValueController.text
        .trim();

    if (nodeId.isEmpty && label.isEmpty && propertyKey.isEmpty) {
      setState(() {
        _searchActive = false;
        _searchResults = const <TaeraeNode>[];
        _searchSummary =
            'No filters entered. Use id, label, or property key/value.';
        _status = 'Search filters are empty.';
      });
      return;
    }

    try {
      setState(() {
        _searchNodeId = nodeId;
        _searchLabel = label;
        _searchPropertyKey = propertyKey;
        _searchPropertyHasValue = propertyValueInput.isNotEmpty;
        _searchPropertyValue = _searchPropertyHasValue
            ? _parseSearchPropertyValue(propertyValueInput)
            : null;
        _searchActive = true;
        _searchResults = _executeActiveSearch();
        _searchSummary = _buildSearchSummary(_searchResults.length);
        _status = 'Search executed.';
      });
    } on FormatException catch (error) {
      setState(() {
        _status = 'Invalid search value: ${error.message}';
      });
    }
  }

  void _clearSearch() {
    _searchNodeIdController.clear();
    _searchLabelController.clear();
    _searchPropertyKeyController.clear();
    _searchPropertyValueController.clear();
    setState(() {
      _searchActive = false;
      _searchSummary = 'Search reset.';
      _searchResults = const <TaeraeNode>[];
      _searchNodeId = '';
      _searchLabel = '';
      _searchPropertyKey = '';
      _searchPropertyHasValue = false;
      _searchPropertyValue = null;
      _status = 'Search filters reset.';
    });
  }

  void _refreshSearchResultsIfNeeded() {
    if (!_searchActive) {
      return;
    }

    _searchResults = _executeActiveSearch();
    _searchSummary = _buildSearchSummary(_searchResults.length);
  }

  List<TaeraeNode> _executeActiveSearch() {
    Iterable<TaeraeNode> results = _controller.nodes;

    if (_searchNodeId.isNotEmpty) {
      results = results.where((TaeraeNode node) => node.id == _searchNodeId);
    }

    if (_searchLabel.isNotEmpty) {
      results = results.where(
        (TaeraeNode node) => node.labels.contains(_searchLabel),
      );
    }

    if (_searchPropertyKey.isNotEmpty) {
      if (_searchPropertyHasValue) {
        final Object? expected = _searchPropertyValue;
        results = results.where((TaeraeNode node) {
          if (!node.properties.containsKey(_searchPropertyKey)) {
            return false;
          }
          return _jsonLikeEquals(node.properties[_searchPropertyKey], expected);
        });
      } else {
        results = results.where(
          (TaeraeNode node) => node.properties.containsKey(_searchPropertyKey),
        );
      }
    }

    return results.toList(growable: false);
  }

  String _buildSearchSummary(int count) {
    final List<String> filters = <String>[];
    if (_searchNodeId.isNotEmpty) {
      filters.add('id=$_searchNodeId');
    }
    if (_searchLabel.isNotEmpty) {
      filters.add('label=$_searchLabel');
    }
    if (_searchPropertyKey.isNotEmpty) {
      if (_searchPropertyHasValue) {
        filters.add(
          '$_searchPropertyKey=${_jsonEncodeSafely(_searchPropertyValue)}',
        );
      } else {
        filters.add('has($_searchPropertyKey)');
      }
    }

    final String description = filters.isEmpty ? 'none' : filters.join(', ');
    return 'Found $count node(s) for filters: $description';
  }

  Iterable<String>? _parseOptionalLabels(String raw) {
    final List<String> labels = raw
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (labels.isEmpty) {
      return null;
    }
    return labels.toSet().toList(growable: false);
  }

  Map<String, Object?>? _parseOptionalProperties(String raw) {
    final String source = raw.trim();
    if (source.isEmpty) {
      return null;
    }

    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Expected JSON object, e.g. {"key":"value"}.',
      );
    }
    final Map<String, Object?> parsed = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in decoded.entries) {
      final Object? key = entry.key;
      if (key is! String || key.isEmpty) {
        throw const FormatException('Property keys must be non-empty strings.');
      }
      parsed[key] = entry.value;
    }
    return parsed;
  }

  Object? _parseSearchPropertyValue(String raw) {
    final String value = raw.trim();
    if (value == 'null') {
      return null;
    }
    if (value == 'true') {
      return true;
    }
    if (value == 'false') {
      return false;
    }
    final num? asNumber = num.tryParse(value);
    if (asNumber != null) {
      return asNumber;
    }
    final bool looksLikeJson =
        (value.startsWith('{') && value.endsWith('}')) ||
        (value.startsWith('[') && value.endsWith(']')) ||
        (value.startsWith('"') && value.endsWith('"'));
    if (looksLikeJson) {
      return jsonDecode(value);
    }
    return value;
  }

  bool _jsonLikeEquals(Object? left, Object? right) {
    if (left is List<Object?> && right is List<Object?>) {
      if (left.length != right.length) {
        return false;
      }
      for (int i = 0; i < left.length; i++) {
        if (!_jsonLikeEquals(left[i], right[i])) {
          return false;
        }
      }
      return true;
    }

    if (left is Map<Object?, Object?> && right is Map<Object?, Object?>) {
      if (left.length != right.length) {
        return false;
      }
      for (final MapEntry<Object?, Object?> entry in left.entries) {
        if (!right.containsKey(entry.key)) {
          return false;
        }
        if (!_jsonLikeEquals(entry.value, right[entry.key])) {
          return false;
        }
      }
      return true;
    }

    return left == right;
  }

  String _jsonEncodeSafely(Object? value) {
    try {
      return jsonEncode(value);
    } on JsonUnsupportedObjectError {
      return '$value';
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: 320,
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildOverview(List<TaeraeNode> nodes, List<TaeraeEdge> edges) {
    final List<String>? path = _controller.shortestPathBfs('alice', 'seoul');
    return _SectionCard(
      title: 'Overview',
      description: 'Graph status and quick sanity check.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Platform: $_platformVersion'),
          const SizedBox(height: 4),
          Text('Nodes: ${nodes.length}'),
          Text('Edges: ${edges.length}'),
          const SizedBox(height: 4),
          Text('Path alice -> seoul: ${path?.join(' -> ') ?? 'not found'}'),
          const SizedBox(height: 8),
          Text('Status: $_status'),
        ],
      ),
    );
  }

  Widget _buildNodeCrud() {
    return _SectionCard(
      title: 'Node CRUD',
      description: 'Create, search, update, and delete graph nodes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildInputField(
                controller: _nodeIdController,
                label: 'Node id',
                hint: 'alice',
              ),
              _buildInputField(
                controller: _nodeLabelsController,
                label: 'Labels (comma separated)',
                hint: 'Person, Employee',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _nodePropertiesController,
            label: 'Properties (JSON object)',
            hint: '{"name":"Alice","team":"core"}',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _upsertNode,
                child: const Text('Upsert Node'),
              ),
              FilledButton.tonal(
                onPressed: _deleteNode,
                child: const Text('Delete Node'),
              ),
              OutlinedButton(
                onPressed: _clearNodeEditor,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return _SectionCard(
      title: 'Node Search',
      description:
          'Filter by id, label, and property. Leave property value empty to find nodes that only contain the key.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildInputField(
                controller: _searchNodeIdController,
                label: 'Search by node id',
                hint: 'alice',
              ),
              _buildInputField(
                controller: _searchLabelController,
                label: 'Search by label',
                hint: 'Person',
              ),
              _buildInputField(
                controller: _searchPropertyKeyController,
                label: 'Property key',
                hint: 'team',
              ),
              _buildInputField(
                controller: _searchPropertyValueController,
                label: 'Property value',
                hint: '"core", 42, true, null, {"k":"v"}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _runSearch,
                child: const Text('Run Search'),
              ),
              OutlinedButton(
                onPressed: _clearSearch,
                child: const Text('Clear Search'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_searchSummary),
          if (_searchActive) ...<Widget>[
            const SizedBox(height: 8),
            if (_searchResults.isEmpty)
              const Text('No matching nodes.')
            else
              Column(
                children: _searchResults
                    .map((TaeraeNode node) {
                      return Card(
                        child: ListTile(
                          title: Text(node.id),
                          subtitle: Text(
                            'labels=${node.labels.join(', ')}\n'
                            'properties=${_jsonEncodeSafely(node.properties)}',
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: 'Load into node editor',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _loadNodeToEditor(node),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildEdgeCrud() {
    return _SectionCard(
      title: 'Edge CRUD',
      description: 'Create, edit, and delete relations between nodes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildInputField(
                controller: _edgeIdController,
                label: 'Edge id',
                hint: 'knows_alice_bob',
              ),
              _buildInputField(
                controller: _edgeFromController,
                label: 'From node id',
                hint: 'alice',
              ),
              _buildInputField(
                controller: _edgeToController,
                label: 'To node id',
                hint: 'bob',
              ),
              _buildInputField(
                controller: _edgeTypeController,
                label: 'Edge type',
                hint: 'KNOWS',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _edgePropertiesController,
            label: 'Properties (JSON object)',
            hint: '{"weight": 0.8}',
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: _upsertEdge,
                child: const Text('Upsert Edge'),
              ),
              FilledButton.tonal(
                onPressed: _deleteEdge,
                child: const Text('Delete Edge'),
              ),
              OutlinedButton(
                onPressed: _clearEdgeEditor,
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphSnapshot(List<TaeraeNode> nodes, List<TaeraeEdge> edges) {
    return _SectionCard(
      title: 'Current Graph',
      description:
          'Tap edit to load into form. Delete buttons apply immediately.',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: <Widget>[
          SizedBox(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Nodes (${nodes.length})'),
                const SizedBox(height: 8),
                if (nodes.isEmpty)
                  const Text('No nodes yet.')
                else
                  Column(
                    children: nodes
                        .map((TaeraeNode node) {
                          return Card(
                            child: ListTile(
                              title: Text(node.id),
                              subtitle: Text(
                                'labels=${node.labels.join(', ')}\n'
                                'properties=${_jsonEncodeSafely(node.properties)}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Edit node',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _loadNodeToEditor(node),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete node',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      _controller.removeNode(node.id);
                                      setState(() {
                                        _status = 'Deleted node "${node.id}".';
                                        _refreshSearchResultsIfNeeded();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 500,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Edges (${edges.length})'),
                const SizedBox(height: 8),
                if (edges.isEmpty)
                  const Text('No edges yet.')
                else
                  Column(
                    children: edges
                        .map((TaeraeEdge edge) {
                          return Card(
                            child: ListTile(
                              title: Text(edge.id),
                              subtitle: Text(
                                '${edge.from} -[${edge.type ?? 'EDGE'}]-> ${edge.to}\n'
                                'properties=${_jsonEncodeSafely(edge.properties)}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Edit edge',
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _loadEdgeToEditor(edge),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete edge',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () {
                                      _controller.removeEdge(edge.id);
                                      setState(() {
                                        _status = 'Deleted edge "${edge.id}".';
                                        _refreshSearchResultsIfNeeded();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taerae CRUD Example')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final List<TaeraeNode> nodes = _controller.nodes;
          final List<TaeraeEdge> edges = _controller.edges;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildOverview(nodes, edges),
                _buildNodeCrud(),
                _buildSearchPanel(),
                _buildEdgeCrud(),
                _buildGraphSnapshot(nodes, edges),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
