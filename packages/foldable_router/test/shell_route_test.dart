import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

bool loggedIn = true;
final List<String> redirectOrder = [];

class HomeRoute extends FoldableFlatRoute {
  const HomeRoute();

  @override
  String get segment => '';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class LoginRoute extends FoldableFlatRoute {
  const LoginRoute();

  @override
  String get segment => 'login';

  @override
  Widget build(BuildContext context) => const Text('login');
}

class PickerRoute extends FoldableFlatRoute {
  const PickerRoute();

  @override
  String get segment => 'pick';

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('picker'),
      TextButton(
        onPressed: () => Navigator.of(context).pop('green'),
        child: const Text('pick green'),
      ),
    ],
  );
}

/// The shell used by most tests: branch 0 is a stateful list, branch 1 a
/// lazily built tab, branch 2 is guarded.
class ShellMain extends FoldableShellRoute {
  const ShellMain();

  @override
  List<FoldableShellChildRoute> get branches => const [
    TabARoute(),
    TabBRoute(),
    GuardedTabRoute(),
  ];

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

class TabARoute extends FoldableShellChildRoute {
  const TabARoute();

  @override
  String get segment => 'a';

  @override
  FoldableShellParent get parent => const ShellMain();

  @override
  Widget build(BuildContext context) => const CounterPage('tab a');
}

class ADetailRoute extends FoldableShellChildRoute {
  const ADetailRoute({required this.id});

  final String id;

  @override
  String get segment => 'detail';

  @override
  Map<String, Object?> get params => {'id': id};

  @override
  FoldableShellParent get parent => const TabARoute();

  @override
  Widget build(BuildContext context) => CounterPage('a detail $id');
}

class TabBRoute extends FoldableShellChildRoute {
  const TabBRoute();

  static int redirects = 0;

  @override
  String get segment => 'b';

  @override
  FoldableShellParent get parent => const ShellMain();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    redirects++;
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('tab b');
}

class BDetailRoute extends FoldableShellChildRoute {
  const BDetailRoute({required this.id});

  final String id;

  @override
  String get segment => 'detail';

  @override
  Map<String, Object?> get params => {'id': id};

  @override
  FoldableShellParent get parent => const TabBRoute();

  @override
  Widget build(BuildContext context) => Text('b detail $id');
}

class GuardedTabRoute extends FoldableShellChildRoute {
  const GuardedTabRoute();

  @override
  String get segment => 'guarded';

  @override
  FoldableShellParent get parent => const ShellMain();

  @override
  FoldableRoute? redirect(BuildContext context, RouteState state) =>
      loggedIn ? null : const LoginRoute();

  @override
  Widget build(BuildContext context) => const Text('guarded tab');
}

/// A route whose parent is the shell but which is not one of its branches.
class OrphanRoute extends FoldableShellChildRoute {
  const OrphanRoute();

  @override
  String get segment => 'orphan';

  @override
  FoldableShellParent get parent => const ShellMain();

  @override
  Widget build(BuildContext context) => const Text('orphan');
}

/// Sits below [ShellMain] without being one of its branches: only reached
/// through redirects.
class RedirectIntoShellRoute extends FoldableFlatRoute {
  const RedirectIntoShellRoute();

  @override
  String get segment => 'redirect-into';

  @override
  FoldableRoute? redirect(BuildContext context, RouteState state) =>
      const ADetailRoute(id: '9');

  @override
  Widget build(BuildContext context) => const Text('should not be built');
}

/// A shell whose redirect runs before the redirect of its branch.
class OrderedShell extends FoldableShellRoute {
  const OrderedShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    redirectOrder.add('shell');
    return null;
  }

  @override
  List<FoldableShellChildRoute> get branches => const [OrderedTabRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Column(
    children: [
      const Text('ordered shell'),
      Expanded(child: shell.child),
    ],
  );
}

class OrderedTabRoute extends FoldableShellChildRoute {
  const OrderedTabRoute();

  @override
  String get segment => 'ordered';

  @override
  FoldableShellParent get parent => const OrderedShell();

  @override
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) {
    redirectOrder.add('tab');
    return null;
  }

  @override
  Widget build(BuildContext context) => const Text('ordered tab');
}

/// A page of the root navigator that sits *below* [LandingShell] in its
/// parent chain.
class LandingRoute extends FoldableFlatRoute {
  const LandingRoute();

  @override
  String get segment => 'landing';

  @override
  Widget build(BuildContext context) => const CounterPage('landing');
}

/// A shell whose parent chain has a page of its own.
class LandingShell extends FoldableShellRoute {
  const LandingShell();

  @override
  FoldableFlatRoute? get parent => const LandingRoute();

  @override
  List<FoldableShellChildRoute> get branches => const [LandingTabRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Column(
    children: [
      const Text('landing shell'),
      Expanded(child: shell.child),
    ],
  );
}

class LandingTabRoute extends FoldableShellChildRoute {
  const LandingTabRoute();

