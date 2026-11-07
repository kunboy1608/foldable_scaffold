import 'package:flutter_test/flutter_test.dart';

import 'package:foldable_dev_tools_example/main.dart';

void main() {
  testWidgets('dev tools example starts on the list route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DevToolsExample());

    expect(find.text('Item 1'), findsOneWidget);
  });
}
