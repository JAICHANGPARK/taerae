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
  ///
  /// When [tolerateIncompleteTrailingLine] is `true`, a malformed final line is
  /// ignored only when the file does not end with a line terminator. This is
  /// useful for crash-truncated appends.
  Future<int> replayInto(
    TaeraeGraph graph, {
    bool tolerateIncompleteTrailingLine = false,
  }) async {
    int replayedCount = 0;
    await for (final TaeraeGraphOperation operation in _operationStream(
      tolerateIncompleteTrailingLine: tolerateIncompleteTrailingLine,
    )) {
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

  Stream<TaeraeGraphOperation> _operationStream({
    bool tolerateIncompleteTrailingLine = false,
  }) async* {
    if (!await file.exists()) {
      return;
    }

    final bool endsWithLineTerminator = await _endsWithLineTerminator();
    final Stream<String> lines = file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    int lineNumber = 0;
    String? pendingLine;
    int pendingLineNumber = 0;
    await for (final String rawLine in lines) {
      lineNumber += 1;
      if (pendingLine != null) {
        final TaeraeGraphOperation? operation = _parseOperationLine(
          pendingLine,
          lineNumber: pendingLineNumber,
        );
        if (operation != null) {
          yield operation;
        }
      }

      pendingLine = rawLine;
      pendingLineNumber = lineNumber;
    }

    if (pendingLine == null) {
      return;
    }

    final TaeraeGraphOperation? trailingOperation = _parseOperationLine(
      pendingLine,
      lineNumber: pendingLineNumber,
      tolerateMalformedTrailingLine:
          tolerateIncompleteTrailingLine && !endsWithLineTerminator,
    );
    if (trailingOperation != null) {
      yield trailingOperation;
    }
  }

  Future<bool> _endsWithLineTerminator() async {
    final int length = await file.length();
    if (length == 0) {
      return true;
    }

    final RandomAccessFile handle = await file.open(mode: FileMode.read);
    try {
      await handle.setPosition(length - 1);
      final List<int> lastByte = await handle.read(1);
      if (lastByte.isEmpty) {
        return true;
      }
      final int codeUnit = lastByte.first;
      return codeUnit == 0x0A || codeUnit == 0x0D;
    } finally {
      await handle.close();
    }
  }

  TaeraeGraphOperation? _parseOperationLine(
    String rawLine, {
    required int lineNumber,
    bool tolerateMalformedTrailingLine = false,
  }) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      return null;
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      if (tolerateMalformedTrailingLine) {
        return null;
      }
      rethrow;
    }

    return TaeraeGraphOperation.fromJson(
      _readJsonMap(decoded, 'log line $lineNumber'),
    );
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
