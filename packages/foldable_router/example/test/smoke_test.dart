import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart'
    show BackButton, Offset, Scrollable;
import 'package:foldable_router_example/main.dart';

void main() {
  testWidgets('guest -> onboarding -> main, and back out', (tester) async {
    await tester.pumpWidget(const RouterExample());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Home'), findsNothing);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Sign up'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open the app'));
    await tester.pumpAndSettle();
    expect(find.text('Last action'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('push a route of another session'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('push a route of another session'));
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('route.push(context)'),
      -100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Last action'), findsWidgets);

    await tester.tap(find.text('route.push(context)'));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('popToRoot()'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('popToRoot()'));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsNothing);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });
}
