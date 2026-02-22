import 'dart:convert';
import 'dart:io';

import '../taerae_graph.dart';

/// Snapshot read/write utility for graph persistence.
class TaeraeGraphSnapshotStore {
  /// Creates a snapshot store backed by [file].
  TaeraeGraphSnapshotStore(this.file);

  static const String _format = 'taerae.snapshot.v1';

  /// Snapshot file path.
  final File file;

  /// Writes a full graph snapshot to disk.
  Future<void> write(TaeraeGraph graph, {bool atomicWrite = true}) async {
    await file.parent.create(recursive: true);

    final Map<String, Object?> payload = <String, Object?>{
      'format': _format,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'graph': graph.toJson(),
    };

    final String content = jsonEncode(payload);
    if (!atomicWrite) {
      await file.writeAsString(content, flush: true);
      return;
    }

    final File tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(content, flush: true);

    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  /// Reads a snapshot from disk or returns an empty graph if missing.
  Future<TaeraeGraph> readOrEmpty() async {
    if (!await file.exists()) {
      return TaeraeGraph();
    }

    final String source = (await file.readAsString()).trim();
    if (source.isEmpty) {
      return TaeraeGraph();
    }

    final Map<String, Object?> root = _readJsonMap(jsonDecode(source), 'root');

    // Backward compatibility: accept raw graph JSON.
    if (root.containsKey('nodes') || root.containsKey('edges')) {
      return TaeraeGraph.fromJson(root);
    }

    final Object? format = root['format'];
    if (format != _format) {
      throw FormatException('Unsupported snapshot format "$format".');
    }

    return TaeraeGraph.fromJson(_readJsonMap(root['graph'], 'graph'));
  }

  static Map<String, Object?> _readJsonMap(Object? value, String fieldName) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected "$fieldName" to be a JSON object.');
    }

    final Map<String, Object?> map = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final Object? key = entry.key;
      if (key is! String || key.isEmpty) {
        throw FormatException(
          'Expected keys in "$fieldName" to be non-empty strings.',
        );
      }
      map[key] = entry.value;
    }
    return map;
  }
}
