import 'package:flutter_test/flutter_test.dart';

import 'package:offline_ai/main.dart';

void main() {
  testWidgets('OrbitApp builds and shows welcome or chat screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OrbitApp());

    expect(find.text('Orbit'), findsOneWidget);
    expect(find.text('Ask me anything...'), findsOneWidget);
  });
}
