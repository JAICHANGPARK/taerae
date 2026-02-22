import 'dart:mirrors';

import 'package:taerae_core/taerae_core.dart';
import 'package:test/test.dart';

void main() {
  group('Private defensive branches', () {
    test('deindexing removes adjacency buckets for missing nodes', () {
      final TaeraeGraph graph = TaeraeGraph()
        ..upsertNode('n1')
        ..upsertNode('n2')
        ..upsertEdge('e1', 'n1', 'n2');

      final InstanceMirror graphMirror = reflect(graph);
      final LibraryMirror graphLibrary =
          graphMirror.type.owner as LibraryMirror;

      final Map<String, TaeraeNode> nodes =
          graphMirror.getField(_private('_nodes', graphLibrary)).reflectee
              as Map<String, TaeraeNode>;
      nodes.clear();

      expect(graph.removeEdge('e1'), isTrue);

      final Map<String, Set<String>> outgoing =
          graphMirror
                  .getField(_private('_outgoingEdgeIdsByNode', graphLibrary))
                  .reflectee
              as Map<String, Set<String>>;
      final Map<String, Set<String>> incoming =
          graphMirror
                  .getField(_private('_incomingEdgeIdsByNode', graphLibrary))
                  .reflectee
              as Map<String, Set<String>>;

      expect(outgoing.containsKey('n1'), isFalse);
      expect(incoming.containsKey('n2'), isFalse);
    });

    test('operation payload guards throw for null payloads', () {
      final ClassMirror operationClass = reflectClass(TaeraeGraphOperation);
      final LibraryMirror operationLibrary =
          operationClass.owner as LibraryMirror;

      expect(
        () => operationClass.invoke(
          _private('_requireNode', operationLibrary),
          <Object?>[null, TaeraeGraphOperationType.upsertNode],
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => operationClass.invoke(
          _private('_requireEdge', operationLibrary),
          <Object?>[null, TaeraeGraphOperationType.upsertEdge],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}

Symbol _private(String name, LibraryMirror library) {
  return MirrorSystem.getSymbol(name, library);
}
