import '_taerae_utils.dart';

/// Immutable directed graph edge.
class TaeraeEdge {
  /// Creates a [TaeraeEdge] between [from] and [to].
  TaeraeEdge({
    required String id,
    required String from,
    required String to,
    this.type,
    Map<String, Object?> properties = const <String, Object?>{},
  }) : id = requireNonEmpty(id, 'id'),
       from = requireNonEmpty(from, 'from'),
       to = requireNonEmpty(to, 'to'),
       properties = freezeProperties(properties);

  /// Creates a [TaeraeEdge] from JSON.
  factory TaeraeEdge.fromJson(Map<String, Object?> json) {
    return TaeraeEdge(
      id: readRequiredString(json, 'id'),
      from: readRequiredString(json, 'from'),
      to: readRequiredString(json, 'to'),
      type: readOptionalString(json, 'type'),
      properties: readPropertiesMap(json),
    );
  }

  /// Stable edge identifier.
  final String id;

  /// Source node identifier.
  final String from;

  /// Target node identifier.
  final String to;

  /// Optional edge type.
  final String? type;

  /// Arbitrary edge properties.
  final Map<String, Object?> properties;

  /// Returns a copy with selected fields replaced.
  TaeraeEdge copyWith({
    String? from,
    String? to,
    String? type,
    Map<String, Object?>? properties,
  }) {
    return TaeraeEdge(
      id: id,
      from: from ?? this.from,
      to: to ?? this.to,
      type: type ?? this.type,
      properties: properties ?? this.properties,
    );
  }

  /// Serializes the edge into a JSON-safe map.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'from': from,
      'to': to,
      'type': type,
      'properties': properties,
    };
  }
}
