import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_taerae_example/main.dart';

void main() {
  testWidgets('renders CRUD sections', (WidgetTester tester) async {
    await tester.pumpWidget(const TaeraeCrudExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Taerae CRUD Example'), findsOneWidget);
    expect(find.text('Node CRUD'), findsOneWidget);
    expect(find.text('Node Search'), findsOneWidget);
    expect(find.text('Edge CRUD'), findsOneWidget);
    expect(find.text('Current Graph'), findsOneWidget);
  });
}
