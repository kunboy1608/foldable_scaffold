import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router_example/app_router.dart';
import 'package:foldable_router_example/main.dart';

void main() {
  testWidgets('start on the main shell, push nested pages, switch shell', (
    tester,
  ) async {
    await tester.pumpWidget(const RouterExample());
    await tester.pumpAndSettle();

    // The main shell shows the Home tab.
    expect(find.text('Home'), findsWidgets);

    // Push the nested Calendar, then the Event details.
    await tester.tap(find.text('Push Calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Calendar'), findsWidgets);

    await tester.tap(find.text('Push Event details'));
    await tester.pumpAndSettle();
    expect(find.text('Event details'), findsWidgets);

    // Switching shells keeps the main shell's stack.
    appRouter.showShell(statisticShell);
    await tester.pumpAndSettle();
    expect(find.text('Profit'), findsWidgets);

    appRouter.showShell(mainShell);
    await tester.pumpAndSettle();
    // Still on the Event details page of the Home tab.
    expect(find.text('Event details'), findsWidgets);
  });
}
