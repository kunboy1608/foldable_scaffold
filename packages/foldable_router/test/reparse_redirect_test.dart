import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

int sizedRedirects = 0;
int slowRedirects = 0;
bool slowMode = false;
Completer<void>? slowGate;
int paneRedirects = 0;
int pendingHomeRedirects = 0;
int pendingHomeSawSlow = 0;
FoldableRouter? pendingRouter;
Completer<void>? pendingGate;
Completer<void>? tabGate;
int pendingTabBRedirects = 0;
Completer<void>? authGate;
int slowGuardedRedirects = 0;
bool throwOnSilentRecheck = false;

/// A stateful page, used to check that a dependency change does not rebuild
/// (and so never recreates) the State of a page.
class Counter extends StatefulWidget {
  const Counter(this.label, {super.key});

  final String label;

  @override
  State<Counter> createState() => CounterState();
}

class CounterState extends State<Counter> {
  int value = 0;

  @override
  Widget build(BuildContext context) => Text('${widget.label} $value');
}

class HomeRoute extends FoldableRoute {
  const HomeRoute();

  @override
  String get path => '/';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class OtherRoute extends FoldableRoute {
  const OtherRoute();

  @override
  String get path => '/other';

  @override
  Widget build(BuildContext context) => const Text('other');
}

class LoginRoute extends FoldableRoute {
  const LoginRoute();

  @override
  String get path => '/login';

  @override
  Widget build(BuildContext context) => const Text('login');
}

/// Registers a dependency on MediaQuery from its redirect.
class SizedRoute extends FoldableRoute {
  const SizedRoute();

  @override
  String get path => '/sized';

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    sizedRedirects++;
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('sized');
}

/// Registers a dependency on MediaQuery, and awaits [slowGate] while
/// [slowMode] is on.
class SlowOnResizeRoute extends FoldableRoute {
  const SlowOnResizeRoute();

  @override
  String get path => '/slow';

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    slowRedirects++;
    MediaQuery.sizeOf(context);
    if (slowMode) await slowGate!.future;
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('slow');
}

/// An InheritedWidget above MaterialApp.router holding the login state.
class Auth extends InheritedWidget {
  const Auth({super.key, required this.signedIn, required super.child});

  final bool signedIn;

  static Auth of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Auth>()!;

  @override
  bool updateShouldNotify(Auth oldWidget) => signedIn != oldWidget.signedIn;
}

class GuardedRoute extends FoldableRoute {
  const GuardedRoute();

  @override
  String get path => '/guarded';

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) =>
      Auth.of(context).signedIn ? null : const LoginRoute();

  @override
  Widget build(BuildContext context) => const Text('guarded');
}

class StackShell extends FoldableShellRoute {
  const StackShell();

  @override
  List<FoldableRoute> get branches => const [BranchA(), BranchB()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < branches.length; i++)
            TextButton(
              key: Key('tab-$i'),
              onPressed: () => shell.goBranch(i),
              child: Text('tab $i'),
            ),
        ],
      ),
    ),
  );
}

class BranchA extends FoldableRoute {
  const BranchA();

  @override
  String get path => '/a';

  @override
  FoldableRoute? get parent => const StackShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      const Counter('a', key: Key('a-root'));
}

class AChild extends FoldableRoute {
  const AChild();

  @override
  String get path => '/a/child';

  @override
  FoldableRoute? get parent => const BranchA();

  @override
  Widget build(BuildContext context) =>
      const Counter('a child', key: Key('a-child'));
}

class BranchB extends FoldableRoute {
  const BranchB();

  @override
  String get path => '/b';

  @override
  FoldableRoute? get parent => const StackShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      const Counter('b', key: Key('b-root'));
}

class BChild extends FoldableRoute {
  const BChild();

  @override
  String get path => '/b/child';

  @override
  FoldableRoute? get parent => const BranchB();

  @override
  Widget build(BuildContext context) =>
      const Counter('b child', key: Key('b-child'));
}

class OverlayRoute extends FoldableRoute {
  const OverlayRoute();

