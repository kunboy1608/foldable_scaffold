import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router_example/app.dart';
import 'package:foldable_router_example/routes.dart';
import 'package:foldable_router_example/session.dart';

Future<FoldableRouter> pumpApp(WidgetTester tester, {String? deepLink}) async {
  if (deepLink != null) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = deepLink;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
  }
  final router = createRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(ExampleApp(router: router));
  return router;
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

String stackText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('stack'))).data!;

void main() {
  setUp(session.reset);

  testWidgets('pendingBuilder is shown on launch, then Home', (tester) async {
    final router = await pumpApp(tester);
    await tester.pump();

    expect(find.text('Starting (pendingBuilder)'), findsOneWidget);
    expect(router.stack, isEmpty);

    await tester.pumpAndSettle();
    expect(router.stack, [const HomeRoute()]);
    expect(find.text('foldable_router example'), findsOneWidget);
  });

  testWidgets('open user detail builds [Users, User]; back shows the list', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-user');
    await tester.pumpAndSettle();

    expect(router.stack, [const UsersRoute(), const UserRoute(id: '7')]);
    expect(stackText(tester), 'stack: /users  >  /users/detail?id=7');
    expect(find.text('User 7'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(router.stack, [const UsersRoute()]);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('push user detail keeps Home below', (tester) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'push-user');
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute(), const UserRoute(id: '7')]);
  });

  testWidgets('protected child while logged out: login, then the target', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-settings');

    // The async guard is pending: Home stays and the progress bar shows.
    await tester.pump(const Duration(milliseconds: 400));
    expect(router.isNavigating.value, isTrue);
    expect(find.byKey(const Key('navigating')), findsOneWidget);
    expect(router.stack, [const HomeRoute()]);

    await tester.pumpAndSettle();
    expect(router.isNavigating.value, isFalse);
    expect(find.byKey(const Key('navigating')), findsNothing);
    expect(router.stack, [const LoginRoute(from: '/profile/settings')]);

    await tap(tester, 'login');
    await tester.pumpAndSettle();

    expect(session.loggedIn, isTrue);
    expect(router.stack, [const ProfileRoute(), const SettingsRoute()]);
    expect(find.text('Guarded by ProfileRoute.redirect.'), findsOneWidget);
  });

  testWidgets('logout + refresh kicks the user out of the protected page', (
    tester,
  ) async {
    session.login();
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-profile');
    await tester.pumpAndSettle();
    expect(router.stack, [const ProfileRoute()]);

    await tap(tester, 'logout');
    await tester.pumpAndSettle();

    expect(session.loggedIn, isFalse);
    expect(router.stack, [const LoginRoute(from: '/profile')]);
    expect(find.text('Only visible when logged in.'), findsNothing);
  });

  testWidgets('pushed picker returns its result to Home', (tester) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Picked: nothing yet'), findsOneWidget);

    await tap(tester, 'pick-color');
    await tester.pumpAndSettle();
    expect(router.stack, [const HomeRoute(), const ColorPickerRoute()]);

    await tester.tap(find.text('green'));
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute()]);
    expect(find.text('Picked: green'), findsOneWidget);
  });

  testWidgets('unknown URL shows the not-found page with a way home', (
    tester,
  ) async {
    final router = await pumpApp(tester, deepLink: '/nope');
    await tester.pumpAndSettle();

    expect(find.text('No route for /nope'), findsOneWidget);
    expect(stackText(tester), 'stack: (empty)');

    await tap(tester, 'go-home');
    await tester.pumpAndSettle();
    expect(router.stack, [const HomeRoute()]);
  });

  testWidgets('deep link to a protected page goes through the guard', (
    tester,
  ) async {
    final router = await pumpApp(tester, deepLink: '/profile');
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute(from: '/profile')]);
  });
}
