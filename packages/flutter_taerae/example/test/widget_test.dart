import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_taerae_example/main.dart';

void main() {
  testWidgets('renders quick start and advanced CRUD sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TaeraeCrudExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Taerae Example'), findsOneWidget);
    expect(find.text('Start Here'), findsOneWidget);
    expect(find.text('Quick Start'), findsOneWidget);
    expect(find.text('Advanced CRUD'), findsOneWidget);
    expect(find.text('Graph Visualizer'), findsOneWidget);

    await tester.tap(find.text('Advanced CRUD'));
    await tester.pumpAndSettle();

    expect(find.text('Node CRUD'), findsOneWidget);
    expect(find.text('Node Search'), findsOneWidget);
    expect(find.text('Edge CRUD'), findsOneWidget);
    expect(find.text('Current Graph'), findsOneWidget);
  });
}
