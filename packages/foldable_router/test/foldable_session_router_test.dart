import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _R extends FoldableRoute {
  const _R(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) => Text('screen $path');
}

FoldableRoute? _match(Uri uri) => _R(uri.path);

FoldableSession _session(
  String id,
  String root, {
  bool disposeOnLeave = false,
  bool deepLinkable = false,
  FoldableRoute? Function(Uri uri)? matcher,
  Widget Function(Widget body)? frame,
}) {
  return FoldableSession(
    id: id,
    disposeOnLeave: disposeOnLeave,
    deepLinkable: deepLinkable,
    config: FoldableRouterConfig(
      roots: [_R(root)],
      matcher: matcher ?? _match,
      notFound: (uri) => _R(uri.path),
    ),
    shell: (context, controller, navigator) =>
        navigator((context, body, secondary) {
          final child = body;
          return frame == null ? child : frame(child);
        }),
  );
}

void main() {
  var current = 'guest';

  FoldableSessionRouter build({bool disposeMain = false}) {
    return FoldableSessionRouter(
      sessions: [
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
      ],
      sessionOf: () => current,
    );
  }

  Future<void> pumpApp(WidgetTester tester, FoldableSessionRouter router) {
    return tester.pumpWidget(
      MaterialApp(home: Builder(builder: router.buildShell)),
    );
  }

  setUp(() => current = 'guest');

  testWidgets('shows the shell of the session sessionOf names', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    await pumpApp(tester, router);

    expect(find.text('screen /signIn'), findsOneWidget);
    expect(find.text('scaffold'), findsNothing);

    current = 'onboarding';
    router.refresh();
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: router.buildShell)),
    );

    expect(find.text('bare'), findsOneWidget);
    expect(find.text('scaffold'), findsNothing);
    expect(find.text('screen /welcome'), findsOneWidget);

    current = 'main';
    router.refresh();
    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: router.buildShell)),
    );

    expect(find.text('scaffold'), findsOneWidget);
    expect(find.text('screen /home'), findsOneWidget);
  });

  testWidgets('refresh notifies only when the session changes', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    var notified = 0;
    router.addListener(() => notified++);

    router.refresh();
    expect(notified, 0);

    current = 'main';
    router.refresh();
    expect(notified, 1);
    expect(router.activeSessionId, 'main');
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
    router.push<void>(const _R('/detail'));

    current = 'guest';
    router.refresh();
    current = 'main';
    router.refresh();

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
    router.refresh();
    await pumpApp(tester, router);
    await tester.pump();

    current = 'main';
    router.refresh();
    expect(router.active.pages.length, 1);
  });

  testWidgets('observers reach sessions created later', (tester) async {
    final router = build();
    addTearDown(router.dispose);
    final events = <FoldableNavigationEvent>[];
    router.addObserver(_Recorder(events));

    current = 'main';
    router.refresh();
    router.push<void>(const _R('/detail'));

    expect(events, hasLength(1));
  });

  testWidgets(
    'replaceSession shows a route and survives an unchanged refresh',
    (tester) async {
      final router = build();
      addTearDown(router.dispose);
      await pumpApp(tester, router);
      router.rootContextOf = () => tester.element(find.byType(Builder).first);

      router.replaceSession('main', route: const _R('/detail'));
      expect(router.activeSessionId, 'main');
      expect(router.currentUri.path, '/detail');

      router.refresh();
      expect(router.activeSessionId, 'main');

      current = 'onboarding';
      router.refresh();
      expect(router.activeSessionId, 'onboarding');
    },
  );

  testWidgets('a URL switches to the deep linkable session that knows it', (
    tester,
  ) async {
    final router = FoldableSessionRouter(
      sessions: [
        _session(
          'guest',
          '/signIn',
          matcher: (uri) => uri.path == '/signIn' ? const _R('/signIn') : null,
        ),
        _session(
          'onboarding',
          '/welcome',
          deepLinkable: true,
          matcher: (uri) =>
              uri.path == '/welcome' ? const _R('/welcome') : null,
        ),
        _session(
          'main',
          '/home',
          matcher: (uri) => uri.path == '/home' ? const _R('/home') : null,
        ),
      ],
      sessionOf: () => 'guest',
    );
    addTearDown(router.dispose);

    router.goUri(Uri.parse('/home'));
    expect(router.activeSessionId, 'guest');

    router.goUri(Uri.parse('/welcome'));
    expect(router.activeSessionId, 'onboarding');
  });

  testWidgets('a session can use the stack navigator', (tester) async {
    current = 'main';
    final router = FoldableSessionRouter(
      sessions: [
        FoldableSession(
          id: 'main',
          navigator: FoldableNavigatorKind.stack,
          config: FoldableRouterConfig(
            roots: const [_R('/home')],
            matcher: _match,
            notFound: (uri) => _R(uri.path),
          ),
        ),
      ],
      sessionOf: () => 'main',
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

  testWidgets('a stack session can start without roots', (tester) async {
    current = 'main';
    final router = FoldableSessionRouter(
      sessions: [
        FoldableSession(
          id: 'main',
          navigator: FoldableNavigatorKind.stack,
          config: FoldableRouterConfig(
            roots: const [],
            matcher: _match,
            notFound: (uri) => _R(uri.path),
          ),
        ),
      ],
      sessionOf: () => 'main',
    );
    addTearDown(router.dispose);
    await pumpApp(tester, router);

    expect(find.textContaining('screen'), findsNothing);

    router.push<void>(const _R('/welcome'));
    await tester.pumpAndSettle();

    expect(find.text('screen /welcome'), findsOneWidget);
  });

  testWidgets('a stack session fills from a URL', (tester) async {
    current = 'main';
    final router = FoldableSessionRouter(
      sessions: [
        FoldableSession(
          id: 'main',
          navigator: FoldableNavigatorKind.stack,
          config: FoldableRouterConfig(
            roots: const [],
            matcher: _match,
            notFound: (uri) => _R(uri.path),
          ),
        ),
      ],
      sessionOf: () => 'main',
    );
    addTearDown(router.dispose);
    await pumpApp(tester, router);
    router.rootContextOf = () =>
        tester.element(find.byType(FoldableStackNavigator));

    // The empty stack's URL is `/`, but the first navigation still runs.
    router.goUri(Uri.parse('/'));
    await tester.pumpAndSettle();

    expect(find.text('screen /'), findsOneWidget);
  });

  test('unknown session id throws', () {
    current = 'nope';
    expect(build, throwsStateError);
  });
}

class _Recorder extends FoldableRouterObserver {
  _Recorder(this.events);

  final List<FoldableNavigationEvent> events;

  @override
  void onNavigation(FoldableNavigationEvent event) => events.add(event);
}
