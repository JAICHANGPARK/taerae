import '../taerae_edge.dart';
import '../taerae_graph.dart';
import '../taerae_node.dart';

/// Operation kinds persisted in the append-only graph log.
enum TaeraeGraphOperationType {
  /// Insert or update a node.
  upsertNode,

  /// Remove a node.
  removeNode,

  /// Insert or update an edge.
  upsertEdge,

  /// Remove an edge.
  removeEdge,

  /// Remove all graph data.
  clear,
}

/// Serializable graph mutation operation for append-only persistence.
class TaeraeGraphOperation {
  const TaeraeGraphOperation._({
    required this.type,
    this.node,
    this.edge,
    this.id,
  });

  /// Creates an upsert-node operation.
  factory TaeraeGraphOperation.upsertNode(TaeraeNode node) {
    return TaeraeGraphOperation._(
      type: TaeraeGraphOperationType.upsertNode,
      node: node,
    );
  }

  /// Creates a remove-node operation.
  factory TaeraeGraphOperation.removeNode(String id) {
    return TaeraeGraphOperation._(
      type: TaeraeGraphOperationType.removeNode,
      id: id,
    );
  }

  /// Creates an upsert-edge operation.
  factory TaeraeGraphOperation.upsertEdge(TaeraeEdge edge) {
    return TaeraeGraphOperation._(
      type: TaeraeGraphOperationType.upsertEdge,
      edge: edge,
    );
  }

  /// Creates a remove-edge operation.
  factory TaeraeGraphOperation.removeEdge(String id) {
    return TaeraeGraphOperation._(
      type: TaeraeGraphOperationType.removeEdge,
      id: id,
    );
  }

  /// Creates a clear-graph operation.
  const factory TaeraeGraphOperation.clear() = _ClearTaeraeGraphOperation;

  /// Parses an operation from JSON.
  factory TaeraeGraphOperation.fromJson(Map<String, Object?> json) {
    final Object? op = json['op'];
    if (op is! String || op.isEmpty) {
      throw FormatException('Expected "op" to be a non-empty string.');
    }

    switch (op) {
      case 'upsert_node':
        return TaeraeGraphOperation.upsertNode(
          TaeraeNode.fromJson(_readJsonMap(json['node'], 'node')),
        );
      case 'remove_node':
        return TaeraeGraphOperation.removeNode(_readRequiredId(json, 'id'));
      case 'upsert_edge':
        return TaeraeGraphOperation.upsertEdge(
          TaeraeEdge.fromJson(_readJsonMap(json['edge'], 'edge')),
        );
      case 'remove_edge':
        return TaeraeGraphOperation.removeEdge(_readRequiredId(json, 'id'));
      case 'clear':
        return const TaeraeGraphOperation.clear();
      default:
        throw FormatException('Unknown graph operation "$op".');
    }
  }

  /// Operation kind.
  final TaeraeGraphOperationType type;

  /// Node payload for [TaeraeGraphOperationType.upsertNode].
  final TaeraeNode? node;

  /// Edge payload for [TaeraeGraphOperationType.upsertEdge].
  final TaeraeEdge? edge;

  /// Identifier payload for remove operations.
  final String? id;

  /// Applies this operation to [graph].
  void applyTo(TaeraeGraph graph) {
    switch (type) {
      case TaeraeGraphOperationType.upsertNode:
        final TaeraeNode currentNode = _requireNode(node, type);
        graph.upsertNode(
          currentNode.id,
          labels: currentNode.labels,
          properties: currentNode.properties,
        );
      case TaeraeGraphOperationType.removeNode:
        graph.removeNode(_requireId(id, type));
      case TaeraeGraphOperationType.upsertEdge:
        final TaeraeEdge currentEdge = _requireEdge(edge, type);
        graph.upsertEdge(
          currentEdge.id,
          currentEdge.from,
          currentEdge.to,
          type: currentEdge.type,
          properties: currentEdge.properties,
        );
      case TaeraeGraphOperationType.removeEdge:
        graph.removeEdge(_requireId(id, type));
      case TaeraeGraphOperationType.clear:
        graph.clear();
    }
  }

  /// Serializes the operation.
  Map<String, Object?> toJson() {
    switch (type) {
      case TaeraeGraphOperationType.upsertNode:
        return <String, Object?>{
          'op': 'upsert_node',
          'node': _requireNode(node, type).toJson(),
        };
      case TaeraeGraphOperationType.removeNode:
        return <String, Object?>{
          'op': 'remove_node',
          'id': _requireId(id, type),
        };
      case TaeraeGraphOperationType.upsertEdge:
        return <String, Object?>{
          'op': 'upsert_edge',
          'edge': _requireEdge(edge, type).toJson(),
        };
      case TaeraeGraphOperationType.removeEdge:
        return <String, Object?>{
          'op': 'remove_edge',
          'id': _requireId(id, type),
        };
      case TaeraeGraphOperationType.clear:
        return const <String, Object?>{'op': 'clear'};
    }
  }

  static TaeraeNode _requireNode(
    TaeraeNode? value,
    TaeraeGraphOperationType type,
  ) {
    if (value == null) {
      throw StateError('Missing node payload for operation "$type".');
    }
    return value;
  }

  static TaeraeEdge _requireEdge(
    TaeraeEdge? value,
    TaeraeGraphOperationType type,
  ) {
    if (value == null) {
      throw StateError('Missing edge payload for operation "$type".');
    }
    return value;
  }

  static String _requireId(String? value, TaeraeGraphOperationType type) {
    if (value == null || value.isEmpty) {
      throw StateError('Missing id payload for operation "$type".');
    }
    return value;
  }

  static String _readRequiredId(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Expected "$key" to be a non-empty string.');
    }
    return value;
  }

  static Map<String, Object?> _readJsonMap(Object? value, String key) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected "$key" to be an object.');
    }

    final Map<String, Object?> map = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final Object? rawKey = entry.key;
      if (rawKey is! String || rawKey.isEmpty) {
        throw FormatException('Expected "$key" keys to be non-empty strings.');
      }
      map[rawKey] = entry.value;
    }
    return map;
  }
}

class _ClearTaeraeGraphOperation extends TaeraeGraphOperation {
  const _ClearTaeraeGraphOperation()
    : super._(type: TaeraeGraphOperationType.clear);
}
