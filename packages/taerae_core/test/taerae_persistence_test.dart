import 'dart:convert';
import 'dart:io';

import 'package:taerae/taerae.dart';
import 'package:test/test.dart';

Future<void> _writeLogWithTruncatedTrailingLine(File file) async {
  final String first = jsonEncode(
    TaeraeGraphOperation.upsertNode(TaeraeNode(id: 'n1')).toJson(),
  );
  final String second = jsonEncode(
    TaeraeGraphOperation.upsertNode(TaeraeNode(id: 'n2')).toJson(),
  );

  await file.writeAsString(
    '$first\n$second\n{"type":"upsertNode","node":{"id":"truncated"',
    flush: true,
  );
}

void main() {
  group('TaeraeGraphLog', () {
    test('appends operations and replays into graph', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-log-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File logFile = File(
        tempDir.uri.resolve('graph.log.ndjson').toFilePath(),
      );
      final TaeraeGraphLog log = TaeraeGraphLog(logFile);

      await log.append(
        TaeraeGraphOperation.upsertNode(
          TaeraeNode(id: 'alice', labels: const <String>['Person']),
        ),
      );
      await log.append(
        TaeraeGraphOperation.upsertNode(
          TaeraeNode(id: 'seoul', labels: const <String>['City']),
        ),
      );
      await log.append(
        TaeraeGraphOperation.upsertEdge(
          TaeraeEdge(id: 'e1', from: 'alice', to: 'seoul', type: 'LIVES_IN'),
        ),
      );

      final TaeraeGraph graph = TaeraeGraph();
      final int replayed = await log.replayInto(graph);

      expect(replayed, equals(3));
      expect(graph.containsNode('alice'), isTrue);
      expect(graph.containsNode('seoul'), isTrue);
      expect(graph.containsEdge('e1'), isTrue);
      expect(
        graph.shortestPathBfs('alice', 'seoul'),
        equals(const <String>['alice', 'seoul']),
      );
    });

    test('supports deferred flush append mode', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-log-flush-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File logFile = File(
        tempDir.uri.resolve('graph.log.ndjson').toFilePath(),
      );
      final TaeraeGraphLog log = TaeraeGraphLog(logFile);

      await log.append(
        TaeraeGraphOperation.upsertNode(TaeraeNode(id: 'n1')),
        flush: false,
      );
      await log.flush();

      final List<TaeraeGraphOperation> operations = await log.readAll();
      expect(operations.length, equals(1));
      expect(
        operations.single.type,
        equals(TaeraeGraphOperationType.upsertNode),
      );
    });

    test('handles missing file, empty lines, and malformed entries', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-log-invalid-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File logFile = File(
        tempDir.uri.resolve('graph.log.ndjson').toFilePath(),
      );
      final TaeraeGraphLog log = TaeraeGraphLog(logFile);

      expect(await log.readAll(), isEmpty);

      await log.ensureExists();
      await logFile.writeAsString('\n[]\n');
      await expectLater(log.readAll(), throwsFormatException);

      await logFile.writeAsString('\n{"":1}\n');
      expect(log.replayInto(TaeraeGraph()), throwsFormatException);
    });
  });

  group('TaeraeGraphSnapshotStore', () {
    test('writes and restores snapshot', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-snapshot-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File snapshotFile = File(
        tempDir.uri.resolve('graph.snapshot.json').toFilePath(),
      );
      final TaeraeGraphSnapshotStore store = TaeraeGraphSnapshotStore(
        snapshotFile,
      );

      final TaeraeGraph original = TaeraeGraph()
        ..upsertNode(
          'n1',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'name': 'Taerae'},
        )
        ..upsertNode('n2', labels: const <String>['City'])
        ..upsertEdge('e1', 'n1', 'n2', type: 'LIVES_IN');

      await store.write(original);
      final TaeraeGraph restored = await store.readOrEmpty();

      expect(restored.toJson(), equals(original.toJson()));
    });

    test('atomic write does not leave temporary file', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-snapshot-atomic-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File snapshotFile = File(
        tempDir.uri.resolve('graph.snapshot.json').toFilePath(),
      );
      final TaeraeGraphSnapshotStore store = TaeraeGraphSnapshotStore(
        snapshotFile,
      );

      final TaeraeGraph graph = TaeraeGraph()..upsertNode('n1');
      await store.write(graph, atomicWrite: true);

      expect(await snapshotFile.exists(), isTrue);
      expect(await File('${snapshotFile.path}.tmp').exists(), isFalse);
    });

    test(
      'supports non-atomic writes and overwriting existing snapshots',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'taerae-snapshot-overwrite-',
        );
        addTearDown(() => tempDir.delete(recursive: true));

        final File snapshotFile = File(
          tempDir.uri.resolve('graph.snapshot.json').toFilePath(),
        );
        final TaeraeGraphSnapshotStore store = TaeraeGraphSnapshotStore(
          snapshotFile,
        );

        await store.write(TaeraeGraph()..upsertNode('n1'), atomicWrite: false);
        await store.write(TaeraeGraph()..upsertNode('n2'));

        final TaeraeGraph restored = await store.readOrEmpty();
        expect(restored.containsNode('n2'), isTrue);
        expect(restored.containsNode('n1'), isFalse);
      },
    );

    test('reads empty, legacy, and invalid snapshot payloads', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'taerae-snapshot-parse-',
      );
      addTearDown(() => tempDir.delete(recursive: true));

      final File snapshotFile = File(
        tempDir.uri.resolve('graph.snapshot.json').toFilePath(),
      );
      final TaeraeGraphSnapshotStore store = TaeraeGraphSnapshotStore(
        snapshotFile,
      );

      // Empty file returns an empty graph.
      await snapshotFile.writeAsString('');
      expect((await store.readOrEmpty()).toJson()['nodes'], isEmpty);

      // Legacy shape is accepted.
      await snapshotFile.writeAsString(
        '{"nodes":[{"id":"legacy"}],"edges":[]}',
      );
      expect((await store.readOrEmpty()).containsNode('legacy'), isTrue);

      // Unsupported format is rejected.
      await snapshotFile.writeAsString(
        '{"format":"other","graph":{"nodes":[],"edges":[]}}',
      );
      await expectLater(store.readOrEmpty(), throwsFormatException);

      // Root must be a map.
      await snapshotFile.writeAsString('[]');
      await expectLater(store.readOrEmpty(), throwsFormatException);

      // Root keys must be non-empty strings.
      await snapshotFile.writeAsString('{"":1}');
      await expectLater(store.readOrEmpty(), throwsFormatException);
    });
  });

  group('TaeraePersistentGraph', () {
    test(
      'open recovers from valid operations with truncated trailing log line',
      () async {
        final Directory storeDir = await Directory.systemTemp.createTemp(
          'taerae-open-truncated-',
        );
        addTearDown(() => storeDir.delete(recursive: true));

        final File logFile = File(
          storeDir.uri.resolve('graph.log.ndjson').toFilePath(),
        );
        await logFile.parent.create(recursive: true);
        await _writeLogWithTruncatedTrailingLine(logFile);

        final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
          directory: storeDir,
          autoCheckpointEvery: 0,
        );

        expect(graph.graph.containsNode('n1'), isTrue);
        expect(graph.graph.containsNode('n2'), isTrue);
        expect(graph.graph.containsNode('truncated'), isFalse);
      },
    );

    test('strict open mode rejects truncated trailing log line', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-open-truncated-strict-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final File logFile = File(
        storeDir.uri.resolve('graph.log.ndjson').toFilePath(),
      );
      await logFile.parent.create(recursive: true);
      await _writeLogWithTruncatedTrailingLine(logFile);

      await expectLater(
        TaeraePersistentGraph.open(
          directory: storeDir,
          autoCheckpointEvery: 0,
          tolerateIncompleteTrailingLogLine: false,
        ),
        throwsFormatException,
      );
    });

    test('persists mutations and recovers from disk', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-persistent-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );

      await graph.upsertNode('alice', labels: const <String>['Person']);
      await graph.upsertNode('bob', labels: const <String>['Person']);
      await graph.upsertEdge('e1', 'alice', 'bob', type: 'KNOWS');
      await graph.checkpoint();

      final TaeraePersistentGraph reopened = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );

      expect(reopened.nodesByLabel('Person').length, equals(2));
      expect(
        reopened.shortestPathBfs('alice', 'bob'),
        equals(const <String>['alice', 'bob']),
      );
    });

    test('auto-checkpoint compacts log after threshold', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-checkpoint-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 2,
      );

      await graph.upsertNode('n1');
      await graph.upsertNode('n2');

      final String logContent = await File(graph.logPath).readAsString();
      expect(logContent.trim(), isEmpty);
      expect(await File(graph.snapshotPath).exists(), isTrue);
    });

    test('supports durability policies', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-durability-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
        durability: const TaeraeDurabilityOptions(
          logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
          flushEveryNOperations: 2,
          writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.inMemoryFirst,
          atomicSnapshotWrite: false,
        ),
      );

      await graph.upsertNode('n1');
      await graph.upsertNode('n2');
      await graph.upsertEdge('e1', 'n1', 'n2');
      await graph.checkpoint();

      final TaeraePersistentGraph reopened = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );
      expect(
        reopened.shortestPathBfs('n1', 'n2'),
        equals(const <String>['n1', 'n2']),
      );
    });

    test('validates everyNOperations flush option', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-durability-validate-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      expect(
        () => TaeraePersistentGraph.open(
          directory: storeDir,
          durability: const TaeraeDurabilityOptions(
            logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
            flushEveryNOperations: 0,
          ),
        ),
        throwsArgumentError,
      );
    });

    test(
      'validates autoCheckpointEvery and exposes defensive graph copy',
      () async {
        final Directory storeDir = await Directory.systemTemp.createTemp(
          'taerae-open-validate-',
        );
        addTearDown(() => storeDir.delete(recursive: true));

        expect(
          () => TaeraePersistentGraph.open(
            directory: storeDir,
            autoCheckpointEvery: -1,
          ),
          throwsArgumentError,
        );

        final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
          directory: storeDir,
          autoCheckpointEvery: 0,
        );
        await graph.upsertNode(
          'n1',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'name': 'A'},
        );

        final TaeraeGraph copy = graph.graph..removeNode('n1');
        expect(copy.containsNode('n1'), isFalse);
        expect(graph.nodesByLabel('Person').single.id, equals('n1'));
        expect(graph.snapshotPath, contains('graph.snapshot.json'));
        expect(graph.logPath, contains('graph.log.ndjson'));
      },
    );

    test('covers remove/clear branches and restoreFromJson', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-remove-clear-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );

      expect(await graph.removeNode('missing'), isFalse);
      expect(await graph.removeEdge('missing'), isFalse);
      await graph.clear(); // No-op on empty graph.

      await graph.upsertNode(
        'n1',
        labels: const <String>['User'],
        properties: const <String, Object?>{'name': 'Alice'},
      );
      await graph.upsertNode('n1');
      expect(graph.nodesByLabel('User').single.id, equals('n1'));
      expect(graph.nodesWhereProperty('name', 'Alice').single.id, equals('n1'));

      await graph.upsertNode('n2');
      await graph.upsertEdge(
        'e1',
        'n1',
        'n2',
        type: 'KNOWS',
        properties: const <String, Object?>{'since': 2026},
      );
      await graph.upsertEdge('e1', 'n1', 'n2');
      expect(
        graph.shortestPathBfs('n1', 'n2'),
        equals(const <String>['n1', 'n2']),
      );

      expect(
        () => graph.upsertEdge('bad-source', 'missing', 'n2'),
        throwsStateError,
      );
      expect(
        () => graph.upsertEdge('bad-target', 'n1', 'missing'),
        throwsStateError,
      );

      expect(await graph.removeEdge('e1'), isTrue);
      expect(await graph.removeNode('n2'), isTrue);
      await graph.clear();
      expect(graph.toJson()['nodes'], isEmpty);

      await graph.restoreFromJson(<String, Object?>{
        'nodes': <Object?>[
          <String, Object?>{
            'id': 'r1',
            'labels': <Object?>['Restored'],
          },
        ],
        'edges': <Object?>[],
      });
      expect(graph.nodesByLabel('Restored').single.id, equals('r1'));
    });

    test('supports onCheckpoint flush policy', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-on-checkpoint-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
        durability: const TaeraeDurabilityOptions(
          logFlushPolicy: TaeraeLogFlushPolicy.onCheckpoint,
        ),
      );

      await graph.upsertNode('n1');
      await graph.upsertNode('n2');
      final String beforeCheckpoint = await File(graph.logPath).readAsString();
      expect(beforeCheckpoint.trim().isNotEmpty, isTrue);

      await graph.checkpoint();
      final String afterCheckpoint = await File(graph.logPath).readAsString();
      expect(afterCheckpoint.trim(), isEmpty);
    });

    test('close marks closed and rejects later mutating operations', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-close-closed-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );
      await graph.upsertNode('n1');

      await graph.close();
      expect(graph.isClosed, isTrue);

      await expectLater(graph.upsertNode('n2'), throwsStateError);
      await expectLater(graph.removeNode('n1'), throwsStateError);
      await expectLater(graph.removeEdge('missing'), throwsStateError);
      await expectLater(graph.clear(), throwsStateError);
      await expectLater(graph.checkpoint(), throwsStateError);
      await expectLater(
        graph.restoreFromJson(const <String, Object?>{
          'nodes': <Object?>[],
          'edges': <Object?>[],
        }),
        throwsStateError,
      );
    });

    test('close without checkpoint flushes log data for reopen', () async {
      final Directory storeDir = await Directory.systemTemp.createTemp(
        'taerae-close-flush-',
      );
      addTearDown(() => storeDir.delete(recursive: true));

      final TaeraePersistentGraph graph = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
        durability: const TaeraeDurabilityOptions(
          logFlushPolicy: TaeraeLogFlushPolicy.onCheckpoint,
        ),
      );

      await graph.upsertNode('n1');
      await graph.upsertNode('n2');
      await graph.close(checkpointOnClose: false);

      expect(graph.isClosed, isTrue);
      final String persistedLog = await File(graph.logPath).readAsString();
      expect(persistedLog.trim().isNotEmpty, isTrue);

      final TaeraePersistentGraph reopened = await TaeraePersistentGraph.open(
        directory: storeDir,
        autoCheckpointEvery: 0,
      );
      expect(reopened.graph.containsNode('n1'), isTrue);
      expect(reopened.graph.containsNode('n2'), isTrue);
    });
  });
}
