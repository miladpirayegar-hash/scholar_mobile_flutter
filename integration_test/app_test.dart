import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pumpAndSettle();
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
