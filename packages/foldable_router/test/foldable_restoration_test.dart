import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A route with a URL that the matcher knows.
class _R extends FoldableRoute {
  const _R(this.path, {this.onRedirect});

  @override
  final String path;

  final void Function()? onRedirect;

  @override
  Widget build(BuildContext context) => Text('screen $location');

  @override
  Future<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) async {
    onRedirect?.call();
    return null;
  }
}

/// The root of a branch.
class _B extends BranchRoute {
  const _B(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) => Text('screen $location');
}

/// A route that cannot be written into a URL.
class _Hidden extends FoldableRoute {
  const _Hidden();

  @override
  String get path => '/hidden';

  @override
  bool get deepLinkable => false;

  @override
  Widget build(BuildContext context) => const Text('hidden');
}

/// Everything one run of the app created, so a test can look at the instances
/// that exist after `restartAndRestore`.
class _Runs {
  final routers = <FoldableRouter>[];
  final sessionRouters = <FoldableSessionRouter>[];
  final events = <FoldableNavigationEvent>[];
  var redirects = 0;

  /// Paths the matcher answers for, besides the roots.
  final known = <String>{
    '/a',
    '/b',
    '/a/1',
    '/a/2',
    '/b/1',
    '/b/2',
    '/c',
    '/c/1',
    '/g',
  };

  FoldableRouter get router => routers.last;
  FoldableSessionRouter get sessionRouter => sessionRouters.last;

  List<BranchRoute> branchesOf(List<String> roots) => [
    for (final root in roots) _B(root),
  ];

  List<FoldableRoute> rootsOf(List<String> roots) => [
    for (final root in roots) _R(root, onRedirect: () => redirects++),
  ];

  FoldableRouterConfig config(List<String> roots, {bool matchAll = false}) {
    return FoldableRouterConfig(
      matcher: (uri) => matchAll
          ? _R(roots.first)
          : known.contains(uri.path)
          ? _R(uri.path, onRedirect: () => redirects++)
          : (uri.path == '/' ? _R(roots.first) : null),
      notFound: (uri) => _R('/not-found'),
      redirect: (context, state) {
        redirects++;
        return null;
      },
      observers: [_Log(events)],
    );
  }
}

class _Log extends FoldableRouterObserver {
  const _Log(this.events);

  final List<FoldableNavigationEvent> events;

  @override
  void onNavigation(FoldableNavigationEvent event) => events.add(event);
}

/// Builds the router and the delegate in its own state, so that
/// `restartAndRestore` (which unmounts and mounts the app) gets new ones, like
/// a process that starts again.
class _App extends StatefulWidget {
  const _App({required this.runs, this.restorationId, this.sessions = false});

  final _Runs runs;
  final String? restorationId;
  final bool sessions;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  late final ChangeNotifier _router;
  late final FoldableRouterDelegate _delegate;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final runs = widget.runs;
    Widget screen(FoldableNavigatorController controller) {
      return FoldableNavigator(
        controller: controller,
        builder: (context, body, secondary) => secondary ?? body,
      );
    }

    if (widget.sessions) {
      final router = FoldableSessionRouter(
        config: runs.config(['/a', '/b']),
        sessions: [
          // The one `_session` names comes first, so it is the base.
          FoldableSessionSplit(
            id: 'guest',
            branches: runs.branchesOf(['/g']),
            deepLinkable: true,
            canActivate: (_) => _session == 'guest',
          ),
          FoldableSessionSplit(
            id: 'main',
            branches: runs.branchesOf(['/a', '/b']),
            shell: (context, controller, navigator) =>
                navigator((context, body, secondary) => secondary ?? body),
          ),
        ],
      )..refresh();
      runs.sessionRouters.add(router);
      _router = router;
      _delegate = FoldableRouterDelegate(
        router: router,
        navigatorKey: _navigatorKey,
        builder: router.buildShell,
        restorationId: widget.restorationId,
      );
    } else {
      final router = FoldableRouter(
        roots: runs.rootsOf(['/a', '/b', '/c']),
        config: runs.config(['/a', '/b', '/c']),
      );
      runs.routers.add(router);
      _router = router;
      _delegate = FoldableRouterDelegate(
        router: router,
        navigatorKey: _navigatorKey,
        builder: (context) => screen(router.controller),
        restorationId: widget.restorationId,
      );
    }
  }

  @override
  void dispose() {
    _delegate.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: 'app',
      routerDelegate: _delegate,
      routeInformationParser: const FoldableRouteInformationParser(),
    );
  }
}

