import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _HomeRoute extends FoldableRoute {
  const _HomeRoute();

  @override
  String get path => '/home';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class _SecondRoute extends FoldableRoute {
  const _SecondRoute();

  @override
  String get path => '/second';

  @override
  Widget build(BuildContext context) => const Text('second');
}

class _DetailRoute extends FoldableRoute {
  const _DetailRoute({this.id});

  final String? id;

  @override
  String get path => '/detail';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) => Text('detail ${id ?? ''}');
}

/// Redirects to [_SecondRoute] and records that it ran.
class _GuardedRoute extends FoldableRoute {
  const _GuardedRoute(this.log);

  final List<String> log;

  @override
  String get path => '/guarded';

  @override
  Widget build(BuildContext context) => const Text('guarded');

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) {
    log.add('route:${state.route.path}');
    return const _SecondRoute();
  }
}

/// Records the state its redirect gets and keeps the route.
class _SpyRoute extends FoldableRoute {
  const _SpyRoute(this.states);

  final List<FoldableRouteState> states;

  @override
  String get path => '/spy';

  @override
  Widget build(BuildContext context) => const Text('spy');

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) {
    states.add(state);
    return null;
  }
}

class _NotFoundRoute extends FoldableRoute {
  const _NotFoundRoute(this.uri);

  final Uri uri;

  @override
  String get path => uri.path;

  @override
  String get location => uri.toString();

  @override
  Widget build(BuildContext context) => const Text('not found');
}

FoldableRoute? _match(Uri uri) {
  return switch (uri.path) {
    '/home' => const _HomeRoute(),
    '/second' => const _SecondRoute(),
    '/detail' => _DetailRoute(id: RouteQuery.fromUri(uri).string('id')),
    _ => null,
  };
}

FoldableRouter _router({
  FoldableRedirect? redirect,
  Object? Function()? stateExtra,
  int maxRedirects = 5,
  bool throwOnRedirectLoop = true,
  FoldableBackTarget? backTarget,
}) {
  final router = FoldableRouter.branches(
    branches: const [_HomeRoute(), _SecondRoute()],
    config: FoldableRouterConfig(
      matcher: _match,
      notFound: _NotFoundRoute.new,
      redirect: redirect,
      stateExtra: stateExtra,
      maxRedirects: maxRedirects,
      throwOnRedirectLoop: throwOnRedirectLoop,
      backTarget: backTarget,
    ),
  );
  addTearDown(router.dispose);
  return router;
}

/// Pumps an app and returns a [BuildContext] inside it.
Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return context;
}

/// Always redirects to the other of [_DetailRoute] and [_SecondRoute].
FoldableRoute _flip(FoldableRouteState state) {
  return state.route is _DetailRoute
      ? const _SecondRoute()
      : const _DetailRoute();
}

