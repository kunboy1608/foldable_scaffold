import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

bool loggedIn = true;
Completer<void>? gate;

class HomeRoute extends FoldableRoute {
  const HomeRoute();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class UsersRoute extends FoldableRoute {
  const UsersRoute();

  @override
  String get path => '/users';

  @override
  Widget build(BuildContext context) => const Text('users');
}

class UserRoute extends FoldableRoute {
  const UserRoute({required this.id, this.tab});

  final String id;
  final String? tab;

  @override
  String get path => '/users/detail';

  @override
  Map<String, String?> get params => {'id': id, 'tab': tab};

  @override
  FoldableRoute? get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('user $id'),
      TextButton(
        onPressed: () => Navigator.of(context).pop('from navigator'),
        child: const Text('navigator pop'),
      ),
      TextButton(
        onPressed: () => FoldableRouter.of(context).pop('from router'),
        child: const Text('router pop'),
      ),
    ],
  );
}

class LoginRoute extends FoldableRoute {
  const LoginRoute();

  @override
  String get path => '/login';

  @override
  Widget build(BuildContext context) => const Text('login');
}

class AccountRoute extends FoldableRoute {
  const AccountRoute();

  @override
  String get path => '/account';

  @override
  FoldableRoute? redirect(RouteState state) =>
      loggedIn ? null : const LoginRoute();

  @override
  Widget build(BuildContext context) => const Text('account');
}

class SettingsRoute extends FoldableRoute {
  const SettingsRoute();

  @override
  String get path => '/account/settings';

  @override
  FoldableRoute? get parent => const AccountRoute();

  @override
  Widget build(BuildContext context) => const Text('settings');
}

/// Waits for [gate] before allowing the navigation.
class SlowRoute extends FoldableRoute {
  const SlowRoute();

  @override
  String get path => '/slow';

  @override
  Future<FoldableRoute?> redirect(RouteState state) async {
    await gate!.future;
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('slow');
}

class BrokenRoute extends FoldableRoute {
  const BrokenRoute();

  @override
  String get path => '/broken';

  @override
  FoldableRoute? redirect(RouteState state) => throw StateError('broken');

  @override
  Widget build(BuildContext context) => const Text('broken');
}

class LoopRoute extends FoldableRoute {
  const LoopRoute(this.n);

  final int n;

  @override
  String get path => '/loop';

  @override
  Map<String, String?> get params => {'n': '$n'};

  @override
  FoldableRoute? redirect(RouteState state) => LoopRoute(n + 1);