  @override
  String get segment => 'tab';

  @override
  FoldableShellParent get parent => const LandingShell();

  @override
  Widget build(BuildContext context) => const Text('landing tab');
}

/// A shell guarding everything inside it.
class GuardedShell extends FoldableShellRoute {
  const GuardedShell();

  @override
  List<FoldableShellChildRoute> get branches => const [SecretRoute()];

  @override
  FoldableRoute? redirect(BuildContext context, RouteState state) =>
      loggedIn ? null : const LoginRoute();

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Column(
    children: [
      const Text('guarded shell'),
      Expanded(child: shell.child),
    ],
  );
}

class SecretRoute extends FoldableShellChildRoute {
  const SecretRoute();

  @override
  String get segment => 'secret';

  @override
  FoldableShellParent get parent => const GuardedShell();

  @override
  Widget build(BuildContext context) => const Text('secret');
}

class HeroShell extends FoldableShellRoute {
  const HeroShell();

  @override
  List<FoldableShellChildRoute> get branches => const [HeroListRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Scaffold(body: shell.child);
}

class HeroListRoute extends FoldableShellChildRoute {
  const HeroListRoute();

  @override
  String get segment => 'hero';

  @override
  FoldableShellParent get parent => const HeroShell();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Hero(
            tag: 'box',
            child: ColoredBox(
              key: Key('flying'),
              color: Colors.teal,
              child: SizedBox(width: 40, height: 40),
            ),
          ),
          TextButton(
            onPressed: () =>
                FoldableRouter.of(context).open(const HeroDetailRoute()),
            child: const Text('go detail'),
          ),
        ],
      ),
    ),
  );
}

class HeroDetailRoute extends FoldableShellChildRoute {
  const HeroDetailRoute();

  @override
  String get segment => 'detail';

  @override
  FoldableShellParent get parent => const HeroListRoute();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Hero(
        tag: 'box',
        child: ColoredBox(
          key: Key('flying'),
          color: Colors.teal,
          child: SizedBox(width: 120, height: 120),
        ),
      ),
    ),
  );
}

class CounterPage extends StatefulWidget {
  const CounterPage(this.label, {super.key});

  final String label;

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label),
        TextButton(
          key: const Key('increment'),
          onPressed: () => setState(() => count++),
          child: Text('count $count'),
        ),
      ],
    ),
  );
}

