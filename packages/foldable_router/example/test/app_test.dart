import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_router_example/app.dart';
import 'package:foldable_router_example/pages/users_pages.dart';
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
    expect(find.text('location: /users/detail?id=7'), findsOneWidget);
    expect(find.text('User 7'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(router.stack, [const UsersRoute()]);
    expect(find.text('Users'), findsOneWidget);
  });

  testWidgets('user avatar flies as a Hero from the list to the detail and '
      'back', (tester) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-users');
    await tester.pumpAndSettle();

    // Onstage avatars of user 7. During a flight the two Heroes keep their
    // child offstage and a single shuttle lives in the overlay; without a
    // Hero both pages would show their own avatar during the transition.
    final avatar = find.widgetWithText(CircleAvatar, '7');
    final hero = find.byWidgetPredicate(
      (widget) => widget is Hero && widget.tag == UserAvatar.heroTag('7'),
    );
    expect(find.byType(Hero), findsNWidgets(3));
    expect(hero, findsOneWidget);
    expect(avatar, findsOneWidget);
    final small = tester.getRect(avatar);
    expect(small.width, 40);

    await tester.tap(find.text('User 7'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In flight: one shuttle, above both pages, between the two sizes.
    expect(router.stack, [const UsersRoute(), const UserRoute(id: '7')]);
    expect(avatar, findsOneWidget);
    expect(
      find.ancestor(of: avatar, matching: find.byType(UserAvatar)),
      findsNothing,
    );
    final flying = tester.getRect(avatar);
    expect(flying.width, greaterThan(40));
    expect(flying.width, lessThan(128));
    expect(flying.center, isNot(small.center));

    await tester.pumpAndSettle();
    expect(hero, findsOneWidget);
    expect(avatar, findsOneWidget);
    final large = tester.getRect(avatar);
    expect(large.width, 128);
    expect(
      find.ancestor(of: avatar, matching: find.byType(UserAvatar)),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(avatar, findsOneWidget);
    expect(
      find.ancestor(of: avatar, matching: find.byType(UserAvatar)),
      findsNothing,
    );
    expect(tester.getRect(avatar).width, inExclusiveRange(40, 128));

    await tester.pumpAndSettle();
    expect(router.stack, [const UsersRoute()]);
    expect(find.byType(Hero), findsNWidgets(3));
    expect(tester.getRect(avatar), small);
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
    expect(find.text('location: /nope'), findsOneWidget);

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