  @override
  String get path => '/overlay';

  @override
  Widget build(BuildContext context) =>
      const Counter('overlay', key: Key('overlay'));
}

/// A shell showing two panes above 600 logical pixels.
class PaneShell extends FoldableShellRoute {
  const PaneShell();

  @override
  List<FoldableRoute> get branches => const [PaneRoot()];

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (panes.constraints.maxWidth < 600) return null;
    return Row(
      children: [
        Expanded(child: panes.primary),
        if (panes.hasSecondary) Expanded(child: panes.secondary),
      ],
    );
  }

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Scaffold(body: shell.child);
}

class PaneRoot extends FoldableRoute {
  const PaneRoot();

  @override
  String get path => '/pane';

  @override
  FoldableRoute? get parent => const PaneShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    paneRedirects++;
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      const Counter('pane root', key: Key('pane-root'));
}

class PaneDetail extends FoldableRoute {
  const PaneDetail();

  @override
  String get path => '/pane/detail';

  @override
  FoldableRoute? get parent => const PaneRoot();

  @override
  Widget build(BuildContext context) =>
      const Counter('pane detail', key: Key('pane-detail'));
}

/// Counts its redirect runs and how many of them saw [PendingSlowRoute] on the
/// stack, which tells a re-check run after the navigation committed from the
/// runs the navigation itself did before committing.
class PendingHomeRoute extends FoldableRoute {
  const PendingHomeRoute();

  @override
  String get path => '/';

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    pendingHomeRedirects++;
    if (pendingRouter?.stack.contains(const PendingSlowRoute()) ?? false) {
      pendingHomeSawSlow++;
    }
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('pending home');
}

class PendingSlowRoute extends FoldableRoute {
  const PendingSlowRoute();

  @override
  String get path => '/pending-slow';

  @override
  FoldableRoute? get parent => const PendingHomeRoute();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    final gate = pendingGate;
    if (gate != null) await gate.future;
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('pending slow');
}

class ThrowingSlowRoute extends FoldableRoute {
  const ThrowingSlowRoute();

  @override
  String get path => '/throwing-slow';

  @override
  FoldableRoute? get parent => const PendingHomeRoute();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    final gate = pendingGate;
    if (gate != null) await gate.future;
    throw StateError('slow redirect failed');
  }

  @override
  Widget build(BuildContext context) => const Text('throwing slow');
}

class SlowGuardedRoute extends FoldableRoute {
  const SlowGuardedRoute();

  @override
  String get path => '/slow-guarded';

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    slowGuardedRedirects++;
    // Captured before the await: the navigation must finish with the value it
    // saw when it started.
    final signedIn = Auth.of(context).signedIn;
    final gate = authGate;
    if (gate != null) await gate.future;
    return signedIn ? null : const LoginRoute();
  }

  @override
  Widget build(BuildContext context) => const Text('slow guarded');
}

class SometimesThrowingRoute extends FoldableRoute {
  const SometimesThrowingRoute();

  @override
  String get path => '/sometimes-throwing';

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    if (throwOnSilentRecheck) throw StateError('silent re-check failed');
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('sometimes throwing');
}

class PendingTabShell extends FoldableShellRoute {
  const PendingTabShell();

  @override
  List<FoldableRoute> get branches => const [PendingTabA(), PendingTabB()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < branches.length; i++)
            TextButton(
              key: Key('pending-tab-$i'),
              onPressed: () => shell.goBranch(i),
              child: Text('pending tab $i'),
            ),
        ],
      ),
    ),
  );
}

class PendingTabA extends FoldableRoute {
  const PendingTabA();

  @override
  String get path => '/pending-tab-a';

  @override
  FoldableRoute? get parent => const PendingTabShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    MediaQuery.sizeOf(context);
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('pending tab a');
}

class PendingTabB extends FoldableRoute {
  const PendingTabB();

  @override
  String get path => '/pending-tab-b';

  @override
  FoldableRoute? get parent => const PendingTabShell();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    pendingTabBRedirects++;
    final gate = tabGate;
    if (gate != null) await gate.future;
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('pending tab b');
}

