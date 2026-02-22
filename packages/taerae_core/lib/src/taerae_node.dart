import '_taerae_utils.dart';

/// Immutable graph node.
class TaeraeNode {
  /// Creates a [TaeraeNode] with optional labels and properties.
  TaeraeNode({
    required String id,
    Iterable<String> labels = const <String>[],
    Map<String, Object?> properties = const <String, Object?>{},
  }) : id = requireNonEmpty(id, 'id'),
       labels = Set<String>.unmodifiable(labels.toSet()),
       properties = freezeProperties(properties) {
    if (this.labels.any((String label) => label.isEmpty)) {
      throw ArgumentError.value(
        labels,
        'labels',
        'Labels must be non-empty strings.',
      );
    }
  }

  /// Creates a [TaeraeNode] from JSON.
  factory TaeraeNode.fromJson(Map<String, Object?> json) {
    return TaeraeNode(
      id: readRequiredString(json, 'id'),
      labels: readStringSet(json, 'labels'),
      properties: readPropertiesMap(json),
    );
  }

  /// Stable node identifier.
  final String id;

  /// Zero or more labels used for grouping.
  final Set<String> labels;

  /// Arbitrary node properties.
  final Map<String, Object?> properties;

  /// Returns a copy with selected fields replaced.
  TaeraeNode copyWith({
    Iterable<String>? labels,
    Map<String, Object?>? properties,
  }) {
    return TaeraeNode(
      id: id,
      labels: labels ?? this.labels,
      properties: properties ?? this.properties,
    );
  }

  /// Serializes the node into a JSON-safe map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'labels': labels.toList(growable: false),
      'properties': properties,
    };
  }
}
