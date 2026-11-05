import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A route with a URL and nothing else; redirects come from the config.
class _R extends FoldableRoute {
  const _R(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) => Text('screen $path');
}

class _Private extends FoldableRoute {
  const _Private();

  @override
  String get path => '/private';

  @override
  bool get deepLinkable => false;

  @override
  Widget build(BuildContext context) => const Text('private');
}

const _roots = [_R('/home'), _R('/settings')];

FoldableRouter _make({
  FoldableRedirect? redirect,
  FoldableRouteMatcher? matcher,
  int maxRedirects = 5,
  bool throwOnRedirectLoop = true,
  List<FoldableRoute> roots = _roots,
}) {
  final router = FoldableRouter(
    roots: roots,
    config: FoldableRouterConfig(
      matcher: matcher ?? (uri) => _R(uri.path),
      notFound: (uri) => _R('/not-found${uri.path}'),
      redirect: redirect,
      maxRedirects: maxRedirects,
      throwOnRedirectLoop: throwOnRedirectLoop,
    ),
  );
  addTearDown(router.dispose);
  return router;
}

/// Pumps an app and returns a [BuildContext] inside it.
Future<BuildContext> _pumpApp(WidgetTester tester) async {
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

/// Pumps an app and points the router's redirects at it.
Future<void> _attach(WidgetTester tester, FoldableRouter router) async {
  final context = await _pumpApp(tester);
  router.rootContextOf = () => context;
}

List<String?> _names(FoldableRouter router, [int? branch]) => [
  for (final page in router.controller.pagesOf(branch ?? router.currentIndex))
    page.name,
];

/// Collects what [FlutterError.reportError] gets instead of failing the test.
List<FlutterErrorDetails> _captureErrors() {
  final reported = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  addTearDown(() => FlutterError.onError = previous);
  return reported;
}

void main() {
  group('push follows the redirects', () {
    testWidgets('a guard cannot be skipped by pushing', (tester) async {
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/admin' ? const _R('/sign-in') : null,
      );
      await _attach(tester, router);

      final result = router.push<String>(const _R('/admin'));

      // Synchronous redirects: the page is there before push returns.
      expect(_names(router), ['/home', '/sign-in']);
      router.pop('done');
      expect(await result, 'done');
    });

    testWidgets('the result of a different route is ignored when it is not a '
        'T', (tester) async {
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/admin' ? const _R('/sign-in') : null,
      );
      await _attach(tester, router);

      final result = router.push<String>(const _R('/admin'));
      router.pop(42);

      expect(await result, isNull);
    });

    testWidgets('a route that keeps itself is pushed at once', (tester) async {
      final router = _make();
      await _attach(tester, router);

      final result = router.push<int>(const _R('/detail'));

      expect(_names(router), ['/home', '/detail']);
      router.pop(7);
      expect(await result, 7);
    });

    testWidgets('pushLocation and pushAndRemoveUntil redirect too', (
      tester,
    ) async {
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/admin' ? const _R('/sign-in') : null,
      );
      await _attach(tester, router);

      router.pushLocation('/admin?x=1');
      expect(_names(router), ['/home', '/sign-in']);

      router.pushAndRemoveUntil<void>(
        const _R('/admin'),
        (page) => page == router.pages.first,
      );
      expect(_names(router), ['/home', '/sign-in']);
    });

    testWidgets('pushAndReplace redirects and replaces above the root', (
      tester,
    ) async {
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/admin' ? const _R('/sign-in') : null,
      );
      await _attach(tester, router);

      // At the root it pushes instead of replacing it.
      router.pushAndReplace<void>(const _R('/detail'));
      expect(_names(router), ['/home', '/detail']);

      router.pushAndReplace<void>(const _R('/admin'));
      expect(_names(router), ['/home', '/sign-in']);

      router.pushReplacementLocation('/detail');
      expect(_names(router), ['/home', '/detail']);
    });

    testWidgets('the redirects get the caller context', (tester) async {
      BuildContext? seen;
      final router = _make(
        redirect: (context, state) {
          seen = context;
          return null;
        },
      );
      await _attach(tester, router);
      final caller = await _pumpApp(tester);

      router.push<void>(const _R('/detail'), context: caller);

      expect(seen, same(caller));
    });

    testWidgets('an asynchronous redirect lands after it resolves', (
      tester,
    ) async {
      final gate = Completer<FoldableRoute?>();
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/admin' ? gate.future : null,
      );
      await _attach(tester, router);

      final result = router.push<void>(const _R('/admin'));
      await tester.pump();
      expect(_names(router), ['/home']);

      gate.complete(const _R('/sign-in'));
      await tester.pump();
      expect(_names(router), ['/home', '/sign-in']);
      router.pop();
      await result;
    });

    testWidgets('pushes land in the order they were made', (tester) async {
      final gate = Completer<FoldableRoute?>();
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/slow' ? gate.future : null,
      );
      await _attach(tester, router);

      router.push<void>(const _R('/slow'));
      router.push<void>(const _R('/fast'));
      await tester.pump();
      // The fast one waits for the slow one.
      expect(_names(router), ['/home']);

      gate.complete(null);
      await tester.pump();
      await tester.pump();
      expect(_names(router), ['/home', '/slow', '/fast']);
    });

    testWidgets('a push waiting for a redirect stays on its own branch', (
      tester,
    ) async {
      final gate = Completer<FoldableRoute?>();
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/slow' ? gate.future : null,
      );
      await _attach(tester, router);

      router.push<void>(const _R('/slow'));
      router.controller.goBranch(1);
      gate.complete(null);
      await tester.pump();

      expect(_names(router, 0), ['/home', '/slow']);
      expect(_names(router, 1), ['/settings']);
    });

    testWidgets('a go that starts meanwhile cancels a waiting push', (
      tester,
    ) async {
      final gate = Completer<FoldableRoute?>();
      final router = _make(
        redirect: (_, state) =>
            state.route.path == '/slow' ? gate.future : null,
      );
      await _attach(tester, router);

      final result = router.push<void>(const _R('/slow'));
      router.go(null, const _R('/elsewhere'));
      await tester.pump();
      gate.complete(null);
      await tester.pump();

      expect(_names(router), ['/home', '/elsewhere']);
      await result;
    });

    testWidgets('a redirect that throws abandons the push', (tester) async {
      final reported = _captureErrors();
      final router = _make(
        redirect: (_, state) {
          if (state.route.path == '/boom') throw StateError('boom');
          return null;
        },
      );
      await _attach(tester, router);

      final result = router.push<String>(const _R('/boom'));

      expect(await result, isNull);
      expect(_names(router), ['/home']);
      expect(reported.single.exception, isA<StateError>());
    });

    testWidgets('a push made before the first build waits for a context', (
      tester,
    ) async {
      final router = _make();
      final context = await _pumpApp(tester);

      router.push<void>(const _R('/detail'));
      await tester.pump();
      expect(_names(router), ['/home']);

      router.rootContextOf = () => context;
      await tester.pump();
      expect(_names(router), ['/home', '/detail']);
    });

    testWidgets('a disposed router drops the waiting push', (tester) async {
      final router = FoldableRouter(
        roots: _roots,
        config: FoldableRouterConfig(
          matcher: (uri) => _R(uri.path),
          notFound: (uri) => _R(uri.path),
        ),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      final result = router.push<void>(const _R('/detail'));
      router.dispose();
      await tester.pump();

      await expectLater(result, completion(isNull));
    });
  });

  group('redirect loops', () {
    FoldableRedirect pingPong() =>
        (_, state) =>
            state.route.path == '/a' ? const _R('/b') : const _R('/a');

    testWidgets('throw while developing and abandon the navigation', (
      tester,
    ) async {
      final reported = _captureErrors();
      final router = _make(redirect: pingPong());
      await _attach(tester, router);

      router.go(null, const _R('/a'));
      await tester.pump();

      expect(_names(router), ['/home']);
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<FlutterError>());
      expect(reported.single.exception.toString(), contains('/a -> /b'));
    });

    testWidgets('show not found in production, and still report', (
      tester,
    ) async {
      final reported = _captureErrors();
      final router = _make(redirect: pingPong(), throwOnRedirectLoop: false);
      await _attach(tester, router);

      router.go(null, const _R('/a'));
      await tester.pump();

      expect(_names(router), ['/home', '/not-found/a']);
      expect(reported, hasLength(1));
    });

    testWidgets('a push is not let through by a loop', (tester) async {
      final reported = _captureErrors();
      final router = _make(redirect: pingPong(), throwOnRedirectLoop: false);
      await _attach(tester, router);

      router.push<void>(const _R('/a'));

      expect(_names(router), ['/home', '/not-found/a']);
      expect(reported, hasLength(1));
    });
  });

  group('the root URL', () {
    FoldableRoute? knowsNoRoot(Uri uri) =>
        uri.path == '/home' || uri.path == '/settings' ? _R(uri.path) : null;

    testWidgets('shows the first root when the matcher does not know /', (
      tester,
    ) async {
      final router = _make(matcher: knowsNoRoot);
      await _attach(tester, router);
      router.controller.goBranch(1);

      router.goUri(Uri.parse('/'));
      await tester.pump();

      expect(router.currentIndex, 0);
      expect(_names(router), ['/home']);
    });

    testWidgets('leaves other unknown URLs to notFound', (tester) async {
      final router = _make(matcher: knowsNoRoot);
      await _attach(tester, router);

      router.goUri(Uri.parse('/missing'));
      await tester.pump();

      expect(_names(router), ['/home', '/not-found/missing']);
    });

    testWidgets('a matcher that knows / wins', (tester) async {
      final router = _make(
        matcher: (uri) =>
            uri.path == '/' ? const _R('/welcome') : knowsNoRoot(uri),
      );
      await _attach(tester, router);

      router.goUri(Uri.parse('/'));
      await tester.pump();

      expect(_names(router), ['/home', '/welcome']);
    });

    testWidgets('a router with no roots still uses notFound', (tester) async {
      final router = FoldableRouter(
        roots: const [],
        allowEmptyRoots: true,
        config: FoldableRouterConfig(
          matcher: (_) => null,
          notFound: (uri) => _R('/not-found${uri.path}'),
        ),
      );
      addTearDown(router.dispose);
      await _attach(tester, router);

      expect(router.routeOf('/').path, '/not-found/');
    });
  });

  group('a route navigates itself', () {
    testWidgets('push, pushAndReplace and go use the router of the delegate', (
      tester,
    ) async {
      final router = _make();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: FoldableRouterDelegate(
            router: router,
            navigatorKey: GlobalKey<NavigatorState>(),
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
          routeInformationParser: const FoldableRouteInformationParser(),
        ),
      );

      unawaited(const _R('/a').push<void>(context));
      expect(_names(router).last, '/a');

      unawaited(const _R('/b').pushAndReplace<void>(context));
      expect(_names(router).last, '/b');
      expect(_names(router), isNot(contains('/a')));

      unawaited(const _R('/c').pushAndRemoveUntil<void>(context, (_) => false));
      expect(_names(router).last, '/c');
    });
  });

  testWidgets('a route that is not deepLinkable cannot be opened by URL', (
    tester,
  ) async {
    final router = _make(
      matcher: (uri) =>
          uri.path == '/private' ? const _Private() : _R(uri.path),
    );
    await _attach(tester, router);

    expect(router.routeOf('/private').path, '/not-found/private');

    router.goUri(Uri.parse('/private'));
    expect(_names(router).last, '/not-found/private');

    // From code it still works, and has no URL.
    unawaited(router.push<void>(const _Private()));
    expect(router.currentUri.path, isNot('/private'));
  });
}