/// The initial session of the session tests.
String _session = 'main';

List<String?> _names(FoldableRouter router, int branch) => [
  for (final page in router.controller.pagesOf(branch)) page.name,
];

Future<_Runs> _start(
  WidgetTester tester, {
  String? restorationId = 'foldable_router',
  bool sessions = false,
}) async {
  final runs = _Runs();
  await tester.pumpWidget(
    _App(runs: runs, restorationId: restorationId, sessions: sessions),
  );
  await tester.pumpAndSettle();
  return runs;
}

/// Builds a stack across branches: /a -> a/1 -> a/2 and /b -> b/1, with the
/// second branch on screen.
///
/// A push waits for the redirects of its route, which the test routes answer
/// asynchronously, so each one is pumped before the next navigation.
Future<void> _navigate(WidgetTester tester, FoldableRouter router) async {
  router.push<void>(const _R('/a/1'));
  await tester.pump();
  router.push<void>(const _R('/a/2'));
  await tester.pump();
  router.controller.goBranch(1);
  router.push<void>(const _R('/b/1'));
  await tester.pump();
}

void main() {
  setUp(() => _session = 'main');

  testWidgets('restores every branch and the current branch', (tester) async {
    final runs = await _start(tester);
    await _navigate(tester, runs.router);
    await tester.pumpAndSettle();
    expect(find.text('screen /b/1'), findsOneWidget);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    final router = runs.router;
    expect(runs.routers, hasLength(2), reason: 'a new router after restart');
    expect(router.currentIndex, 1);
    expect(_names(router, 0), ['/a', '/a/1', '/a/2']);
    expect(_names(router, 1), ['/b', '/b/1']);
    expect(_names(router, 2), ['/c']);
    expect(find.text('screen /b/1'), findsOneWidget);
    expect(router.currentUri.toString(), '/b/1');
  });

  testWidgets('keeps the pages the router created for the roots', (
    tester,
  ) async {
    final runs = await _start(tester);
    final before = runs.router;
    before.push<void>(const _R('/a/1'));
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    final router = runs.router;
    expect(router, isNot(same(before)));
    // The root is not rebuilt from its URL: it is the page of the new router.
    expect(router.controller.pagesOf(0).first, isA<FoldablePage<void>>());
    expect(router.controller.pagesOf(0), hasLength(2));
    expect(router.controller.pagesOf(0).first.name, '/a');
  });

  testWidgets('restored pages can be popped as usual', (tester) async {
    final runs = await _start(tester);
    runs.router.push<void>(const _R('/a/1'));
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();
    expect(find.text('screen /a/1'), findsOneWidget);

    runs.router.back();
    await tester.pumpAndSettle();
    expect(_names(runs.router, 0), ['/a']);
    expect(find.text('screen /a'), findsOneWidget);
  });

  testWidgets('drops pages whose route is not deepLinkable', (tester) async {
    final runs = await _start(tester);
    runs.router
      ..push<void>(const _R('/a/1'))
      ..push<void>(const _Hidden())
      ..push<void>(const _R('/a/2'));
    await tester.pumpAndSettle();
    expect(_names(runs.router, 0), ['/a', '/a/1', null, '/a/2']);

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_names(runs.router, 0), ['/a', '/a/1', '/a/2']);
    expect(find.text('hidden'), findsNothing);
  });

  testWidgets('drops routes the matcher does not know any more', (
    tester,
  ) async {
    final runs = await _start(tester);
    runs.router
      ..push<void>(const _R('/a/1'))
      ..push<void>(const _R('/old'))
      ..push<void>(const _R('/a/2'));
    await tester.pumpAndSettle();
    expect(runs.router.currentUri.toString(), '/a/2');

    // The matcher does not know /old: restoring drops it, it does not fall
    // back to the notFound route.
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_names(runs.router, 0), ['/a', '/a/1', '/a/2']);
    expect(find.text('screen /not-found'), findsNothing);
    expect(find.text('screen /a/2'), findsOneWidget);
  });

  testWidgets('ignores a snapshot of another number of branches', (
    tester,
  ) async {
    final runs = await _start(tester);
    await _navigate(tester, runs.router);
    await tester.pumpAndSettle();

    // Another version of the app: two tabs instead of three.
    final saved = runs.router.saveState();
    final other = FoldableRouter(
      roots: runs.rootsOf(['/a', '/b']),
      config: runs.config(['/a', '/b']),
    );
    addTearDown(other.dispose);
    other.restoreState(saved);
    expect(_names(other, 0), ['/a']);
    expect(_names(other, 1), ['/b']);
    expect(other.currentIndex, 0);

    // A snapshot with one branch against a router with three.
    final bad = <String, Object?>{
      'index': 1,
      'branches': [
        ['/a/1'],
      ],
    };
    runs.router.restoreState(bad);
    expect(_names(runs.router, 0), ['/a', '/a/1', '/a/2']);
  });

  testWidgets('ignores a snapshot that is out of range or malformed', (
    tester,
  ) async {
    final runs = await _start(tester);
    final router = runs.router;
    final events = runs.events.length;

    final snapshots = <Map<String, Object?>>[
      {
        'index': 3,
        'branches': [
          <String>['/a/1'],
          <String>[],
          <String>[],
        ],
      },
      {
        'index': -1,
        'branches': [<String>[], <String>[], <String>[]],
      },
      {'index': 0},
      {'index': 'zero', 'branches': <Object?>[]},
      {
        'index': 0,
        'branches': [
          <Object?>['/a/1', 7],
          <String>[],
          <String>[],
        ],
      },
      {
        'index': 0,
        'branches': ['not a list', <String>[], <String>[]],
      },
    ];
    for (final snapshot in snapshots) {
      router.restoreState(snapshot);
    }

    for (var branch = 0; branch < 3; branch++) {
      expect(router.controller.pagesOf(branch), hasLength(1));
    }
    expect(router.currentIndex, 0);
    expect(runs.events, hasLength(events));
  });

  testWidgets('restoration is off without a restorationId', (tester) async {
    final runs = await _start(tester, restorationId: null);
    await _navigate(tester, runs.router);
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    // Only the URL on top comes back (from MaterialApp.router itself), as a
    // single page of the first branch: the stacks start again.
    final router = runs.router;
    expect(router.currentIndex, 0);
    expect(_names(router, 0), ['/a', '/b/1']);
    expect(_names(router, 1), ['/b']);
    expect(_names(router, 2), ['/c']);
  });

  testWidgets('a delegate without restorationId builds no restoration host', (
    tester,
  ) async {
    await _start(tester, restorationId: null);
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_RestorationHost',
      ),
      findsNothing,
    );
  });

  testWidgets('restoring tells no observer and runs no redirect', (
    tester,
  ) async {
    final runs = await _start(tester);
    await _navigate(tester, runs.router);
    await tester.pumpAndSettle();
    expect(runs.events, isNotEmpty);
    expect(runs.redirects, greaterThan(0));
    runs.events.clear();
    runs.redirects = 0;

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_names(runs.router, 0), ['/a', '/a/1', '/a/2']);
    expect(runs.router.currentIndex, 1);
    expect(runs.events, isEmpty);
    expect(runs.redirects, 0);
  });

  testWidgets('the startup route does not wipe the restored stacks', (
    tester,
  ) async {
    final runs = await _start(tester);
    runs.router
      ..push<void>(const _R('/a/1'))
      ..push<void>(const _R('/a/2'));
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    // Frames in which a navigation that waited for a context would have run.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(_names(runs.router, 0), ['/a', '/a/1', '/a/2']);
    expect(runs.router.currentUri.toString(), '/a/2');
    expect(find.text('screen /a/2'), findsOneWidget);
  });

  testWidgets('after the restore links navigate as usual', (tester) async {
    final runs = await _start(tester);
    runs.router.push<void>(const _R('/a/1'));
    await tester.pumpAndSettle();
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    // After the restore a link is a normal navigation.
    runs.router.goUri(Uri.parse('/b/1'));
    await tester.pumpAndSettle();
    expect(runs.router.currentUri.toString(), '/b/1');
  });

  testWidgets('the snapshot follows the stacks while the app runs', (
    tester,
  ) async {
    final runs = await _start(tester);
    runs.router.push<void>(const _R('/a/1'));
    await tester.pumpAndSettle();
    runs.router.push<void>(const _R('/a/2'));
    await tester.pump();
    runs.router.pop();
    await tester.pumpAndSettle();

    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(_names(runs.router, 0), ['/a', '/a/1']);
  });

  group('FoldableRouter state', () {
    testWidgets('saveState holds plain codec friendly values', (tester) async {
      final runs = await _start(tester);
      await _navigate(tester, runs.router);
      await tester.pumpAndSettle();

      expect(runs.router.saveState(), {
        'index': 1,
        'branches': [
          ['/a/1', '/a/2'],
          ['/b/1'],
          <String>[],
        ],
      });
    });

    testWidgets('restoreState announces nothing and runs no redirect', (
      tester,
    ) async {
      final runs = await _start(tester);
      runs.events.clear();
      runs.redirects = 0;

      runs.router.restoreState({
        'index': 2,
        'branches': [
          ['/a/1'],
          <String>[],
          ['/c/1'],
        ],
      });

      expect(runs.router.currentIndex, 2);
      expect(_names(runs.router, 2), ['/c', '/c/1']);
      expect(runs.events, isEmpty);
      expect(runs.redirects, 0);

      // The next change is reported against the restored stacks.
      runs.router.pop();
      expect(runs.events, hasLength(1));
      expect(runs.events.single.kind, FoldableNavigationKind.pop);
    });
  });

  group('FoldableSessionRouter', () {
    testWidgets('restores the active session and its stacks', (tester) async {
      final runs = await _start(tester, sessions: true);
      final router = runs.sessionRouter;
      router.push<void>(const _R('/a/1'));
      router.controller.goBranch(1);
      router.push<void>(const _R('/b/1'));
      router.push<void>(const _R('/b/2'));
      await tester.pumpAndSettle();

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      final restored = runs.sessionRouter;
      expect(runs.sessionRouters, hasLength(2));
      expect(restored.activeSessionId, 'main');
      expect(restored.active.currentIndex, 1);
      expect(_names(restored.active, 0), ['/a', '/a/1']);
      expect(_names(restored.active, 1), ['/b', '/b/1', '/b/2']);
      expect(restored.currentUri.toString(), '/b/2');
      expect(find.text('screen /b/2'), findsOneWidget);
    });

    testWidgets('saves the active session only', (tester) async {
      final runs = await _start(tester, sessions: true);
      runs.sessionRouter.push<void>(const _R('/a/1'));
      await tester.pump();

      final state = runs.sessionRouter.saveState();

      expect(state['session'], 'main');
      expect((state['router'] as Map<String, Object?>)['branches'], [
        ['/a/1'],
        <String>[],
      ]);
      expect(state.keys, unorderedEquals(['session', 'router']));
    });

    testWidgets('the saved session wins over the initial one', (tester) async {
      final runs = await _start(tester, sessions: true);
      runs.sessionRouter.push<void>(const _R('/a/1'));
      await tester.pumpAndSettle();

      // The app starts on another session when it comes back.
      _session = 'guest';
      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      final restored = runs.sessionRouter;
      expect(restored.activeSessionId, 'main');
      expect(restored.openSessionIds, ['main']);
      expect(restored.active.pages, hasLength(2));
    });
  });

  testWidgets('a router without state to save is left alone', (tester) async {
    final router = _PlainRouter();
    addTearDown(router.dispose);
    final key = GlobalKey<NavigatorState>();
    final delegate = FoldableRouterDelegate(
      router: router,
      navigatorKey: key,
      builder: (context) => const Text('plain'),
      restorationId: 'foldable_router',
    );
    addTearDown(delegate.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        restorationScopeId: 'app',
        routerDelegate: delegate,
        routeInformationParser: const FoldableRouteInformationParser(),
      ),
    );
    await tester.restartAndRestore();
    await tester.pumpAndSettle();

    expect(find.text('plain'), findsOneWidget);
    expect(router.restored, isEmpty);
  });
}

/// A third party router: it implements only the required members.
class _PlainRouter extends ChangeNotifier with FoldableRouterBase {
  final restored = <Map<String, Object?>>[];

  @override
  Uri get currentUri => Uri.parse('/');

  @override
  void goUri(Uri uri) {}

  @override
  bool get backGoesToRoot => false;

  @override
  void goBackToRoot() {}

  @override
  void restoreState(Map<String, Object?> state) => restored.add(state);
}
