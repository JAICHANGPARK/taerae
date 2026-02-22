import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_taerae/flutter_taerae.dart';

void main() {
  // Verifies visualizer rendering, live updates, and tap callbacks.
  group('TaeraeGraphView', () {
    testWidgets('renders nodes and refreshes on controller updates', (
      WidgetTester tester,
    ) async {
      final TaeraeGraphController controller = TaeraeGraphController()
        ..upsertNode('alice')
        ..upsertNode('bob')
        ..upsertEdge('knows', 'alice', 'bob', type: 'KNOWS');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 280,
              child: TaeraeGraphView(
                controller: controller,
                interactive: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);

      controller.upsertNode('carol');
      await tester.pump();

      expect(find.text('carol'), findsOneWidget);
    });

    testWidgets('invokes onNodeTap for node hit-testing', (
      WidgetTester tester,
    ) async {
      final TaeraeGraphController controller = TaeraeGraphController()
        ..upsertNode('solo');
      addTearDown(controller.dispose);

      TaeraeNode? tappedNode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: TaeraeGraphView(
                controller: controller,
                interactive: false,
                onNodeTap: (TaeraeNode node) {
                  tappedNode = node;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.byType(TaeraeGraphView)));
      await tester.pump();

      expect(tappedNode?.id, equals('solo'));
    });

    testWidgets('invokes onEdgeTap when tapping a rendered edge', (
      WidgetTester tester,
    ) async {
      final TaeraeGraphController controller = TaeraeGraphController()
        ..upsertNode('left')
        ..upsertNode('right')
        ..upsertEdge('e1', 'left', 'right', type: 'LINKS');
      addTearDown(controller.dispose);

      TaeraeEdge? tappedEdge;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 240,
              child: TaeraeGraphView(
                controller: controller,
                interactive: false,
                layout:
                    (
                      Size _,
                      List<TaeraeNode> _,
                      List<TaeraeEdge> _,
                      EdgeInsets _,
                      double _,
                    ) {
                      return const <String, Offset>{
                        'left': Offset(80, 120),
                        'right': Offset(280, 120),
                      };
                    },
                onEdgeTap: (TaeraeEdge edge) {
                  tappedEdge = edge;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final Offset origin = tester.getTopLeft(find.byType(TaeraeGraphView));
      await tester.tapAt(origin + const Offset(180, 120));
      await tester.pump();

      expect(tappedEdge?.id, equals('e1'));
    });
  });
}
