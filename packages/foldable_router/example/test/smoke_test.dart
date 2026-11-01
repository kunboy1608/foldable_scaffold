import 'package:flutter_test/flutter_test.dart';
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

    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    expect(find.text('Details 1'), findsOneWidget);
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
