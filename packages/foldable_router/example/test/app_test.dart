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

/// Taps a destination of the shell's bottom `NavigationBar`.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

String stackText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('stack'))).data!;

void main() {
  setUp(session.reset);

  testWidgets('pendingBuilder is shown on launch, then the shell on Home', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    await tester.pump();

    expect(find.text('Starting (pendingBuilder)'), findsOneWidget);
    expect(router.stack, isEmpty);

    await tester.pumpAndSettle();
    expect(router.stack, [const MainShellRoute(), const HomeRoute()]);
    expect(find.text('foldable_router example'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(stackText(tester), 'stack: [shell]  >  /');
    expect(find.text('location: /'), findsOneWidget);
  });

  testWidgets('open user detail builds [shell, Users, User]; back shows the '
      'list', (tester) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-user');
    await tester.pumpAndSettle();

    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    expect(
      stackText(tester),
      'stack: [shell]  >  /users  >  /users/detail?id=7',
    );
    expect(find.text('location: /users/detail?id=7'), findsOneWidget);
    expect(find.text('User 7'), findsWidgets);
    // open switched to the Users branch of the shell.
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(router.stack, [const MainShellRoute(), const UsersRoute()]);
    expect(find.text('Users'), findsWidgets);
  });

  testWidgets('the tab bar switches branches and keeps each tab stack', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    // Build a stack in the Users branch.
    await tap(tester, 'open-user');
    await tester.pumpAndSettle();
    expect(router.stack.last, const UserRoute(id: '7'));

    await tapTab(tester, 'Home');
    expect(router.stack, [const MainShellRoute(), const HomeRoute()]);
    expect(find.text('stack: [shell]  >  /'), findsOneWidget);

    await tapTab(tester, 'Users');
    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    expect(find.text('User 7'), findsWidgets);
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
    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
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
    expect(router.stack, [const MainShellRoute(), const UsersRoute()]);
    expect(find.byType(Hero), findsNWidgets(3));
    expect(tester.getRect(avatar), small);
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
    expect(router.stack, [const MainShellRoute(), const HomeRoute()]);

    await tester.pumpAndSettle();
    expect(router.isNavigating.value, isFalse);
    expect(find.byKey(const Key('navigating')), findsNothing);
    // Login is outside the shell: the shell (and its tabs) is gone.
    expect(router.stack, [const LoginRoute(from: '/profile/settings')]);
    expect(find.byType(NavigationBar), findsNothing);

    await tap(tester, 'login');
    await tester.pumpAndSettle();

    expect(session.loggedIn, isTrue);
    expect(router.stack, [
      const MainShellRoute(),
      const ProfileRoute(),
      const SettingsRoute(),
    ]);
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
    expect(router.stack, [const MainShellRoute(), const ProfileRoute()]);

    await tap(tester, 'logout');
    await tester.pumpAndSettle();

    expect(session.loggedIn, isFalse);
    expect(router.stack, [const LoginRoute(from: '/profile')]);
    expect(find.text('Only visible when logged in.'), findsNothing);
  });

  testWidgets('pushed picker covers the shell and returns its result to Home', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(find.text('Picked: nothing yet'), findsOneWidget);

    await tap(tester, 'pick-color');
    await tester.pumpAndSettle();
    // The picker is outside the shell: a full-screen page above the tabs.
    expect(router.stack, [
      const MainShellRoute(),
      const HomeRoute(),
      const ColorPickerRoute(),
    ]);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('green'));
    await tester.pumpAndSettle();

    expect(router.stack, [const MainShellRoute(), const HomeRoute()]);
    expect(find.byType(NavigationBar), findsOneWidget);
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
    expect(router.stack, [const MainShellRoute(), const HomeRoute()]);
  });

  testWidgets('deep link to a protected page goes through the guard', (
    tester,
  ) async {
    final router = await pumpApp(tester, deepLink: '/profile');
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute(from: '/profile')]);
  });

  testWidgets('deep link into a shell branch builds only that branch', (
    tester,
  ) async {
    final router = await pumpApp(tester, deepLink: '/users/detail?id=7');
    await tester.pumpAndSettle();

    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    expect(find.text('User 7'), findsWidgets);
    expect(
      stackText(tester),
      'stack: [shell]  >  /users  >  /users/detail?id=7',
    );
  });

  testWidgets('wide window: the Users tab shows two panes', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tapTab(tester, 'Users');
    await tester.pumpAndSettle();

    // One page: the empty-state asks for a selection on the right.
    expect(find.byKey(const Key('no-user-selected')), findsOneWidget);
    expect(find.text('Chọn một người dùng'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, 'User 7'));
    await tester.pumpAndSettle();

    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    expect(find.byKey(const Key('no-user-selected')), findsNothing);
    expect(find.text('User 7'), findsWidgets);

    // The row of the open user is highlighted while the list is the left
    // pane.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.selected &&
            widget.title is Text &&
            (widget.title! as Text).data == 'User 7',
      ),
      findsOneWidget,
    );

    // The back button of the right pane pops just the detail page.
    await tester.tap(
      find.descendant(
        of: find.byType(UserPage),
        matching: find.byType(BackButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(router.stack, [const MainShellRoute(), const UsersRoute()]);
    expect(find.byKey(const Key('no-user-selected')), findsOneWidget);
  });

  testWidgets('wide window: opening a user from Home lands on two panes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tap(tester, 'open-user');
    await tester.pumpAndSettle();

    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    expect(find.byKey(const Key('no-user-selected')), findsNothing);
    // Both panes are on screen: the list and the detail.
    expect(find.widgetWithText(AppBar, 'Users'), findsOneWidget);
    expect(find.byType(UserPage), findsOneWidget);
  });

  testWidgets('narrow window: the Users tab keeps one pane', (tester) async {
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();

    await tapTab(tester, 'Users');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'User 7'));
    await tester.pumpAndSettle();

    expect(router.stack, [
      const MainShellRoute(),
      const UsersRoute(),
      const UserRoute(id: '7'),
    ]);
    // The detail fills the tab; the list is behind it, out of the screen.
    expect(find.byType(UserPage), findsOneWidget);
    // ('Users' also labels the tab in the navigation bar: look at the AppBar.)
    expect(find.widgetWithText(AppBar, 'Users'), findsNothing);
    expect(find.byKey(const Key('no-user-selected')), findsNothing);

    await tester.tap(find.byType(BackButton).first);
    await tester.pumpAndSettle();
    expect(router.stack, [const MainShellRoute(), const UsersRoute()]);
  });
}
