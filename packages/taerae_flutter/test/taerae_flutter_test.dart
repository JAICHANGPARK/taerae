import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:taerae_flutter/taerae_flutter.dart';
import 'package:taerae_flutter/taerae_flutter_method_channel.dart';
import 'package:taerae_flutter/taerae_flutter_platform_interface.dart';

class MockTaeraeFlutterPlatform
    with MockPlatformInterfaceMixin
    implements TaeraeFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TaeraeFlutterPlatform initialPlatform = TaeraeFlutterPlatform.instance;

  test('$MethodChannelTaeraeFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTaeraeFlutter>());
  });

  test('getPlatformVersion', () async {
    TaeraeFlutter taeraeFlutterPlugin = TaeraeFlutter();
    MockTaeraeFlutterPlatform fakePlatform = MockTaeraeFlutterPlatform();
    TaeraeFlutterPlatform.instance = fakePlatform;

    expect(await taeraeFlutterPlugin.getPlatformVersion(), '42');
  });

  group('TaeraeGraphController', () {
    test('notifies listeners on graph mutations', () {
      final TaeraeGraphController controller = TaeraeGraphController();
      int notifyCount = 0;
      controller.addListener(() {
        notifyCount += 1;
      });

      controller.upsertNode('n1', labels: const <String>['Person']);
      controller.upsertNode('n2', labels: const <String>['Person']);
      controller.upsertEdge('e1', 'n1', 'n2', type: 'KNOWS');

      expect(notifyCount, equals(3));
      expect(controller.containsNode('n1'), isTrue);
      expect(controller.containsEdge('e1'), isTrue);
      expect(
        controller.shortestPathBfs('n1', 'n2'),
        equals(const <String>['n1', 'n2']),
      );
    });

    test('exports and imports JSON graph state', () {
      final TaeraeGraphController source = TaeraeGraphController()
        ..upsertNode(
          'alice',
          labels: const <String>['Person'],
          properties: const <String, Object?>{'name': 'Alice'},
        )
        ..upsertNode('seoul', labels: const <String>['City'])
        ..upsertEdge('e1', 'alice', 'seoul', type: 'LIVES_IN');

      final String payload = source.exportToJsonString();
      final TaeraeGraphController restored = TaeraeGraphController()
        ..importFromJsonString(payload);

      expect(restored.nodesByLabel('Person').single.id, equals('alice'));
      expect(restored.edgeById('e1')?.type, equals('LIVES_IN'));
      expect(
        restored.shortestPathBfs('alice', 'seoul'),
        equals(const <String>['alice', 'seoul']),
      );
    });
  });
}
