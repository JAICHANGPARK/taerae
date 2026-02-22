import 'dart:convert';
import 'dart:io';

import '../taerae_graph.dart';
import 'taerae_graph_operation.dart';

/// Append-only NDJSON log for graph mutation operations.
class TaeraeGraphLog {
  /// Creates a log backed by [file].
  TaeraeGraphLog(this.file);

  /// Log file path.
  final File file;

  /// Ensures the parent directory and file exist.
  Future<void> ensureExists() async {
    await file.parent.create(recursive: true);
    if (!await file.exists()) {
      await file.writeAsString('', flush: true);
    }
  }

  /// Appends one operation to the end of the log.
  Future<void> append(
    TaeraeGraphOperation operation, {
    bool flush = true,
  }) async {
    await ensureExists();
    final String line = jsonEncode(operation.toJson());
    await file.writeAsString('$line\n', mode: FileMode.append, flush: flush);
  }

  /// Reads all logged operations in order.
  Future<List<TaeraeGraphOperation>> readAll() async {
    final List<TaeraeGraphOperation> operations = <TaeraeGraphOperation>[];
    await for (final TaeraeGraphOperation operation in _operationStream()) {
      operations.add(operation);
    }
    return List<TaeraeGraphOperation>.unmodifiable(operations);
  }

  /// Replays all operations into [graph] and returns replayed operation count.
  Future<int> replayInto(TaeraeGraph graph) async {
    int replayedCount = 0;
    await for (final TaeraeGraphOperation operation in _operationStream()) {
      operation.applyTo(graph);
      replayedCount += 1;
    }
    return replayedCount;
  }

  /// Truncates the log file.
  Future<void> truncate() async {
    await ensureExists();
    await file.writeAsString('', flush: true);
  }

  /// Flushes pending buffered writes to storage.
  Future<void> flush() async {
    await ensureExists();
    final RandomAccessFile handle = await file.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Stream<TaeraeGraphOperation> _operationStream() async* {
    if (!await file.exists()) {
      return;
    }

    final Stream<String> lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    int lineNumber = 0;
    await for (final String rawLine in lines) {
      lineNumber += 1;
      final String line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final Object? decoded = jsonDecode(line);
      yield TaeraeGraphOperation.fromJson(
        _readJsonMap(decoded, 'log line $lineNumber'),
      );
    }
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
