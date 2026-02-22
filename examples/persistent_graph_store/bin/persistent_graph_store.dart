import 'dart:io';

import 'package:taerae_core/taerae_core.dart';

Future<void> main() async {
  final Directory storeDir = Directory('./.taerae_store');

  final TaeraePersistentGraph persistent = await TaeraePersistentGraph.open(
    directory: storeDir,
    autoCheckpointEvery: 3,
    durability: const TaeraeDurabilityOptions(
      logFlushPolicy: TaeraeLogFlushPolicy.everyNOperations,
      flushEveryNOperations: 2,
      writeAtomicityPolicy: TaeraeWriteAtomicityPolicy.writeAhead,
      atomicSnapshotWrite: true,
    ),
  );

  await persistent.upsertNode('alice', labels: const <String>['Person']);
  await persistent.upsertNode('seoul', labels: const <String>['City']);
  await persistent.upsertEdge('e1', 'alice', 'seoul', type: 'LIVES_IN');

  final List<String>? path = persistent.shortestPathBfs('alice', 'seoul');
  print('Path alice -> seoul: $path');
  print('Snapshot file: ${persistent.snapshotPath}');
  print('Log file: ${persistent.logPath}');

  await persistent.checkpoint();

  final TaeraePersistentGraph reopened = await TaeraePersistentGraph.open(
    directory: storeDir,
    autoCheckpointEvery: 3,
  );
  print('Recovered graph: ${reopened.toJson()}');
}