void main() {
  group('redirects', () {
    testWidgets('a loop of synchronous redirects throws', (tester) async {
      final context = await _pumpContext(tester);
      var calls = 0;
      final router = _router(
        maxRedirects: 4,
        redirect: (_, state) {
          calls++;
          return _flip(state);
        },
      );

      expect(
        () => router.resolve(const _DetailRoute(), context: context),
        throwsA(
          isA<FlutterError>().having(
            (error) => error.toString(),
            'message',
            allOf(
              contains('Too many redirects (more than 4)'),
              contains('/detail -> /second -> /detail -> /second -> /detail'),
            ),
          ),
        ),
      );
      // Four redirects are followed, the fifth is the loop.
      expect(calls, 5);
    });

    testWidgets('a loop of asynchronous redirects throws', (tester) async {
      final context = await _pumpContext(tester);
      var calls = 0;
      final router = _router(
        maxRedirects: 3,
        redirect: (_, state) async {
          calls++;
          return _flip(state);
        },
      );

      final result = router.resolve(const _DetailRoute(), context: context);

      expect(result, isA<Future<FoldableRoute?>>());
      await expectLater(result, throwsA(isA<FlutterError>()));
      expect(calls, 4);
    });

    testWidgets('without throwOnRedirectLoop a loop shows not found and is '
        'reported', (tester) async {
      final context = await _pumpContext(tester);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      final router = _router(
        maxRedirects: 3,
        throwOnRedirectLoop: false,
        redirect: (_, state) => _flip(state),
      );

      final result = router.resolve(const _DetailRoute(), context: context);

      // Neither route of the loop is shown, they may be guarded.
      expect(result, isA<_NotFoundRoute>());
      expect((result! as _NotFoundRoute).uri.toString(), '/detail');
      expect(reported, hasLength(1));
      expect(reported.single.exception.toString(), contains('Too many'));
    });

    testWidgets('a chain of exactly maxRedirects redirects is not a loop', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      FoldableRoute? hop(FoldableRouteState state) =>
          switch (state.route.path) {
            '/detail' => const _SecondRoute(),
            '/second' => const _HomeRoute(),
            _ => null,
          };

      expect(
        _router(
          maxRedirects: 2,
          redirect: (_, state) => hop(state),
        ).resolve(const _DetailRoute(), context: context),
        isA<_HomeRoute>(),
      );
      expect(
        () => _router(
          maxRedirects: 1,
          redirect: (_, state) => hop(state),
        ).resolve(const _DetailRoute(), context: context),
        throwsFlutterError,
      );
    });

    testWidgets('a cap of zero allows no redirect at all', (tester) async {
      final context = await _pumpContext(tester);
      final log = <String>[];
      final capped = _router(maxRedirects: 0);
      final router = _router(maxRedirects: 2);

      // A route that keeps itself needs none.
      expect(capped.resolve(_SpyRoute([]), context: context), isA<_SpyRoute>());
      expect(
        () => capped.resolve(_GuardedRoute(log), context: context),
        throwsFlutterError,
      );

      // Within the cap the redirect is followed until the route stays.
      expect(
        router.resolve(_GuardedRoute(log), context: context),
        isA<_SecondRoute>(),
      );
    });

    testWidgets('the route redirect runs before the global one', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final log = <String>[];
      final router = _router(
        redirect: (_, state) {
          log.add('global:${state.route.path}');
          // Would win if it ran first.
          return state.route is _GuardedRoute ? const _HomeRoute() : null;
        },
      );

      final result = router.resolve(_GuardedRoute(log), context: context);

      expect(result, isA<_SecondRoute>());
      // The global redirect never saw the guarded route: the route redirect
      // answered first, and the global one only checked where it led.
      expect(log, ['route:/guarded', 'global:/second']);
    });

    testWidgets('the global redirect runs when the route keeps itself', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final states = <FoldableRouteState>[];
      final router = _router(
        redirect: (_, state) =>
            state.route is _SpyRoute ? const _HomeRoute() : null,
      );

      final result = router.resolve(_SpyRoute(states), context: context);

      expect(result, isA<_HomeRoute>());
      expect(states, hasLength(1));
    });

    testWidgets('stateExtra reaches FoldableRouteState.extra', (tester) async {
      final context = await _pumpContext(tester);
      final states = <FoldableRouteState>[];
      final router = _router(
        stateExtra: () => 'user-1',
        redirect: (_, state) {
          states.add(state);
          return null;
        },
      );
      final spy = _SpyRoute(states);

      router.resolve(spy, context: context, uri: Uri.parse('/spy?x=1'));

      // The route redirect first, then the global one.
      expect(states, hasLength(2));
      for (final state in states) {
        expect(state.extra, 'user-1');
        expect(state.route, same(spy));
        expect(state.uri.toString(), '/spy?x=1');
      }
    });

    testWidgets('extra is null without stateExtra, and uri defaults to the '
        'route location', (tester) async {
      final context = await _pumpContext(tester);
      final states = <FoldableRouteState>[];
      final router = _router();

      router.resolve(_SpyRoute(states), context: context);

      expect(states.single.extra, isNull);
      expect(states.single.uri.toString(), '/spy');
    });

    testWidgets('stateExtra is read again for every navigation', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final states = <FoldableRouteState>[];
      var loggedIn = false;
      final router = _router(stateExtra: () => loggedIn);

      router.resolve(_SpyRoute(states), context: context);
      loggedIn = true;
      router.resolve(_SpyRoute(states), context: context);

      expect(states.map((state) => state.extra), [false, true]);
    });
  });

  group('FoldableRouterDelegate', () {
    FoldableRouterDelegate delegateOf(
      FoldableRouter router,
      BuildContext context,
    ) {
      final delegate = FoldableRouterDelegate(
        router: router,
        navigatorKey: GlobalKey<NavigatorState>(),
        builder: (_) => const SizedBox.shrink(),
      );
      // The delegate points redirects at its navigator, which is not mounted
      // here: use the test app instead.
      router.rootContextOf = () => context;
      addTearDown(delegate.dispose);
      return delegate;
    }

    FoldableRoute? backToHome(FoldableRouter router) =>
        router.currentIndex == 0 ? null : const _HomeRoute();

    testWidgets('a pop that happened does nothing', (tester) async {
      final context = await _pumpContext(tester);
      final router = _router(backTarget: backToHome);
      final delegate = delegateOf(router, context);
      router.controller.openBranch(1);
      expect(router.backHasTarget, isTrue);

      delegate.onPopInvoked(true);

      expect(router.currentIndex, 1);
    });

    testWidgets('a refused pop goes to the back target', (tester) async {
      final context = await _pumpContext(tester);
      final router = _router(backTarget: backToHome);
      final delegate = delegateOf(router, context);
      router.controller.openBranch(1);
      expect(router.backHasTarget, isTrue);

      delegate.onPopInvoked(false);

      expect(router.currentIndex, 0);
      expect(router.currentUri.toString(), '/home');
    });

    testWidgets('a refused pop does nothing without a back target', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final router = _router();
      final delegate = delegateOf(router, context);
      expect(router.backHasTarget, isFalse);

      delegate.onPopInvoked(false);

      expect(router.currentIndex, 0);
      expect(router.pages, hasLength(1));
    });

    testWidgets('a refused pop of a page inside the stack leaves the stack', (
      tester,
    ) async {
      final context = await _pumpContext(tester);
      final router = _router(backTarget: backToHome);
      final delegate = delegateOf(router, context);
      router.controller.openBranch(1);
      router.push<void>(const _DetailRoute(id: '1'));
      // The page above the root can pop, so back must not leave the branch.
      expect(router.backHasTarget, isFalse);

      delegate.onPopInvoked(false);

      expect(router.currentIndex, 1);
      expect(router.pages, hasLength(2));
    });

    testWidgets('reports the address and applies a new one', (tester) async {
      final context = await _pumpContext(tester);
      final router = _router();
      final delegate = delegateOf(router, context);
      expect(delegate.currentConfiguration.toString(), '/home');

      await delegate.setNewRoutePath(Uri.parse('/second'));

      expect(router.currentIndex, 1);
      expect(delegate.currentConfiguration.toString(), '/second');
    });
  });

  group('FoldableRouteInformationParser', () {
    test('round-trips a Uri', () async {
      const parser = FoldableRouteInformationParser();
      final uri = Uri.parse('/detail?id=3&name=a%20b#top');

      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: uri),
      );
      final restored = parser.restoreRouteInformation(parsed);

      expect(parsed, uri);
      expect(restored?.uri, uri);
    });

    test('round-trips the root', () async {
      const parser = FoldableRouteInformationParser();
      final uri = Uri.parse('/');

      final parsed = await parser.parseRouteInformation(
        RouteInformation(uri: uri),
      );

      expect(parser.restoreRouteInformation(parsed)?.uri, uri);
    });
  });

  group('RouteQuery', () {
    final query = RouteQuery.fromUri(
      Uri.parse(
        '/x?i=42&neg=-7&d=1.5&t=true&f=false&bad=abc&yes=TRUE&one=1&empty=',
      ),
    );

    test('string returns the raw value', () {
      expect(query.string('bad'), 'abc');
      expect(query.string('empty'), '');
      expect(query.string('missing'), isNull);
    });

    test('integer parses ints and gives null for anything else', () {
      expect(query.integer('i'), 42);
      expect(query.integer('neg'), -7);
      expect(query.integer('d'), isNull);
      expect(query.integer('bad'), isNull);
      expect(query.integer('empty'), isNull);
      expect(query.integer('missing'), isNull);
    });

    test('decimal parses numbers and gives null for anything else', () {
      expect(query.decimal('d'), 1.5);
      expect(query.decimal('i'), 42.0);
      expect(query.decimal('neg'), -7.0);
      expect(query.decimal('bad'), isNull);
      expect(query.decimal('empty'), isNull);
      expect(query.decimal('missing'), isNull);
    });

    test('boolean only accepts true and false', () {
      expect(query.boolean('t'), isTrue);
      expect(query.boolean('f'), isFalse);
      expect(query.boolean('yes'), isNull);
      expect(query.boolean('one'), isNull);
      expect(query.boolean('bad'), isNull);
      expect(query.boolean('missing'), isNull);
    });

    test('can be built from a map', () {
      const direct = RouteQuery({'id': '7'});

      expect(direct.integer('id'), 7);
      expect(direct.string('other'), isNull);
    });

    test('build leaves out null values', () {
      expect(
        RouteQuery.build('/detail', {'id': 3, 'name': null, 'on': true}),
        '/detail?id=3&on=true',
      );
      expect(RouteQuery.build('/p', {'ratio': 1.5}), '/p?ratio=1.5');
    });

    test('build has no question mark without parameters', () {
      expect(RouteQuery.build('/detail', {'id': null}), '/detail');
      expect(RouteQuery.build('/detail', {}), '/detail');
    });

    test('build output reads back, whatever the characters', () {
      final location = RouteQuery.build('/p', {'q': 'a b&c=d/é', 'n': 5});
      final read = RouteQuery.fromUri(Uri.parse(location));

      expect(read.string('q'), 'a b&c=d/é');
      expect(read.integer('n'), 5);
    });

    test('a route builds its location from its query', () {
      expect(const _DetailRoute().location, '/detail');
      expect(const _DetailRoute(id: '7').location, '/detail?id=7');
    });
  });

  test('the delegate hands its config to the router', () {
    final router = FoldableRouter.branches(branches: const [_HomeRoute()]);
    addTearDown(router.dispose);
    expect(() => router.routeOf('/second'), throwsStateError);

    final delegate = FoldableRouterDelegate(
      router: router,
      config: FoldableRouterConfig(
        matcher: (uri) => uri.path == '/second' ? const _SecondRoute() : null,
        notFound: (uri) => const _DetailRoute(id: 'missing'),
      ),
      navigatorKey: GlobalKey<NavigatorState>(),
      builder: (context) => const SizedBox.shrink(),
    );
    addTearDown(delegate.dispose);

    expect(router.routeOf('/second').path, '/second');
    expect(router.routeOf('/nothing').path, '/detail');
  });
}
