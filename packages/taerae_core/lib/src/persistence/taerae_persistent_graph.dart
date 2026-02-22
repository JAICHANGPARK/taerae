import 'dart:io';

import '../taerae_edge.dart';
import '../taerae_graph.dart';
import '../taerae_node.dart';
import 'taerae_graph_log.dart';
import 'taerae_graph_operation.dart';
import 'taerae_graph_snapshot.dart';

/// Log flush strategy for append-only writes.
enum TaeraeLogFlushPolicy {
  /// Flush each write immediately.
  immediate,

  /// Flush every N operations.
  everyNOperations,

  /// Flush only during checkpoint.
  onCheckpoint,
}

/// Ordering policy for memory-vs-log mutation commit.
enum TaeraeWriteAtomicityPolicy {
  /// Write-ahead logging: append to log first, then mutate memory.
  writeAhead,

  /// Mutate memory first, then append to log.
  inMemoryFirst,
}

/// Durability settings for [TaeraePersistentGraph].
class TaeraeDurabilityOptions {
  /// Creates durability options.
  const TaeraeDurabilityOptions({
    this.logFlushPolicy = TaeraeLogFlushPolicy.immediate,
    this.flushEveryNOperations = 16,
    this.writeAtomicityPolicy = TaeraeWriteAtomicityPolicy.writeAhead,
    this.atomicSnapshotWrite = true,
  });

  /// Strategy for flushing log appends.
  final TaeraeLogFlushPolicy logFlushPolicy;

  /// N for [TaeraeLogFlushPolicy.everyNOperations].
  final int flushEveryNOperations;

  /// Ordering policy between WAL append and in-memory mutation.
  final TaeraeWriteAtomicityPolicy writeAtomicityPolicy;

  /// Whether snapshots are written atomically using temp-file + rename.
  final bool atomicSnapshotWrite;
}

/// File-backed graph wrapper using append-only logs plus periodic snapshots.
class TaeraePersistentGraph {
  TaeraePersistentGraph._({
    required this.directory,
    required TaeraeGraph graph,
    required TaeraeGraphLog log,
    required TaeraeGraphSnapshotStore snapshotStore,
    required int autoCheckpointEvery,
    required int pendingOperationCount,
    required int operationsSinceFlush,
    required this.durability,
  }) : _graph = graph,
       _log = log,
       _snapshotStore = snapshotStore,
       _autoCheckpointEvery = autoCheckpointEvery,
       _pendingOperationCount = pendingOperationCount,
       _operationsSinceFlush = operationsSinceFlush;

  /// Opens or creates a persistent graph in [directory].
  ///
  /// When [tolerateIncompleteTrailingLogLine] is `true`, recovery ignores a
  /// malformed final log line if the file ends without a newline. This helps
  /// recover from crash-truncated appends.
  static Future<TaeraePersistentGraph> open({
    required Directory directory,
    String snapshotFileName = 'graph.snapshot.json',
    String logFileName = 'graph.log.ndjson',
    int autoCheckpointEvery = 200,
    bool tolerateIncompleteTrailingLogLine = true,
    TaeraeDurabilityOptions durability = const TaeraeDurabilityOptions(),
  }) async {
    if (autoCheckpointEvery < 0) {
      throw ArgumentError.value(
        autoCheckpointEvery,
        'autoCheckpointEvery',
        'Must be >= 0. Use 0 to disable auto-checkpoint.',
      );
    }
    _validateDurabilityOptions(durability);

    await directory.create(recursive: true);

    final File snapshotFile = File(
      directory.uri.resolve(snapshotFileName).toFilePath(),
    );
    final File logFile = File(directory.uri.resolve(logFileName).toFilePath());

    final TaeraeGraphSnapshotStore snapshotStore = TaeraeGraphSnapshotStore(
      snapshotFile,
    );
    final TaeraeGraphLog log = TaeraeGraphLog(logFile);
    await log.ensureExists();

    final TaeraeGraph graph = await snapshotStore.readOrEmpty();
    final int replayedCount = await log.replayInto(
      graph,
      tolerateIncompleteTrailingLine: tolerateIncompleteTrailingLogLine,
    );

    return TaeraePersistentGraph._(
      directory: directory,
      graph: graph,
      log: log,
      snapshotStore: snapshotStore,
      autoCheckpointEvery: autoCheckpointEvery,
      pendingOperationCount: replayedCount,
      operationsSinceFlush: 0,
      durability: durability,
    );
  }