FoldableRouter makeRouter({
  FoldableRoute initial = const HomeRoute(),
  Map<String, FoldableRouteFactory> routes = const {},
}) {
  final router = FoldableRouter(
    initial: initial,
    routes: routes,
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<void> pumpApp(WidgetTester tester, FoldableRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
}

void setSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
}

/// Sends [url] the way the platform (a browser reload, a deep link) does.
Future<void> platformPushesUrl(WidgetTester tester, String url) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', <String, Object?>{
        'location': url,
        'state': null,
      }),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sizedRedirects = 0;
    slowRedirects = 0;
    slowMode = false;
    slowGate = null;
    paneRedirects = 0;
    pendingHomeRedirects = 0;
    pendingHomeSawSlow = 0;
    pendingRouter = null;
    pendingGate = null;
    tabGate = null;
    pendingTabBRedirects = 0;
    authGate = null;
    slowGuardedRedirects = 0;
    throwOnSilentRecheck = false;
  });

  testWidgets('a dependency change re-runs the redirects without reopening', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter();
    await pumpApp(tester, router);

    await router.open(const OtherRoute());
    await tester.pumpAndSettle();
    var done = false;
    final pushed = router.push<void>(const SizedRoute());
    unawaited(pushed.then((_) => done = true));
    await tester.pumpAndSettle();
    expect(router.stack, [const OtherRoute(), const SizedRoute()]);

    final redirectsBefore = sizedRedirects;
    var notifications = 0;
    router.addListener(() => notifications++);

    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();

    // The stack is untouched, the push future is still pending, the router
    // did not notify, and the redirect did run again.
    expect(router.stack, [const OtherRoute(), const SizedRoute()]);
    expect(done, isFalse);
    expect(notifications, 0);
    expect(sizedRedirects, greaterThan(redirectsBefore));

    router.pop();
    await pushed;
    await tester.pumpAndSettle();
  });

  testWidgets('a platform URL equal to the current one refreshes, not reopen', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter();
    await pumpApp(tester, router);

    await router.open(const OtherRoute());
    await tester.pumpAndSettle();
    var done = false;
    final pushed = router.push<void>(const SizedRoute());
    unawaited(pushed.then((_) => done = true));
    await tester.pumpAndSettle();

    var notifications = 0;
    router.addListener(() => notifications++);
    final redirectsBefore = sizedRedirects;

    // This is what a web reload asks for: the location already shown.
    await platformPushesUrl(tester, '/sized');

    expect(router.stack, [const OtherRoute(), const SizedRoute()]);
    expect(done, isFalse);
    expect(notifications, 0);
    expect(sizedRedirects, greaterThan(redirectsBefore));

    router.pop();
    await pushed;
    await tester.pumpAndSettle();
  });

  testWidgets('in a shell every branch stack and page State survive', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const StackShell());
    await pumpApp(tester, router);

    await router.open(const AChild());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    await router.open(const BChild());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-0')));
    await tester.pumpAndSettle();
    final pushed = router.push<void>(const OverlayRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [
      const StackShell(),
      const BranchA(),
      const AChild(),
      const OverlayRoute(),
    ]);

    CounterState state(String key) => tester.state<CounterState>(
      find.byKey(Key(key), skipOffstage: false),
    );
    final a = state('a-child');
    final bRoot = state('b-root');
    final b = state('b-child');
    final overlay = state('overlay');

    tester.view.physicalSize = const Size(1000, 700);
    await tester.pumpAndSettle();

    expect(router.stack, [
      const StackShell(),
      const BranchA(),
      const AChild(),
      const OverlayRoute(),
    ]);
    expect(identical(state('a-child'), a), isTrue);
    expect(identical(state('b-root'), bRoot), isTrue);
    expect(identical(state('b-child'), b), isTrue);
    expect(identical(state('overlay'), overlay), isTrue);

    router.pop();
    await pushed;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-1')));
    await tester.pumpAndSettle();
    expect(router.stack, [
      const StackShell(),
      const BranchB(),
      const BChild(),
    ]);
    expect(identical(state('b-root'), bRoot), isTrue);
    expect(identical(state('b-child'), b), isTrue);
  });

  testWidgets('a dependency that now refuses the route navigates to Login', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(
      routes: {'/guarded': (params) => const GuardedRoute()},
    );
    Widget app(bool signedIn) => Auth(
      signedIn: signedIn,
      child: MaterialApp.router(routerConfig: router.routerConfig),
    );

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    await router.open(const GuardedRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const GuardedRoute()]);

    // No refresh(): the Router re-parses because the redirect depends on Auth.
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('re-parsing the same location on the not-found page does nothing', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/nope';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final router = makeRouter();
    await pumpApp(tester, router);

    expect(find.text('not found: /nope'), findsOneWidget);
    expect(router.stack, isEmpty);
    expect(router.location, Uri.parse('/nope'));

    var notifications = 0;
    router.addListener(() => notifications++);

    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();

    expect(find.text('not found: /nope'), findsOneWidget);
    expect(router.stack, isEmpty);
    expect(router.location, Uri.parse('/nope'));
    expect(notifications, 0);
  });

  testWidgets('repeated dependency changes supersede each other cleanly', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter();
    await pumpApp(tester, router);

    await router.open(const SlowOnResizeRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const SlowOnResizeRoute()]);

    final redirectsBefore = slowRedirects;
    var notifications = 0;
    router.addListener(() => notifications++);
    slowMode = true;
    slowGate = Completer<void>();

    for (var i = 0; i < 3; i++) {
      tester.view.physicalSize = Size(810 + i * 10.0, 600);
      await tester.pump();
    }
    expect(slowRedirects, greaterThanOrEqualTo(redirectsBefore + 3));

    slowGate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(router.stack, [const SlowOnResizeRoute()]);
    expect(notifications, 0);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('crossing the two-pane threshold keeps the stack and State', (
    tester,
  ) async {
    setSize(tester, const Size(500, 700));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PaneShell());
    await pumpApp(tester, router);

    await router.open(const PaneDetail());
    await tester.pumpAndSettle();
    // One pane: only the detail is on screen.
    expect(find.byKey(const Key('pane-root')), findsNothing);
    expect(find.byKey(const Key('pane-detail')), findsOneWidget);

    CounterState state(String key) => tester.state<CounterState>(
      find.byKey(Key(key), skipOffstage: false),
    );
    final root = state('pane-root');
    final detail = state('pane-detail');
    final redirectsBefore = paneRedirects;

    // Two panes.
    tester.view.physicalSize = const Size(900, 700);
    await tester.pumpAndSettle();

    expect(router.stack, [
      const PaneShell(),
      const PaneRoot(),
      const PaneDetail(),
    ]);
    expect(paneRedirects, greaterThan(redirectsBefore));
    expect(find.byKey(const Key('pane-root')), findsOneWidget);
    expect(find.byKey(const Key('pane-detail')), findsOneWidget);
    expect(identical(state('pane-root'), root), isTrue);
    expect(identical(state('pane-detail'), detail), isTrue);

    // Back to one pane.
    tester.view.physicalSize = const Size(500, 700);
    await tester.pumpAndSettle();

    expect(router.stack, [
      const PaneShell(),
      const PaneRoot(),
      const PaneDetail(),
    ]);
    expect(identical(state('pane-root'), root), isTrue);
    expect(identical(state('pane-detail'), detail), isTrue);
  });

  testWidgets('a dependency change during open does not cancel it', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingHomeRoute());
    pendingRouter = router;
    addTearDown(() => pendingRouter = null);
    await pumpApp(tester, router);

    pendingGate = Completer<void>();
    var done = false;
    final openFuture = router.open(const PendingSlowRoute());
    unawaited(openFuture.then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(done, isFalse);

    final redirectsBefore = pendingHomeRedirects;
    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();
    expect(done, isFalse);

    pendingGate!.complete();
    pendingGate = null;
    await tester.pumpAndSettle();
    await openFuture;

    // The open completed normally, and only afterwards did a single silent
    // re-check run, on the stack it committed.
    expect(router.stack, [const PendingHomeRoute(), const PendingSlowRoute()]);
    expect(done, isTrue);
    expect(pendingHomeRedirects, greaterThan(redirectsBefore));
    expect(pendingHomeSawSlow, 1);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('a dependency change during push does not cancel it', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingHomeRoute());
    pendingRouter = router;
    addTearDown(() => pendingRouter = null);
    await pumpApp(tester, router);

    pendingGate = Completer<void>();
    var done = false;
    final pushFuture = router.push<void>(const PendingSlowRoute());
    unawaited(pushFuture.then((_) => done = true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(done, isFalse);

    final redirectsBefore = pendingHomeRedirects;
    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();
    expect(done, isFalse);

    pendingGate!.complete();
    pendingGate = null;
    await tester.pumpAndSettle();

    // The silent re-check left the pushed page and its pending future alone.
    expect(router.stack, [const PendingHomeRoute(), const PendingSlowRoute()]);
    expect(done, isFalse);
    expect(pendingHomeRedirects, greaterThan(redirectsBefore));
    expect(pendingHomeSawSlow, 1);

    router.pop();
    await pushFuture;
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('a dependency change during an explicit refresh does not cancel it', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingHomeRoute());
    pendingRouter = router;
    addTearDown(() => pendingRouter = null);
    await pumpApp(tester, router);

    await router.open(const PendingSlowRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const PendingHomeRoute(), const PendingSlowRoute()]);

    pendingGate = Completer<void>();
    var done = false;
    final refreshFuture = router.refresh();
    unawaited(refreshFuture.then((_) => done = true));
    await tester.pump();
    expect(router.isNavigating.value, isTrue);
    final sawSlowBefore = pendingHomeSawSlow;

    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();
    expect(done, isFalse);

    pendingGate!.complete();
    pendingGate = null;
    await tester.pumpAndSettle();
    await refreshFuture;

    expect(router.stack, [const PendingHomeRoute(), const PendingSlowRoute()]);
    expect(done, isTrue);
    expect(pendingHomeSawSlow, sawSlowBefore + 1);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('a dependency change during a shell tab switch does not cancel it', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingTabShell());
    await pumpApp(tester, router);
    expect(router.stack, [const PendingTabShell(), const PendingTabA()]);

    pendingTabBRedirects = 0;
    tabGate = Completer<void>();
    await tester.tap(find.byKey(const Key('pending-tab-1')));
    await tester.pump();
    expect(pendingTabBRedirects, 1);

    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();

    tabGate!.complete();
    tabGate = null;
    await tester.pumpAndSettle();

    expect(router.stack, [const PendingTabShell(), const PendingTabB()]);
    expect(pendingTabBRedirects, 2);
    expect(router.isNavigating.value, isFalse);
    expect(find.text('pending tab b'), findsOneWidget);
  });

  testWidgets('several changes during a pending navigation coalesce into one', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingHomeRoute());
    pendingRouter = router;
    addTearDown(() => pendingRouter = null);
    await pumpApp(tester, router);

    pendingGate = Completer<void>();
    var done = false;
    final before = pendingHomeRedirects;
    final openFuture = router.open(const PendingSlowRoute());
    unawaited(openFuture.then((_) => done = true));
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      tester.view.physicalSize = Size(810 + i * 10.0, 600);
      await tester.pump();
    }
    expect(done, isFalse);
    // Only the open's own re-check ran so far: the changes are coalesced.
    expect(pendingHomeRedirects, before + 1);

    pendingGate!.complete();
    pendingGate = null;
    await tester.pumpAndSettle();
    await openFuture;

    expect(router.stack, [const PendingHomeRoute(), const PendingSlowRoute()]);
    expect(pendingHomeRedirects, before + 2);
    expect(pendingHomeSawSlow, 1);
  });

  testWidgets('a pending navigation finishes before the re-check sends Login', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(
      routes: {'/slow-guarded': (params) => const SlowGuardedRoute()},
    );
    Widget app(bool signedIn) => Auth(
      signedIn: signedIn,
      child: MaterialApp.router(routerConfig: router.routerConfig),
    );

    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();

    final order = <Uri?>[];
    router.addListener(() => order.add(router.location));

    slowGuardedRedirects = 0;
    authGate = Completer<void>();
    var done = false;
    final openFuture = router.open(const SlowGuardedRoute());
    unawaited(openFuture.then((_) => done = true));
    await tester.pump();
    expect(done, isFalse);

    // Flip the dependency while the navigation is still pending.
    await tester.pumpWidget(app(false));
    expect(done, isFalse);

    authGate!.complete();
    authGate = null;
    await tester.pumpAndSettle();
    await openFuture;

    // Observed order: the pending open commits /slow-guarded (its redirect
    // captured signedIn == true), then the silent re-check sees false and
    // commits /login.
    expect(order, [Uri.parse('/slow-guarded'), Uri.parse('/login')]);
    expect(router.stack, [const LoginRoute()]);
    expect(slowGuardedRedirects, 2);
  });

  testWidgets('a pending navigation that fails still gets one re-check', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const PendingHomeRoute());
    pendingRouter = router;
    addTearDown(() => pendingRouter = null);
    await pumpApp(tester, router);

    pendingGate = Completer<void>();
    final openFuture = router.open(const ThrowingSlowRoute());
    final failed = expectLater(openFuture, throwsA(isA<StateError>()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();

    pendingGate!.complete();
    pendingGate = null;
    await tester.pumpAndSettle();
    await failed;

    expect(router.stack, [const PendingHomeRoute()]);
    expect(pendingHomeRedirects, 3);
    expect(pendingHomeSawSlow, 0);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('an error in a silent re-check goes to FlutterError', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const SometimesThrowingRoute());
    await pumpApp(tester, router);

    throwOnSilentRecheck = true;
    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isA<StateError>());
    expect(router.stack, [const SometimesThrowingRoute()]);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('an app navigation during a silent re-check wins', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const SlowOnResizeRoute());
    await pumpApp(tester, router);

    slowMode = true;
    slowGate = Completer<void>();
    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();
    expect(slowRedirects, 2); // launch + the silent re-check, awaiting the gate

    final openFuture = router.open(const OtherRoute());
    await tester.pumpAndSettle();
    await openFuture;
    expect(router.stack, [const OtherRoute()]);
    expect(router.isNavigating.value, isFalse);

    // The superseded silent re-check resumes and must change nothing.
    slowGate!.complete();
    slowGate = null;
    await tester.pumpAndSettle();

    expect(router.stack, [const OtherRoute()]);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('a silent re-check with a synchronous redirect keeps isNavigating off', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const SizedRoute());
    await pumpApp(tester, router);

    final values = <bool>[];
    router.isNavigating.addListener(
      () => values.add(router.isNavigating.value),
    );
    final redirectsBefore = sizedRedirects;

    tester.view.physicalSize = const Size(900, 600);
    await tester.pumpAndSettle();

    expect(sizedRedirects, greaterThan(redirectsBefore));
    expect(values.where((value) => value), isEmpty);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('a silent re-check with an asynchronous redirect keeps isNavigating off', (
    tester,
  ) async {
    setSize(tester, const Size(800, 600));
    addTearDown(tester.view.reset);
    final router = makeRouter(initial: const SlowOnResizeRoute());
    await pumpApp(tester, router);

    final values = <bool>[];
    router.isNavigating.addListener(
      () => values.add(router.isNavigating.value),
    );
    final redirectsBefore = slowRedirects;

    tester.view.physicalSize = const Size(900, 600);
    await tester.pump();
    expect(router.isNavigating.value, isFalse);
    await tester.pumpAndSettle();

    expect(slowRedirects, greaterThan(redirectsBefore));
    expect(values.where((value) => value), isEmpty);
    expect(router.isNavigating.value, isFalse);
  });
}