FoldableRouter createShellRouter({
  FoldableRoute initial = const ShellMain(),
  Map<String, FoldableRouteFactory> extraRoutes = const {},
}) {
  final router = FoldableRouter(
    initial: initial,
    routes: {
      '/a': (params) => const TabARoute(),
      '/a/detail': (params) => ADetailRoute(id: params['id']!),
      '/b': (params) => const TabBRoute(),
      '/b/detail': (params) => BDetailRoute(id: params['id']!),
      '/guarded': (params) => const GuardedTabRoute(),
      '/hero': (params) => const HeroListRoute(),
      '/hero/detail': (params) => const HeroDetailRoute(),
      '/secret': (params) => const SecretRoute(),
      '/login': (params) => const LoginRoute(),
      '/pick': (params) => const PickerRoute(),
      '/landing': (params) => const LandingRoute(),
      '/landing/tab': (params) => const LandingTabRoute(),
      ...extraRoutes,
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> pumpShell(
  WidgetTester tester, {
  FoldableRoute initial = const ShellMain(),
  String? deepLink,
}) async {
  if (deepLink != null) {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = deepLink;
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
  }
  final router = createShellRouter(initial: initial);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Uri reportedUri(FoldableRouter router) =>
    router.routerConfig.routeInformationProvider!.value.uri;

void main() {
  setUp(() {
    loggedIn = true;
    redirectOrder.clear();
    TabBRoute.redirects = 0;
  });

  testWidgets('the shell is one root page with a navigator per branch', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    expect(router.stack, [const ShellMain(), const TabARoute()]);
    expect(find.text('tab a'), findsOneWidget);
    expect(find.text('tab 0'), findsOneWidget);
    expect(find.text('tab b', skipOffstage: false), findsNothing);
    // Root navigator + the navigator of the only built branch.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Navigator,
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
    expect(router.location, Uri.parse('/a'));
    expect(reportedUri(router), Uri.parse('/a'));
  });

  testWidgets('open inside a branch builds the chain under the shell', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
    ]);
    expect(find.text('a detail 7'), findsOneWidget);
    expect(find.text('tab 0'), findsOneWidget);
    expect(router.location, Uri.parse('/a/detail?id=7'));
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Navigator,
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('switching tabs keeps the stack and the state of the other '
      'branch', (tester) async {
    final router = await pumpShell(tester);

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'increment');
    expect(find.text('count 1'), findsOneWidget);

    await tapKey(tester, 'tab-1');
    expect(router.stack, [const ShellMain(), const TabBRoute()]);
    expect(find.text('tab b'), findsOneWidget);
    expect(find.text('a detail 7'), findsNothing);

    await tapKey(tester, 'tab-0');
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
    ]);
    expect(find.text('a detail 7'), findsOneWidget);
    // The page state survived the tab switch.
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('branches are built lazily and run their redirect on first '
      'visit and when shown again', (tester) async {
    final router = await pumpShell(tester);

    expect(TabBRoute.redirects, 0);
    expect(find.text('tab b', skipOffstage: false), findsNothing);

    await tapKey(tester, 'tab-1');
    expect(TabBRoute.redirects, 1);
    expect(find.text('tab b'), findsOneWidget);
    expect(router.stack, [const ShellMain(), const TabBRoute()]);

    await tapKey(tester, 'tab-0');
    expect(router.stack, [const ShellMain(), const TabARoute()]);
    await tapKey(tester, 'tab-1');
    expect(TabBRoute.redirects, 2);
    expect(router.stack, [const ShellMain(), const TabBRoute()]);
  });

  testWidgets('open(shell) opens its first branch', (tester) async {
    final router = await pumpShell(tester, initial: const HomeRoute());
    expect(router.stack, [const HomeRoute()]);

    await router.open(const ShellMain());
    await tester.pumpAndSettle();

    expect(router.stack, [const ShellMain(), const TabARoute()]);
    expect(find.text('tab a'), findsOneWidget);
  });

  testWidgets('the redirect of the shell runs before the one of the branch', (
    tester,
  ) async {
    await pumpShell(tester, initial: const OrderedShell());

    expect(redirectOrder, ['shell', 'tab']);
    expect(find.text('ordered tab'), findsOneWidget);
  });

  testWidgets('a redirect on the shell blocks the routes inside it', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    loggedIn = false;

    await router.open(const SecretRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);
    expect(find.text('secret', skipOffstage: false), findsNothing);
  });

  testWidgets('push whose redirect lands inside the shell opens it', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    // The redirect of the pushed route lands inside the shell: committed
    // like open, and the push completes with null.
    await expectLater(
      router.push<void>(const RedirectIntoShellRoute()),
      completion(isNull),
    );
    await tester.pumpAndSettle();
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '9'),
    ]);
    expect(router.isNavigating.value, isFalse);
  });

  testWidgets('push outside the shell covers it and returns its result', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();

    final result = router.push<String>(const PickerRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
      const PickerRoute(),
    ]);
    expect(find.text('picker'), findsOneWidget);
    // The shell is fully covered: its frame is offstage.
    expect(find.text('tab 0'), findsNothing);
    expect(router.location, Uri.parse('/pick'));

    await tester.tap(find.text('pick green'));
    await tester.pumpAndSettle();

    expect(await result, 'green');
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
    ]);
    expect(find.text('a detail 7'), findsOneWidget);
    expect(find.text('tab 0'), findsOneWidget);
    expect(router.location, Uri.parse('/a/detail?id=7'));
  });

  testWidgets('open drops an open overlay and completes its push with null', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    final pushed = router.push<String>(const PickerRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const PickerRoute(),
    ]);

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();

    expect(await pushed, isNull);
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
    ]);
    expect(find.text('picker'), findsNothing);
    expect(router.location, Uri.parse('/a/detail?id=7'));
  });

  testWidgets('push outside the shell then open a route in another branch', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    router.push<String>(const PickerRoute());
    await tester.pumpAndSettle();
    expect(find.text('picker'), findsOneWidget);

    await router.open(const TabBRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const ShellMain(), const TabBRoute()]);
    expect(find.text('picker'), findsNothing);
  });

  testWidgets('a page below the shell stays and keeps its state', (
    tester,
  ) async {
    final router = await pumpShell(tester, initial: const LandingShell());

    expect(reportedUri(router), Uri.parse('/landing/tab'));
    expect(router.stack, [
      const LandingRoute(),
      const LandingShell(),
      const LandingTabRoute(),
    ]);
    // The shell is opaque: its parent page is alive, offstage, below it.
    expect(find.text('landing', skipOffstage: false), findsOneWidget);
    expect(find.text('landing shell'), findsOneWidget);
    expect(find.text('landing tab'), findsOneWidget);

    final page = tester.state<State<CounterPage>>(
      find.byType(CounterPage, skipOffstage: false),
    );

    // Opening the branch root again keeps the bottom of the stack.
    await router.open(const LandingTabRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [
      const LandingRoute(),
      const LandingShell(),
      const LandingTabRoute(),
    ]);
    expect(
      tester.state<State<CounterPage>>(
        find.byType(CounterPage, skipOffstage: false),
      ),
      same(page),
    );

    // Back at the root of the branch is not handled: the system leaves the
    // app.
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(router.stack, [
      const LandingRoute(),
      const LandingShell(),
      const LandingTabRoute(),
    ]);
  });

  testWidgets('pop goes back inside the branch and stops at its root', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();
    expect(router.stack, [const ShellMain(), const TabARoute()]);

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.stack, [const ShellMain(), const TabARoute()]);

    // Going back again would leave the app; it does not jump to the first
    // tab either.
    await tapKey(tester, 'tab-1');
    router.pop();
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isFalse);
    await tester.pumpAndSettle();
    expect(router.stack, [const ShellMain(), const TabBRoute()]);
    expect(find.text('tab b'), findsOneWidget);
  });

  testWidgets('back removes the full-screen page before the branch page', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    final result = router.push<String>(const PickerRoute());
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(await result, isNull);
    expect(router.stack, [
      const ShellMain(),
      const TabARoute(),
      const ADetailRoute(id: '7'),
    ]);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.stack, [const ShellMain(), const TabARoute()]);

    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  testWidgets('location, URL and listeners follow the current branch', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    var notifications = 0;
    router.addListener(() => notifications++);
    addTearDown(() => router.removeListener(() {}));

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    expect(notifications, 1);
    expect(router.location, Uri.parse('/a/detail?id=7'));

    await tapKey(tester, 'tab-1');
    expect(notifications, 2);
    expect(router.location, Uri.parse('/b'));
    expect(reportedUri(router), Uri.parse('/b'));
    expect(router.stack, [const ShellMain(), const TabBRoute()]);

    await tapKey(tester, 'tab-0');
    expect(notifications, 3);
    expect(router.location, Uri.parse('/a/detail?id=7'));
    expect(reportedUri(router), Uri.parse('/a/detail?id=7'));
  });

  testWidgets('a deep link builds only the branch that contains the route', (
    tester,
  ) async {
    final router = await pumpShell(tester, deepLink: '/b/detail?id=2');

    expect(router.stack, [
      const ShellMain(),
      const TabBRoute(),
      const BDetailRoute(id: '2'),
    ]);
    expect(find.text('b detail 2'), findsOneWidget);
    expect(router.location, Uri.parse('/b/detail?id=2'));
    // Branch A was never built.
    expect(find.text('tab a', skipOffstage: false), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Navigator,
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('open outside the shell drops the shell and every branch', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'tab-1');

    await router.open(const HomeRoute());
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute()]);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('tab 0', skipOffstage: false), findsNothing);
    expect(find.text('tab a', skipOffstage: false), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Navigator,
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('refresh re-runs the redirects of the shell and the branch', (
    tester,
  ) async {
    final router = await pumpShell(tester);
    await router.open(const SecretRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const GuardedShell(), const SecretRoute()]);

    await router.refresh();
    await tester.pumpAndSettle();
    expect(router.stack, [const GuardedShell(), const SecretRoute()]);

    loggedIn = false;
    await router.refresh();
    await tester.pumpAndSettle();

    expect(router.stack, [const LoginRoute()]);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('a route below the shell but in no branch is an error', (
    tester,
  ) async {
    final router = await pumpShell(tester);

    await expectLater(router.open(const OrphanRoute()), throwsStateError);
    await tester.pumpAndSettle();

    expect(router.stack, [const ShellMain(), const TabARoute()]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Hero flies between two pages of the same branch', (
    tester,
  ) async {
    final router = await pumpShell(tester, initial: const HeroShell());
    expect(router.stack, [const HeroShell(), const HeroListRoute()]);

    final before = tester.getRect(find.byKey(const Key('flying')));
    expect(before.size, const Size(40, 40));

    await tester.tap(find.text('go detail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // In flight: the shuttle lives in the overlay of the nested navigator.
    expect(router.stack, [
      const HeroShell(),
      const HeroListRoute(),
      const HeroDetailRoute(),
    ]);
    final flying = tester.getRect(find.byKey(const Key('flying')));
    expect(flying.width, inExclusiveRange(40, 120));

    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('flying'))).size,
      const Size(120, 120),
    );
  });

  testWidgets('reports to the system when back can be handled', (tester) async {
    final reports = <bool>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          reports.add(call.arguments as bool);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    // WidgetsApp only forwards NavigationNotifications to the platform while
    // the app is alive; the binding starts without a lifecycle state.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
      (_) {},
    );

    final router = await pumpShell(tester);
    await tester.pumpAndSettle();
    // At the root of the branch the system leaves the app.
    expect(reports, isNotEmpty);
    expect(reports.last, isFalse);

    await router.open(const ADetailRoute(id: '7'));
    await tester.pumpAndSettle();
    expect(reports.last, isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(reports.last, isFalse);
  });
}
