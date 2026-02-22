String requireNonEmpty(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(
      value,
      fieldName,
      '$fieldName must not be empty.',
    );
  }
  return value;
}

String readRequiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected "$key" to be a non-empty string.');
  }
  return value;
}

String? readOptionalString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('Expected "$key" to be a string.');
  }
  return value;
}

Set<String> readStringSet(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value == null) {
    return <String>{};
  }
  if (value is! Iterable<Object?>) {
    throw FormatException('Expected "$key" to be a list of strings.');
  }

  final Set<String> result = <String>{};
  for (final Object? item in value) {
    if (item is! String || item.isEmpty) {
      throw FormatException('Expected "$key" entries to be non-empty strings.');
    }
    result.add(item);
  }
  return result;
}

Map<String, Object?> readPropertiesMap(
  Map<String, Object?> json, {
  String key = 'properties',
}) {
  final Object? rawProperties = json[key];
  if (rawProperties == null) {
    return const <String, Object?>{};
  }
  return readStringKeyedMap(rawProperties, key);
}

Map<String, Object?> readStringKeyedMap(Object? source, String fieldName) {
  if (source is! Map<Object?, Object?>) {
    throw FormatException('Expected "$fieldName" to be an object.');
  }

  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in source.entries) {
    final Object? rawKey = entry.key;
    if (rawKey is! String || rawKey.isEmpty) {
      throw FormatException(
        'Expected "$fieldName" keys to be non-empty strings.',
      );
    }
    result[rawKey] = entry.value;
  }
  return result;
}

Map<String, Object?> freezeProperties(Map<String, Object?> source) {
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in source.entries) {
    result[entry.key] = freezeValue(entry.value);
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? freezeValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    final Map<Object?, Object?> frozen = <Object?, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      frozen[entry.key] = freezeValue(entry.value);
    }
    return Map<Object?, Object?>.unmodifiable(frozen);
  }

  if (value is Iterable<Object?>) {
    return List<Object?>.unmodifiable(value.map(freezeValue));
  }

  return value;
}