  /// Root directory containing snapshot and log files.
  final Directory directory;

  /// Durability options for this instance.
  final TaeraeDurabilityOptions durability;

  final TaeraeGraphLog _log;
  final TaeraeGraphSnapshotStore _snapshotStore;
  final int _autoCheckpointEvery;
  TaeraeGraph _graph;
  int _pendingOperationCount;
  int _operationsSinceFlush;
  bool _isClosed = false;

  /// Whether [close] has been called successfully.
  bool get isClosed => _isClosed;

  /// Returns a defensive copy of the current in-memory graph state.
  TaeraeGraph get graph => _graph.copy();

  /// Returns the snapshot file path.
  String get snapshotPath => _snapshotStore.file.path;

  /// Returns the append-only log file path.
  String get logPath => _log.file.path;

  /// Inserts or updates a node and persists the operation.
  Future<TaeraeNode> upsertNode(
    String id, {
    Iterable<String>? labels,
    Map<String, Object?>? properties,
  }) async {
    _throwIfClosed();
    final TaeraeNode? existingNode = _graph.nodeById(id);
    final TaeraeNode nextNode = TaeraeNode(
      id: id,
      labels: labels ?? existingNode?.labels ?? const <String>{},
      properties:
          properties ?? existingNode?.properties ?? const <String, Object?>{},
    );

    await _commitMutation(
      TaeraeGraphOperation.upsertNode(nextNode),
      applyInMemory: () {
        _graph.upsertNode(
          nextNode.id,
          labels: nextNode.labels,
          properties: nextNode.properties,
        );
      },
    );
    return nextNode;
  }

  /// Removes a node and persists the operation.
  Future<bool> removeNode(String id) async {
    _throwIfClosed();
    final TaeraeGraph probe = _graph.copy();
    final bool removed = probe.removeNode(id);
    if (!removed) {
      return false;
    }

    await _commitMutation(
      TaeraeGraphOperation.removeNode(id),
      applyInMemory: () => _graph.removeNode(id),
    );
    return true;
  }

  /// Inserts or updates an edge and persists the operation.
  Future<TaeraeEdge> upsertEdge(
    String id,
    String from,
    String to, {
    String? type,
    Map<String, Object?>? properties,
  }) async {
    _throwIfClosed();
    if (!_graph.containsNode(from)) {
      throw StateError(
        'Cannot upsert edge "$id": source node "$from" does not exist.',
      );
    }
    if (!_graph.containsNode(to)) {
      throw StateError(
        'Cannot upsert edge "$id": target node "$to" does not exist.',
      );
    }

    final TaeraeEdge? existingEdge = _graph.edgeById(id);
    final TaeraeEdge nextEdge = TaeraeEdge(
      id: id,
      from: from,
      to: to,
      type: type ?? existingEdge?.type,
      properties:
          properties ?? existingEdge?.properties ?? const <String, Object?>{},
    );

    await _commitMutation(
      TaeraeGraphOperation.upsertEdge(nextEdge),
      applyInMemory: () {
        _graph.upsertEdge(
          nextEdge.id,
          nextEdge.from,
          nextEdge.to,
          type: nextEdge.type,
          properties: nextEdge.properties,
        );
      },
    );
    return nextEdge;
  }

  /// Removes an edge and persists the operation.
  Future<bool> removeEdge(String id) async {
    _throwIfClosed();
    final TaeraeGraph probe = _graph.copy();
    final bool removed = probe.removeEdge(id);
    if (!removed) {
      return false;
    }

    await _commitMutation(
      TaeraeGraphOperation.removeEdge(id),
      applyInMemory: () => _graph.removeEdge(id),
    );
    return true;
  }

  /// Clears all graph data and persists the operation.
  Future<void> clear() async {
    _throwIfClosed();
    if (_isEmptyGraph()) {
      return;
    }
    await _commitMutation(
      const TaeraeGraphOperation.clear(),
      applyInMemory: _graph.clear,
    );
  }

