import 'dart:io';

import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

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
  });

  group('TaeraePersistentGraph', () {
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
  });
}
