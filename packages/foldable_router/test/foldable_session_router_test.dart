import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _R extends FoldableRoute {
  const _R(this.path, {this.session});

  @override
  final String path;

  @override
  final String? session;

  @override
  Widget build(BuildContext context) => Text('screen $path');
}

class _B extends BranchRoute {
  const _B(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) => Text('screen $path');
}

FoldableRoute? _match(Uri uri) => _R(uri.path);

final _config = FoldableRouterConfig(
  matcher: _match,
  notFound: (uri) => _R(uri.path),
);

FoldableSession _session(
  String id,
  String root, {
  bool disposeOnLeave = false,
  bool deepLinkable = false,
  Widget Function(Widget body)? frame,
}) {
  return FoldableSessionSplit(
    branches: [_B(root)],
    id: id,
    disposeOnLeave: disposeOnLeave,
    deepLinkable: deepLinkable,

    shell: (context, controller, navigator) =>
        navigator((context, body, secondary) {
          final child = body;
          return frame == null ? child : frame(child);
        }),
  );
}

extension on FoldableSessionSplit {
  FoldableSession copyLocked() => FoldableSessionSplit(
    id: id,
    branches: branches,
    shell: shell,
    closable: false,
  );
}

void main() {
  var current = 'guest';

  FoldableSessionRouter build({bool disposeMain = false}) {
    final sessions = [
      _session('guest', '/signIn'),
      _session(
        'onboarding',
        '/welcome',
        frame: (body) => Column(
          children: [
            const Text('bare'),
            Expanded(child: body),
          ],
        ),
      ),
      _session(
        'main',
        '/home',
        disposeOnLeave: disposeMain,
        frame: (body) => Column(
          children: [
            const Text('scaffold'),
            Expanded(child: body),
          ],
        ),
      ),
    ];
    // The first session is the base: the one `current` names comes first.
    sessions.sort(
      (a, b) => (b.id == current ? 1 : 0).compareTo(a.id == current ? 1 : 0),
    );
    return FoldableSessionRouter(config: _config, sessions: sessions);
  }

  Future<void> pumpApp(
    WidgetTester tester,
    FoldableSessionRouter router,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: router,
          builder: (context, _) => router.buildShell(context),
        ),
      ),
    );
    // Pushes run the redirects, which need a context.
    router.rootContextOf = () => tester.element(find.byType(MaterialApp));
  }

  setUp(() => current = 'guest');

  testWidgets('shows the shell of the initial session', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);

    expect(find.text('screen /signIn'), findsOneWidget);
    expect(find.text('scaffold'), findsNothing);

    current = 'onboarding';
    router.resetSession(current);
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: router.buildShell)),
    );

    expect(find.text('bare'), findsOneWidget);
    expect(find.text('scaffold'), findsNothing);
    expect(find.text('screen /welcome'), findsOneWidget);

    current = 'main';
    router.resetSession(current);
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: router.buildShell)),
    );

    expect(find.text('scaffold'), findsOneWidget);
    expect(find.text('screen /home'), findsOneWidget);
  });

  testWidgets('resetSession puts one session on screen and notifies', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    var notified = 0;
    router.addListener(() => notified++);

    router.resetSession('main');
    expect(notified, 1);
    expect(router.activeSessionId, 'main');
    expect(router.openSessionIds, ['main']);
  });

  testWidgets('navigation acts on the session on screen', (tester) async {
    current = 'main';
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);

    router.push<void>(const _R('/detail'));
    await tester.pump();

    expect(router.active.pages.length, 2);
    expect(router.currentUri.path, '/detail');
    expect(router.routerOf('guest').pages.length, 1);

    router.back();
    await tester.pump();
    expect(router.currentUri.path, '/home');
  });

  testWidgets('keeps the stacks of a session it left', (tester) async {
    current = 'main';
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);
    router.push<void>(const _R('/detail'));

    current = 'guest';
    router.resetSession(current);
    current = 'main';
    router.resetSession(current);

    expect(router.active.pages.length, 2);
  });

  testWidgets('disposeOnLeave starts the session again on return', (
    tester,
  ) async {
    current = 'main';
    final router = build(disposeMain: true);
    addTearDown(router.dispose);
    await pumpApp(tester, router);
    router.push<void>(const _R('/detail'));
    await tester.pump();

    current = 'guest';
    router.resetSession(current);
    await pumpApp(tester, router);
    await tester.pump();

    current = 'main';
    router.resetSession(current);
    expect(router.active.pages.length, 1);
  });

  testWidgets('observers reach sessions created later', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);
    final events = <FoldableNavigationEvent>[];
    router.addObserver(_Recorder(events));

    current = 'main';
    router.resetSession(current);
    router.push<void>(const _R('/detail'));

    expect(events, hasLength(1));
  });

  testWidgets('replaceSession shows a route in the new session', (
    tester,
  ) async {
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);
    router.rootContextOf = () => tester.element(find.byType(Builder).first);

    router.replaceSession('main', route: const _R('/detail'));
    expect(router.activeSessionId, 'main');
    expect(router.currentUri.path, '/detail');
  });

  testWidgets('a URL switches to the deep linkable session that knows it', (
    tester,
  ) async {
    final router = FoldableSessionRouter(
      // The matcher says which session owns each URL.
      config: FoldableRouterConfig(
        matcher: (uri) => switch (uri.path) {
          '/signIn' => const _R('/signIn', session: 'guest'),
          '/welcome' => const _R('/welcome', session: 'onboarding'),
          '/home' => const _R('/home', session: 'main'),
          _ => null,
        },
        notFound: (uri) => _R(uri.path),
      ),
      sessions: [
        _session('guest', '/signIn'),
        _session('onboarding', '/welcome', deepLinkable: true),
        _session('main', '/home'),
      ],
    );
    addTearDown(router.dispose);

    router.openUri(Uri.parse('/home'));
    expect(router.activeSessionId, 'guest');

    router.openUri(Uri.parse('/welcome'));
    expect(router.activeSessionId, 'onboarding');
  });

  testWidgets('a session can use the stack navigator', (tester) async {
    current = 'main';
    final router = FoldableSessionRouter(
      config: _config,
      sessions: [
        FoldableSessionStack(initRoute: const _R('/home'), id: 'main'),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(tester, router);

    expect(find.text('screen /home'), findsOneWidget);

    router.push<void>(const _R('/detail'));
    await tester.pumpAndSettle();

    // Only the top page is mounted, not the page below it.
    expect(find.text('screen /detail'), findsOneWidget);
    expect(find.text('screen /home', skipOffstage: false), findsNothing);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('screen /home'), findsOneWidget);
  });

  test('an unknown session id throws', () {
    final router = FoldableSessionRouter(
      config: _config,
      sessions: [_session('main', '/home')],
    );
    addTearDown(router.dispose);

    expect(() => router.openSession<void>('nope'), throwsStateError);
  });

  test('the config is shared by every session', () {
    final router =
        FoldableSessionRouter(
          sessions: [_session('a', '/a'), _session('b', '/b')],
        )..attachConfig(
          FoldableRouterConfig(
            matcher: (uri) => uri.path == '/known' ? const _R('/known') : null,
            notFound: (uri) => _R('/shared${uri.path}'),
          ),
        );
    addTearDown(router.dispose);

    expect(router.routerOf('a').routeOf('/zzz').path, '/shared/zzz');
    expect(router.routerOf('b').routeOf('/zzz').path, '/shared/zzz');
    expect(router.routerOf('b').routeOf('/known').path, '/known');
  });

  group('refresh', () {
    var loggedIn = false;
    Completer<void>? gate;
    final denied = <String>[];
    var noSession = 0;

    // A condition that reads the app state, after [gate] if one is set.
    FutureOr<bool> Function(BuildContext) when(bool Function() holds) =>
        (_) async {
          await gate?.future;
          return holds();
        };

    FoldableSessionRouter conditional({FoldableRouterConfig? config}) {
      return FoldableSessionRouter(
        config: config ?? _config,
        onActivationDenied: (session) => denied.add(session.id),
        onNoSession: (_) => noSession++,
        sessions: [
          FoldableSessionSplit(
            id: 'guest',
            branches: const [_B('/signIn')],
            canActivate: when(() => !loggedIn),
          ),
          FoldableSessionSplit(
            id: 'main',
            branches: const [_B('/home')],
            canActivate: when(() => loggedIn),
          ),
          FoldableSessionStack(
            id: 'checkout',
            initRoute: const _R('/cart'),
            parent: 'main',
            canBeBase: false,
          ),
        ],
      );
    }

    setUp(() {
      loggedIn = false;
      gate = null;
      denied.clear();
      noSession = 0;
    });

    test('nothing is on screen before the first refresh', () {
      final router = conditional();
      addTearDown(router.dispose);

      expect(router.isResolved, isFalse);
      expect(() => router.active, throwsStateError);
    });

    testWidgets('the first session whose condition holds becomes the base', (
      tester,
    ) async {
      final guest = conditional();
      addTearDown(guest.dispose);
      await pumpApp(tester, guest);
      await guest.refresh();
      expect(guest.activeSessionId, 'guest');

      loggedIn = true;
      final main = conditional();
      addTearDown(main.dispose);
      await pumpApp(tester, main);
      await main.refresh();
      expect(main.activeSessionId, 'main');
    });

    test('a session without conditions is the base at once', () {
      final router = FoldableSessionRouter(
        config: _config,
        sessions: [
          FoldableSessionSplit(
            id: 'overlay',
            branches: const [_B('/o')],
            canBeBase: false,
          ),
          FoldableSessionSplit(id: 'base', branches: const [_B('/b')]),
        ],
      );
      addTearDown(router.dispose);

      expect(router.activeSessionId, 'base');
    });

    testWidgets('a URL that comes first waits for the first refresh', (
      tester,
    ) async {
      gate = Completer<void>();
      loggedIn = true;
      final router = conditional();
      addTearDown(router.dispose);

      router.openUri(Uri.parse('/detail'));
      expect(router.currentUri.path, '/detail');
      await pumpApp(tester, router);
      expect(find.text('screen /home'), findsNothing);

      final refreshed = router.refresh();
      gate!.complete();
      await refreshed;
      await tester.pumpAndSettle();

      expect(router.activeSessionId, 'main');
      expect(router.currentUri.path, '/detail');
    });

    testWidgets('a URL of a session that does not exist yet is kept', (
      tester,
    ) async {
      final router = conditional(
        config: FoldableRouterConfig(
          matcher: (uri) =>
              _R(uri.path, session: uri.path == '/home' ? 'main' : null),
          notFound: (uri) => _R(uri.path),
        ),
      );
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.openUri(Uri.parse('/home'));
      await router.refresh();
      await tester.pumpAndSettle();
      expect(router.activeSessionId, 'guest');

      loggedIn = true;
      await router.refresh();
      await tester.pumpAndSettle();
      expect(router.activeSessionId, 'main');
      expect(router.currentUri.path, '/home');
    });

    testWidgets('navigation waits for a running refresh', (tester) async {
      final router = conditional();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      await router.refresh();
      expect(router.openSessionIds, ['guest']);

      loggedIn = true;
      gate = Completer<void>();
      final refreshed = router.refresh();
      final opened = router.openSession<String>('checkout');
      expect(router.isRefreshing, isTrue);
      expect(router.openSessionIds, ['guest']);

      gate!.complete();
      await refreshed;

      expect(router.openSessionIds, ['main', 'checkout']);
      router.closeSession('done');
      expect(await opened, 'done');
    });

    testWidgets('a session that does not hold is closed with its children', (
      tester,
    ) async {
      loggedIn = true;
      final router = conditional();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      await router.refresh();
      final checkout = router.openSession<String>('checkout');
      expect(router.openSessionIds, ['main', 'checkout']);
      var notified = 0;
      router.addListener(() => notified++);

      loggedIn = false;
      await router.refresh();

      expect(router.openSessionIds, ['guest']);
      expect(await checkout, isNull);
      expect(notified, greaterThan(0));
      expect(noSession, 0);
    });

    testWidgets('the session below is shown when the top one goes', (
      tester,
    ) async {
      loggedIn = true;
      final router = FoldableSessionRouter(
        config: _config,
        sessions: [
          _session('main', '/home'),
          FoldableSessionStack(
            id: 'promo',
            initRoute: const _R('/promo'),
            canActivate: (_) => loggedIn,
            canBeBase: false,
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      await router.refresh();
      router.openSession<void>('promo');
      expect(router.activeSessionId, 'promo');

      loggedIn = false;
      await router.refresh();

      expect(router.activeSessionId, 'main');
      expect(router.openSessionIds, ['main']);
    });

    testWidgets('onNoSession is called when no session is left', (
      tester,
    ) async {
      final router = FoldableSessionRouter(
        config: _config,
        onNoSession: (_) => noSession++,
        sessions: [
          FoldableSessionSplit(
            id: 'a',
            branches: const [_B('/a')],
            canActivate: (_) => loggedIn,
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      await router.refresh();
      expect(noSession, 1);
      expect(router.isResolved, isFalse);

      loggedIn = true;
      await router.refresh();
      expect(noSession, 1);
      expect(router.activeSessionId, 'a');
    });

    testWidgets('without onNoSession the refresh fails', (tester) async {
      final router = FoldableSessionRouter(
        config: _config,
        sessions: [
          FoldableSessionSplit(
            id: 'a',
            branches: const [_B('/a')],
            canActivate: (_) => false,
          ),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      await expectLater(router.refresh(), throwsStateError);
    });

    testWidgets('a session that does not exist is not activated', (
      tester,
    ) async {
      final router = conditional();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      await router.refresh();

      // openSession, replaceSession and resetSession do nothing.
      expect(await router.openSession<Object>('checkout'), isNull);
      expect(router.replaceSession('main'), isFalse);
      expect(router.resetSession('main'), isFalse);
      expect(router.openSessionIds, ['guest']);
      expect(denied, ['checkout', 'main', 'main']);

      // So does a route that names it: the navigation is dropped.
      router.open(null, const _R('/cart', session: 'checkout'));
      expect(
        await router.push<Object>(const _R('/cart', session: 'checkout')),
        isNull,
      );
      expect(router.openSessionIds, ['guest']);
      expect(router.active.pages.length, 1);

      // Once the condition holds, it opens.
      loggedIn = true;
      await router.refresh();
      router.openSession<void>('checkout');
      expect(router.openSessionIds, ['main', 'checkout']);
    });

    testWidgets('two refreshes in a row both complete', (tester) async {
      final router = conditional();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      gate = Completer<void>();
      final first = router.refresh();
      final second = router.refresh();
      loggedIn = true;
      gate!.complete();
      await Future.wait([first, second]);

      expect(router.activeSessionId, 'main');
    });
  });

  group('a stack session without initRoute', () {
    FoldableSessionRouter withEmpty() {
      return FoldableSessionRouter(
        config: _config,
        sessions: [
          _session('main', '/home'),
          FoldableSessionStack(id: 'flow'),
        ],
      );
    }

    testWidgets('starts with no page and draws nothing', (tester) async {
      final router = withEmpty();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.openSession<void>('flow');
      await tester.pumpAndSettle();

      expect(router.activeSessionId, 'flow');
      expect(router.active.pages, isEmpty);
      expect(find.textContaining('screen'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the first route fills it, and back closes the session', (
      tester,
    ) async {
      final router = withEmpty();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.openSession<void>('flow', route: const _R('/step'));
      await tester.pumpAndSettle();
      expect(find.text('screen /step'), findsOneWidget);

      // The last page is not popped, like the last route of a Navigator.
      expect(router.pop(), isFalse);
      router.open(null, const _R('/next'));
      await tester.pumpAndSettle();
      expect(router.active.pages.length, 2);

      router.back();
      await tester.pumpAndSettle();
      expect(router.active.pages.length, 1);
      router.back();
      await tester.pumpAndSettle();
      expect(router.openSessionIds, ['main']);
      expect(find.text('screen /home'), findsOneWidget);
    });

    testWidgets('a route that names it opens it', (tester) async {
      final router = withEmpty();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.open(null, const _R('/step', session: 'flow'));
      await tester.pumpAndSettle();

      expect(router.openSessionIds, ['main', 'flow']);
      expect(find.text('screen /step'), findsOneWidget);
    });
  });

  group('stacked sessions', () {
    FoldableSessionRouter stacked() {
      return FoldableSessionRouter(
        config: _config,
        sessions: [
          _session('main', '/home'),
          FoldableSessionStack(
            id: 'checkout',
            disposeOnLeave: true,
            initRoute: const _R('/cart'),
          ),
          (_session('pinned', '/pin') as FoldableSessionSplit).copyLocked(),
        ],
      );
    }

    testWidgets('opens over the base session and closes with a result', (
      tester,
    ) async {
      final router = stacked();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      expect(router.canCloseSession, isFalse);

      router.active.push(const _R('/detail'));
      final result = router.openSession<String>('checkout');
      await tester.pumpAndSettle();

      expect(router.openSessionIds, ['main', 'checkout']);
      expect(router.canCloseSession, isTrue);
      expect(find.text('screen /cart'), findsOneWidget);

      expect(router.closeSession('paid'), isTrue);
      await tester.pump();

      expect(await result, 'paid');
      expect(router.openSessionIds, ['main']);
      // The lower session kept its pages.
      expect(router.active.pages.length, 2);
      // The closed session was discarded (disposeOnLeave).
      router.openSession<void>('checkout');
      await tester.pump();
      expect(router.active.pages.length, 1);
    });

    testWidgets('a route names its session: created, then moved to the top', (
      tester,
    ) async {
      final router = stacked();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      // No session: the one on screen.
      router.open(null, const _R('/a'));
      expect(router.openSessionIds, ['main']);

      // Another session: created over the current one.
      unawaited(router.push<void>(const _R('/pay', session: 'checkout')));
      await tester.pumpAndSettle();
      expect(router.openSessionIds, ['main', 'checkout']);
      expect(find.text('screen /pay'), findsOneWidget);

      // A route of the session below moves it to the top.
      router.open(null, const _R('/b', session: 'main'));
      await tester.pumpAndSettle();
      expect(router.openSessionIds, ['checkout', 'main']);
      expect(router.activeSessionId, 'main');

      // And back again, reusing the stack that is still there.
      router.open(null, const _R('/c', session: 'checkout'));
      await tester.pumpAndSettle();
      expect(router.openSessionIds, ['main', 'checkout']);
      expect(router.closeSession(), isTrue);
      expect(router.openSessionIds, ['main']);
    });

    testWidgets('the base session cannot be closed', (tester) async {
      final router = stacked();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      expect(router.closeSession(), isFalse);
      expect(router.openSessionIds, ['main']);
    });

    testWidgets('a session that is not closable stays', (tester) async {
      final router = stacked();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.openSession<void>('pinned');
      await tester.pump();

      expect(router.canCloseSession, isFalse);
      expect(router.closeSession(), isFalse);
    });

    testWidgets('system back at the root of a session closes it', (
      tester,
    ) async {
      final router = stacked();
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      router.openSession<void>('checkout');
      await tester.pump();
      expect(router.backHasTarget, isTrue);

      router.openBackTarget();
      expect(router.openSessionIds, ['main']);
      expect(router.backHasTarget, isFalse);
    });

    testWidgets('FoldableSessionBackButton shows only with stacked sessions', (
      tester,
    ) async {
      final router = stacked();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FoldableRouterScope(
            router: router,
            child: Scaffold(
              appBar: AppBar(leading: const FoldableSessionBackButton()),
            ),
          ),
        ),
      );
      expect(find.byType(BackButton), findsNothing);

      router.openSession<void>('checkout');
      await tester.pump();
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(router.openSessionIds, ['main']);
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('refresh drops the sessions opened over the base one', (
      tester,
    ) async {
      current = 'main';
      final router = FoldableSessionRouter(
        config: _config,
        sessions: [
          _session('guest', '/signIn'),
          _session('main', '/home'),
          _session('extra', '/extra'),
        ],
      );
      addTearDown(router.dispose);
      await pumpApp(tester, router);

      final result = router.openSession<void>('extra');
      current = 'guest';
      router.resetSession(current);
      await result;

      expect(router.openSessionIds, ['guest']);
    });
  });
}

class _Recorder extends FoldableRouterObserver {
  _Recorder(this.events);

  final List<FoldableNavigationEvent> events;

  @override
  void onNavigation(FoldableNavigationEvent event) => events.add(event);
}