  @override
  Widget build(BuildContext context) => const Text('loop');
}

FoldableRouter createRouter({
  FoldableRoute initial = const HomeRoute(),
  bool withPending = true,
}) {
  final router = FoldableRouter(
    initial: initial,
    routes: {
      '/users': (params) => const UsersRoute(),
      '/users/detail': (params) =>
          UserRoute(id: params['id']!, tab: params['tab']),
      '/login': (params) => const LoginRoute(),
      '/account': (params) => const AccountRoute(),
      '/slow': (params) => const SlowRoute(),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
    pendingBuilder: withPending
        ? (context) => const Text('pending', textDirection: TextDirection.ltr)
        : null,
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> pumpRouter(
  WidgetTester tester, {
  FoldableRoute initial = const HomeRoute(),
  String? deepLink,
}) async {
  if (deepLink != null) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = deepLink;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
  }
  final router = createRouter(initial: initial);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Uri reportedUri(FoldableRouter router) =>
    router.routerConfig.routeInformationProvider!.value.uri;

Future<void> platformPushesUrl(WidgetTester tester, String location) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', <String, Object?>{
        'location': location,
        'state': null,
      }),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    loggedIn = true;
    gate = null;
  });

  testWidgets('starts on the initial route', (tester) async {
    final router = await pumpRouter(tester);

    expect(find.text('home'), findsOneWidget);
    expect(router.stack, [const HomeRoute()]);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('open builds the parent chain and reports the URL', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    await router.open(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(router.stack, [const UsersRoute(), const UserRoute(id: '7')]);
    expect(find.text('user 7'), findsOneWidget);
    expect(find.text('users', skipOffstage: false), findsOneWidget);
    expect(find.text('home', skipOffstage: false), findsNothing);
    expect(reportedUri(router), Uri.parse('/users/detail?id=7'));
  });

  testWidgets('open replaces the stack, including pushed pages', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    final pushed = router.push<String>(const UserRoute(id: '1'));
    await tester.pumpAndSettle();

    await router.open(const LoginRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(await pushed, isNull);
  });

  testWidgets('push adds one page and pop returns the result', (tester) async {
    final router = await pumpRouter(tester);

    final result = router.push<String>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute(), const UserRoute(id: '7')]);
    expect(find.text('user 7'), findsOneWidget);
    expect(reportedUri(router), Uri.parse('/users/detail?id=7'));

    router.pop('done');
    await tester.pumpAndSettle();

    expect(await result, 'done');
    expect(router.stack, [const HomeRoute()]);
    expect(find.text('home'), findsOneWidget);
    expect(reportedUri(router), Uri.parse('/'));
  });

  testWidgets('the same route can be pushed twice', (tester) async {
    final router = await pumpRouter(tester);

    final first = router.push<int>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();
    final second = router.push<int>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(router.stack, hasLength(3));
    expect(tester.takeException(), isNull);

    router.pop(2);
    await tester.pumpAndSettle();
    router.pop(1);
    await tester.pumpAndSettle();

    expect(await second, 2);
    expect(await first, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('FoldableRouter.of gives access from a page', (tester) async {
    final router = await pumpRouter(tester);
    final result = router.push<String>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('router pop'));
    await tester.pumpAndSettle();

    expect(await result, 'from router');
    expect(router.stack, [const HomeRoute()]);
  });

  testWidgets('Navigator.pop inside a page completes push with its result', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    final result = router.push<String>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('navigator pop'));
    await tester.pumpAndSettle();

    expect(await result, 'from navigator');
    expect(router.stack, [const HomeRoute()]);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('system back pops the top page and completes push with null', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    final result = router.push<String>(const UserRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();

    expect(await result, isNull);
    expect(router.stack, [const HomeRoute()]);
    expect(reportedUri(router), Uri.parse('/'));
  });

  testWidgets('popping the last page is a no-op left to the system', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    router.pop();
    await tester.pumpAndSettle();
    expect(router.stack, [const HomeRoute()]);

    expect(await router.routerConfig.routerDelegate.popRoute(), isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('redirect on open', (tester) async {
    final router = await pumpRouter(tester);
    loggedIn = false;

    // The guard sits on the parent of the target.
    await router.open(const SettingsRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);
    expect(reportedUri(router), Uri.parse('/login'));
  });

  testWidgets('redirect on push pushes the redirect target', (tester) async {
    final router = await pumpRouter(tester);
    loggedIn = false;

    final result = router.push<String>(const SettingsRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute(), const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);

    router.pop('signed in');
    expect(await result, 'signed in');
  });

  testWidgets('refresh kicks the user out when a redirect now objects', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    await router.open(const SettingsRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const AccountRoute(), const SettingsRoute()]);

    await router.refresh();
    await tester.pumpAndSettle();
    expect(router.stack, [const AccountRoute(), const SettingsRoute()]);

    loggedIn = false;
    await router.refresh();
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);
    expect(find.text('settings', skipOffstage: false), findsNothing);
  });

  testWidgets('old page stays while an async redirect is pending', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    gate = Completer<void>();
    final notifications = <bool>[];
    router.isNavigating.addListener(
      () => notifications.add(router.isNavigating.value),
    );

    var done = false;
    unawaited(router.open(const SlowRoute()).then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(router.isNavigating.value, isTrue);
    expect(done, isFalse);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('slow'), findsNothing);
    expect(router.stack, [const HomeRoute()]);
    expect(reportedUri(router), Uri.parse('/'));

    gate!.complete();
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(router.isNavigating.value, isFalse);
    expect(notifications, [true, false]);
    expect(find.text('slow'), findsOneWidget);
    expect(router.stack, [const SlowRoute()]);
  });

  testWidgets('latest navigation wins', (tester) async {
    final router = await pumpRouter(tester);
    gate = Completer<void>();

    var olderDone = false;
    unawaited(router.open(const SlowRoute()).then((_) => olderDone = true));
    await tester.pump();
    await router.open(const UsersRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const UsersRoute()]);
    expect(router.isNavigating.value, isFalse);

    gate!.complete();
    await tester.pumpAndSettle();

    expect(olderDone, isTrue);
    expect(router.stack, [const UsersRoute()]);
    expect(find.text('users'), findsOneWidget);
  });

  testWidgets('a throwing redirect cancels the navigation', (tester) async {
    final router = await pumpRouter(tester);

    await expectLater(router.open(const BrokenRoute()), throwsStateError);
    await expectLater(router.push<void>(const BrokenRoute()), throwsStateError);
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute()]);
    expect(router.isNavigating.value, isFalse);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('too many redirects fail with a dedicated exception', (
    tester,
  ) async {
    final router = await pumpRouter(tester);

    await expectLater(
      router.open(const LoopRoute(0)),
      throwsA(isA<FoldableRedirectException>()),
    );
    expect(router.stack, [const HomeRoute()]);
  });

  testWidgets('deep link with query params builds the right route', (
    tester,
  ) async {
    final router = await pumpRouter(
      tester,
      deepLink: '/users/detail?id=7&tab=posts',
    );

    expect(router.stack, [
      const UsersRoute(),
      const UserRoute(id: '7', tab: 'posts'),
    ]);
    expect((router.stack.last as UserRoute).tab, 'posts');
    expect(find.text('user 7'), findsOneWidget);
    expect(find.text('home', skipOffstage: false), findsNothing);
  });

  testWidgets('URL pushed by the platform at runtime is opened', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    unawaited(router.push<void>(const LoginRoute()));
    await tester.pumpAndSettle();

    await platformPushesUrl(tester, '/users/detail?id=42');

    expect(router.stack, [const UsersRoute(), const UserRoute(id: '42')]);
    expect(find.text('user 42'), findsOneWidget);
  });

  testWidgets('deep link goes through redirects', (tester) async {
    loggedIn = false;
    final router = await pumpRouter(tester, deepLink: '/account');

    expect(router.stack, [const LoginRoute()]);
    expect(reportedUri(router), Uri.parse('/login'));
  });

  testWidgets('unknown URL shows notFound', (tester) async {
    final router = await pumpRouter(tester, deepLink: '/nope?x=1');

    expect(find.text('not found: /nope?x=1'), findsOneWidget);
    expect(router.stack, isEmpty);

    await router.open(const UsersRoute());
    await tester.pumpAndSettle();
    expect(find.text('users'), findsOneWidget);

    await platformPushesUrl(tester, '/still-nope');
    expect(find.text('not found: /still-nope'), findsOneWidget);
    expect(find.text('users', skipOffstage: false), findsNothing);
  });

  testWidgets('a factory that throws shows notFound', (tester) async {
    await pumpRouter(tester, deepLink: '/users/detail');

    expect(find.text('not found: /users/detail'), findsOneWidget);
  });

  testWidgets('pendingBuilder is shown while the first redirect is pending', (
    tester,
  ) async {
    gate = Completer<void>();
    final router = createRouter(initial: const SlowRoute());
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pump();

    expect(find.text('pending'), findsOneWidget);
    expect(find.text('slow'), findsNothing);
    expect(router.isNavigating.value, isTrue);
    expect(router.stack, isEmpty);

    gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('pending'), findsNothing);
    expect(find.text('slow'), findsOneWidget);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('without pendingBuilder nothing is shown while pending', (
    tester,
  ) async {
    gate = Completer<void>();
    final router = createRouter(initial: const SlowRoute(), withPending: false);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pump();

    expect(find.byType(Navigator), findsNothing);
    expect(tester.takeException(), isNull);

    gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('slow'), findsOneWidget);
  });
}
