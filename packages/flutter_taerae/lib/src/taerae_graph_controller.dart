import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:taerae_core/taerae_core.dart';

/// ChangeNotifier-based controller for managing a [TaeraeGraph].
class TaeraeGraphController extends ChangeNotifier {
  /// Creates a controller with an optional initial graph.
  ///
  /// The provided graph is copied to keep controller mutations isolated.
  TaeraeGraphController({TaeraeGraph? graph})
    : _graph = graph?.copy() ?? TaeraeGraph();

  /// Creates a controller from a serialized graph payload.
  factory TaeraeGraphController.fromJson(Map<String, Object?> json) {
    return TaeraeGraphController(graph: TaeraeGraph.fromJson(json));
  }

  TaeraeGraph _graph;
  List<TaeraeNode>? _cachedNodes;
  List<TaeraeEdge>? _cachedEdges;

  /// Immutable copy of the underlying graph.
  TaeraeGraph get graph => _graph.copy();

  /// Current nodes sorted by id.
  List<TaeraeNode> get nodes => _cachedNodes ??= _readNodes(_graph.toJson());

  /// Current edges sorted by id.
  List<TaeraeEdge> get edges => _cachedEdges ??= _readEdges(_graph.toJson());

  /// Whether a node with [id] exists.
  bool containsNode(String id) => _graph.containsNode(id);

  /// Whether an edge with [id] exists.
  bool containsEdge(String id) => _graph.containsEdge(id);

  /// Returns a node by [id], or `null`.
  TaeraeNode? nodeById(String id) => _graph.nodeById(id);

  /// Returns an edge by [id], or `null`.
  TaeraeEdge? edgeById(String id) => _graph.edgeById(id);

  /// Returns outgoing edges for [nodeId].
  List<TaeraeEdge> outgoing(String nodeId, {String? type}) {
    return _graph.outgoing(nodeId, type: type);
  }

  /// Returns incoming edges for [nodeId].
  List<TaeraeEdge> incoming(String nodeId, {String? type}) {
    return _graph.incoming(nodeId, type: type);
  }

  /// Returns neighboring nodes for [nodeId].
  List<TaeraeNode> neighbors(
    String nodeId, {
    String? type,
    bool bothDirections = true,
  }) {
    return _graph.neighbors(nodeId, type: type, bothDirections: bothDirections);
  }

  /// Returns all nodes that contain [label].
  List<TaeraeNode> nodesByLabel(String label) => _graph.nodesByLabel(label);

  /// Returns all nodes where [key] matches [value].
  List<TaeraeNode> nodesWhereProperty(String key, Object? value) {
    return _graph.nodesWhereProperty(key, value);
  }

  /// Finds shortest directed path from [startId] to [endId] using BFS.
  List<String>? shortestPathBfs(
    String startId,
    String endId, {
    String? edgeType,
  }) {
    return _graph.shortestPathBfs(startId, endId, edgeType: edgeType);
  }

  /// Inserts or updates a node and notifies listeners.
  TaeraeNode upsertNode(
    String id, {
    Iterable<String>? labels,
    Map<String, Object?>? properties,
  }) {
    final TaeraeNode node = _graph.upsertNode(
      id,
      labels: labels,
      properties: properties,
    );
    _invalidateDerivedCaches();
    notifyListeners();
    return node;
  }

  /// Removes a node and notifies listeners when removed.
  bool removeNode(String id) {
    final bool removed = _graph.removeNode(id);
    if (removed) {
      _invalidateDerivedCaches();
      notifyListeners();
    }
    return removed;
  }

  /// Inserts or updates an edge and notifies listeners.
  TaeraeEdge upsertEdge(
    String id,
    String from,
    String to, {
    String? type,
    Map<String, Object?>? properties,
  }) {
    final TaeraeEdge edge = _graph.upsertEdge(
      id,
      from,
      to,
      type: type,
      properties: properties,
    );
    _invalidateDerivedCaches();
    notifyListeners();
    return edge;
  }

  /// Removes an edge and notifies listeners when removed.
  bool removeEdge(String id) {
    final bool removed = _graph.removeEdge(id);
    if (removed) {
      _invalidateDerivedCaches();
      notifyListeners();
    }
    return removed;
  }

  /// Clears the graph and notifies listeners when data existed.
  void clear() {
    final Map<String, Object?> snapshot = _graph.toJson();
    final Object? rawNodes = snapshot['nodes'];
    final Object? rawEdges = snapshot['edges'];
    final bool hasData =
        (rawNodes is List<Object?> && rawNodes.isNotEmpty) ||
        (rawEdges is List<Object?> && rawEdges.isNotEmpty);
    if (!hasData) {
      return;
    }

    _graph.clear();
    _invalidateDerivedCaches();
    notifyListeners();
  }

  /// Replaces the current graph and notifies listeners.
  void replaceGraph(TaeraeGraph graph) {
    _graph = graph.copy();
    _invalidateDerivedCaches();
    notifyListeners();
  }

  /// Exports the graph to JSON.
  Map<String, Object?> exportToJson() => _graph.toJson();

  /// Exports the graph as a JSON string.
  String exportToJsonString({bool pretty = false}) {
    final Map<String, Object?> json = exportToJson();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(json);
    }
    return jsonEncode(json);
  }

  /// Imports graph state from JSON and notifies listeners.
  void importFromJson(Map<String, Object?> json) {
    _graph = TaeraeGraph.fromJson(json);
    _invalidateDerivedCaches();
    notifyListeners();
  }

  /// Imports graph state from a JSON string and notifies listeners.
  void importFromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    importFromJson(_readJsonMap(decoded, 'source'));
  }

  void _invalidateDerivedCaches() {
    _cachedNodes = null;
    _cachedEdges = null;
  }

  static List<TaeraeNode> _readNodes(Map<String, Object?> json) {
    final Object? rawNodes = json['nodes'];
    if (rawNodes is! List<Object?>) {
      return const <TaeraeNode>[];
    }

    final List<TaeraeNode> nodes = <TaeraeNode>[];
    for (int index = 0; index < rawNodes.length; index++) {
      nodes.add(TaeraeNode.fromJson(_readJsonMap(rawNodes[index], 'nodes')));
    }
    return List<TaeraeNode>.unmodifiable(nodes);
  }

  static List<TaeraeEdge> _readEdges(Map<String, Object?> json) {
    final Object? rawEdges = json['edges'];
    if (rawEdges is! List<Object?>) {
      return const <TaeraeEdge>[];
    }

    final List<TaeraeEdge> edges = <TaeraeEdge>[];
    for (int index = 0; index < rawEdges.length; index++) {
      edges.add(TaeraeEdge.fromJson(_readJsonMap(rawEdges[index], 'edges')));
    }
    return List<TaeraeEdge>.unmodifiable(edges);
  }

  static Map<String, Object?> _readJsonMap(Object? value, String key) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected "$key" to be a JSON object.');
    }

    final Map<String, Object?> map = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      map[entry.key as String] = entry.value;
    }
    return map;
  }
}