  /// Writes a full snapshot and truncates the append-only log.
  Future<void> checkpoint() async {
    _throwIfClosed();
    await _log.flush();
    await _snapshotStore.write(
      _graph,
      atomicWrite: durability.atomicSnapshotWrite,
    );
    await _log.truncate();
    _pendingOperationCount = 0;
    _operationsSinceFlush = 0;
  }

  /// Returns the shortest path in the current graph.
  List<String>? shortestPathBfs(
    String startId,
    String endId, {
    String? edgeType,
  }) {
    return _graph.shortestPathBfs(startId, endId, edgeType: edgeType);
  }

  /// Returns nodes by label.
  List<TaeraeNode> nodesByLabel(String label) => _graph.nodesByLabel(label);

  /// Returns nodes filtered by property value.
  List<TaeraeNode> nodesWhereProperty(String key, Object? value) {
    return _graph.nodesWhereProperty(key, value);
  }

  /// Returns all graph data as JSON.
  Map<String, Object?> toJson() => _graph.toJson();

  /// Replaces current state from [json] and stores a compact snapshot.
  Future<void> restoreFromJson(Map<String, Object?> json) async {
    _throwIfClosed();
    _graph = TaeraeGraph.fromJson(json);
    await checkpoint();
  }

  /// Closes this instance after flushing persistence state.
  ///
  /// When [checkpointOnClose] is `true`, this writes a compact snapshot and
  /// truncates the log. When `false`, pending log writes are still flushed, but
  /// log compaction is skipped.
  Future<void> close({bool checkpointOnClose = true}) async {
    if (_isClosed) {
      return;
    }

    if (checkpointOnClose) {
      await checkpoint();
    } else {
      await _log.flush();
      _operationsSinceFlush = 0;
    }

    _isClosed = true;
  }

  Future<void> _commitMutation(
    TaeraeGraphOperation operation, {
    required void Function() applyInMemory,
  }) async {
    switch (durability.writeAtomicityPolicy) {
      case TaeraeWriteAtomicityPolicy.writeAhead:
        await _appendOperation(operation);
        applyInMemory();
      case TaeraeWriteAtomicityPolicy.inMemoryFirst:
        applyInMemory();
        await _appendOperation(operation);
    }

    _pendingOperationCount += 1;
    if (_autoCheckpointEvery > 0 &&
        _pendingOperationCount >= _autoCheckpointEvery) {
      await checkpoint();
    }
  }

  Future<void> _appendOperation(TaeraeGraphOperation operation) async {
    final bool flushThisWrite = _shouldFlushOnAppend();
    await _log.append(operation, flush: flushThisWrite);

    if (flushThisWrite) {
      _operationsSinceFlush = 0;
    } else {
      _operationsSinceFlush += 1;
    }
  }

  bool _shouldFlushOnAppend() {
    switch (durability.logFlushPolicy) {
      case TaeraeLogFlushPolicy.immediate:
        return true;
      case TaeraeLogFlushPolicy.onCheckpoint:
        return false;
      case TaeraeLogFlushPolicy.everyNOperations:
        return _operationsSinceFlush + 1 >= durability.flushEveryNOperations;
    }
  }

  bool _isEmptyGraph() {
    final Map<String, Object?> json = _graph.toJson();
    final Object? rawNodes = json['nodes'];
    final Object? rawEdges = json['edges'];
    return (rawNodes is List<Object?> && rawNodes.isEmpty) &&
        (rawEdges is List<Object?> && rawEdges.isEmpty);
  }

  static void _validateDurabilityOptions(TaeraeDurabilityOptions durability) {
    if (durability.logFlushPolicy == TaeraeLogFlushPolicy.everyNOperations &&
        durability.flushEveryNOperations <= 0) {
      throw ArgumentError.value(
        durability.flushEveryNOperations,
        'durability.flushEveryNOperations',
        'Must be > 0 when using everyNOperations flush policy.',
      );
    }
  }

  void _throwIfClosed() {
    if (_isClosed) {
      throw StateError('Cannot mutate a closed TaeraePersistentGraph.');
    }
  }
}
