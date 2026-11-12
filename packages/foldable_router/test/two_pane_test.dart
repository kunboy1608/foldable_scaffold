import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

// ---------------------------------------------------------------------------
// Test app: a shell with two branches; two panes driven by [paneConfig].
// ---------------------------------------------------------------------------

class PaneConfig {
  bool twoPane = false;
}

final PaneConfig paneConfig = PaneConfig();

class TwoPaneShell extends FoldableShellRoute {
  const TwoPaneShell();

  @override
  List<FoldableRoute> get branches => const [UsersRoute(), HomeRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
      ],
    ),
  );

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (!paneConfig.twoPane) return null;
    final Widget secondary = panes.hasSecondary
        ? KeyedSubtree(
            key: const Key('secondary-frame'),
            child: panes.secondary,
          )
        : const Center(
            key: Key('secondary-choose'),
            child: Text('choose a user'),
          );
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: KeyedSubtree(
            key: const Key('primary-frame'),
            child: panes.primary,
          ),
        ),
        const VerticalDivider(width: 24),
        Expanded(flex: 3, child: secondary),
      ],
    );
  }
}

class UsersRoute extends FoldableRoute {
  const UsersRoute();

  @override
  String get path => '/users';

  @override
  FoldableRoute? get parent => const TwoPaneShell();

  @override
  Widget build(BuildContext context) => const UsersPage();
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => UsersPageState();
}

class UsersPageState extends State<UsersPage> {
  int count = 0;
  final TextEditingController text = TextEditingController();
  final ScrollController scroll = ScrollController();
  FoldablePane? lastPane;
  bool lastTickerMode = true;

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lastPane = FoldableRouter.paneOf(context);
    lastTickerMode = TickerMode.valuesOf(context).enabled;
    return Scaffold(
      key: const Key('page users'),
      appBar: AppBar(title: const Text('users')),
      body: Column(
        children: <Widget>[
          const Text('users list'),
          Text('users count $count'),
          TextButton(
            key: const Key('users-increment'),
            onPressed: () => setState(() => count++),
            child: const Text('users +'),
          ),
          TextField(key: const Key('users-text'), controller: text),
          for (final id in const ['7', '42'])
            ListTile(
              leading: TestHero('hero-user-$id'),
              title: Text('User $id'),
              onTap: () => FoldableRouter.of(context).open(UserRoute(id: id)),
            ),
          Expanded(
            child: ListView.builder(
              key: const Key('users-list'),
              controller: scroll,
              itemCount: 50,
              itemBuilder: (context, index) =>
                  SizedBox(height: 40, child: Text('users item ${index + 2}')),
            ),
          ),
        ],
      ),
    );
  }
}

class UserRoute extends FoldableRoute {
  const UserRoute({required this.id});

  final String id;

  @override
  String get path => '/users/detail';

  @override
  Map<String, String?> get params => {'id': id};

  @override
  FoldableRoute? get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => UserPage(id: id);
}

class UserPage extends StatefulWidget {
  const UserPage({super.key, required this.id});

  final String id;

  @override
  State<UserPage> createState() => UserPageState();
}

class UserPageState extends State<UserPage> {
  int count = 0;
  final TextEditingController text = TextEditingController();
  final ScrollController scroll = ScrollController();
  FoldablePane? lastPane;

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    lastPane = FoldableRouter.paneOf(context);
    return Scaffold(
      key: Key('page user-${widget.id}'),
      appBar: AppBar(title: Text('user ${widget.id}')),
      body: Column(
        children: <Widget>[
          const Text('user detail'),
          TestHero('hero-user-${widget.id}'),
          Text('user count $count'),
          TextButton(
            key: Key('user-increment-${widget.id}'),
            onPressed: () => setState(() => count++),
            child: const Text('user +'),
          ),
          TextField(key: Key('user-text-${widget.id}'), controller: text),
          Expanded(
            child: ListView.builder(
              key: Key('user-list-${widget.id}'),
              controller: scroll,
              itemCount: 50,
              itemBuilder: (context, index) =>
                  SizedBox(height: 40, child: Text('user item ${index + 2}')),
            ),
          ),
          TextButton(
            key: Key('close-user-${widget.id}'),
            onPressed: () => FoldableRouter.close(context),
            child: const Text('close'),
          ),
        ],
      ),
    );
  }
}

/// A [Hero] whose shuttle is easy to detect mid-flight.
class TestHero extends StatelessWidget {
  const TestHero(this.tag, {super.key});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      placeholderBuilder: (context, size, child) => child,
      flightShuttleBuilder: (context, animation, direction, from, to) =>
          const SizedBox(
            key: Key('hero shuttle'),
            width: 40,
            height: 40,
            child: Text('flying'),
          ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: ColoredBox(color: Colors.teal, child: Text(tag)),
      ),
    );
  }
}

class HomeRoute extends FoldableRoute {
  const HomeRoute();

  @override
  String get path => '/';

  @override
  FoldableRoute? get parent => const TwoPaneShell();

  @override
  Widget build(BuildContext context) =>
      const Material(key: Key('page home'), child: Text('home'));
}

class GuardedUserRoute extends FoldableRoute {
  const GuardedUserRoute({required this.id});

  final String id;

  @override
  String get path => '/users/guarded';

  @override
  Map<String, String?> get params => {'id': id};

  @override
  FoldableRoute? get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => GuardedUserPage(id: id);
}

class GuardedUserPage extends StatelessWidget {
  const GuardedUserPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) =>
        guardedPops.add(didPop),
    child: Scaffold(
      key: Key('page user-$id'),
      appBar: AppBar(title: Text('user $id')),
      body: Center(child: Text('user $id')),
    ),
  );
}

class DeepRoute extends FoldableRoute {
  const DeepRoute();

  @override
  String get path => '/users/deep';

  @override
  FoldableRoute? get parent => const UserRoute(id: '7');

  @override
  Widget build(BuildContext context) => const DeepPage();
}

class DeepPage extends StatelessWidget {
  const DeepPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('page deep'),
    appBar: AppBar(title: const Text('deep')),
    body: const Center(child: Text('deep page body')),
  );
}

final List<bool> guardedPops = <bool>[];

FoldableRouter createRouter() {
  final router = FoldableRouter(
    initial: const TwoPaneShell(),
    routes: {
      '/users': (_) => const UsersRoute(),
      '/users/detail': (params) => UserRoute(id: params['id']!),
      '/users/deep': (_) => const DeepRoute(),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> pumpApp(WidgetTester tester) async {
  final router = createRouter();
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Rebuilds the app once so the area is rebuilt with the current mode.
Future<void> rebuild(WidgetTester tester, FoldableRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
}

Future<void> setTwoPane(
  WidgetTester tester,
  FoldableRouter router, {
  required bool value,
}) async {
  paneConfig.twoPane = value;
  await rebuild(tester, router);
  await tester.pumpAndSettle();
}

Rect frameRect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key), skipOffstage: false));

int _notifications = 0;

// ---------------------------------------------------------------------------
// Platform helpers (predictive back, lifecycle).
// ---------------------------------------------------------------------------

final List<bool> reportedHandlesBack = <bool>[];

void installPlatformMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          reportedHandlesBack.add(call.arguments! as bool);
        }
        return null;
      });
}

Future<void> resumeApp(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    const StringCodec().encodeMessage(AppLifecycleState.resumed.toString()),
    (ByteData? _) {},
  );
}

Future<bool?> _backGestureMessage(WidgetTester tester, MethodCall call) async {
  bool? result;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/backgesture',
    const StandardMethodCodec().encodeMethodCall(call),
    (ByteData? data) {
      if (data != null) {
        result = const StandardMethodCodec().decodeEnvelope(data) as bool?;
      }
    },
  );
  await tester.pump();
  return result;
}

Map<String, Object?> _backEvent(double x, double progress) => <String, Object?>{
  'touchOffset': <double>[x, 300.0],
  'progress': progress,
  'swipeEdge': 0,
};

Future<bool?> startBackGesture(WidgetTester tester) => _backGestureMessage(
  tester,
  MethodCall('startBackGesture', _backEvent(5.0, 0.0)),
);

Future<void> updateBackGesture(WidgetTester tester) async {
  await _backGestureMessage(
    tester,
    MethodCall('updateBackGestureProgress', _backEvent(200.0, 0.45)),
  );
}

Future<void> commitBackGesture(WidgetTester tester) async {
  await _backGestureMessage(tester, const MethodCall('commitBackGesture'));
  await tester.pumpAndSettle();
}

Future<void> cancelBackGesture(WidgetTester tester) async {
  await _backGestureMessage(tester, const MethodCall('cancelBackGesture'));
  await tester.pumpAndSettle();
}

void androidTest(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    paneConfig.twoPane = false;
    _notifications = 0;
    guardedPops.clear();
    reportedHandlesBack.clear();
    installPlatformMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('step 2: display rules', () {
    testWidgets('[A] in two panes: A on the left, the right side empty', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
      expect(
        tester.getRect(find.byKey(const Key('page users'))),
        frameRect(tester, 'primary-frame'),
      );
      expect(
        FoldableRouter.paneOf(
          tester.element(find.byKey(const Key('page users'))),
        ),
        FoldablePane.primary,
      );
      expect(find.byKey(const Key('secondary-choose')), findsOneWidget);
    });

    testWidgets('[A,B]: A on the left, B on the right', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      final Rect left = frameRect(tester, 'primary-frame');
      final Rect right = frameRect(tester, 'secondary-frame');
      expect(tester.getRect(find.byKey(const Key('page users'))), left);
      expect(tester.getRect(find.byKey(const Key('page user-7'))), right);
      // Asymmetric 2:3 panes with a 24px gutter.
      expect(right.width / left.width, closeTo(3 / 2, 0.01));
      expect(right.left - left.right, 24);
      expect(
        FoldableRouter.paneOf(
          tester.element(find.byKey(const Key('page users'))),
        ),
        FoldablePane.primary,
      );
      expect(
        FoldableRouter.paneOf(
          tester.element(find.byKey(const Key('page user-7'))),
        ),
        FoldablePane.secondary,
      );
    });

    testWidgets('[A,B,C]: B on the left, C on the right, A hidden', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      // Open user 7, then user 42 (both children of Users).
      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
        const DeepRoute(),
      ]);
      final Rect left = frameRect(tester, 'primary-frame');
      final Rect right = frameRect(tester, 'secondary-frame');
      expect(tester.getRect(find.byKey(const Key('page user-7'))), left);
      expect(tester.getRect(find.byKey(const Key('page deep'))), right);

      // A (users) is alive but hidden: not painted, not hit-testable, out of
      // semantics, out of focus, ticker stopped.
      expect(find.text('users list'), findsNothing);
      expect(
        find.byKey(const Key('page users'), skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byKey(const Key('users-text')).hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('users list'), findsNothing);
      final UsersPageState usersState = tester.state<UsersPageState>(
        find.byType(UsersPage, skipOffstage: false),
      );
      expect(usersState.lastTickerMode, isFalse);
      expect(usersState.lastPane, FoldablePane.primary);
    });

    testWidgets('stack, URL and tabs do not change between modes', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/users/detail?id=7'));

      await setTwoPane(tester, router, value: true);
      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/users/detail?id=7'));

      await setTwoPane(tester, router, value: false);
      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      expect(router.location, Uri.parse('/users/detail?id=7'));
    });

    testWidgets('pop re-slots on the very next frame (no deferral)', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();

      router.pop();
      await tester.pump();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      final Rect left = frameRect(tester, 'primary-frame');
      final Rect right = frameRect(tester, 'secondary-frame');
      // B moved to the right, A back on the left, one frame after the pop.
      expect(tester.getRect(find.byKey(const Key('page users'))), left);
      expect(tester.getRect(find.byKey(const Key('page user-7'))), right);
      // C is still on screen above the right pane, animating away.
      final Finder leaving = find.byKey(
        const Key('page deep'),
        skipOffstage: false,
      );
      expect(leaving, findsOneWidget);
      expect(tester.getRect(leaving).left, right.left);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('page deep')), findsNothing);
    });
  });

  group('step 2: state and mode switches', () {
    testWidgets('page State, scroll, text and counter survive pane moves and '
        'mode switches', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      final UsersPageState users = tester.state<UsersPageState>(
        find.byType(UsersPage),
      );
      final Element navigator = tester.element(
        find
            .byWidgetPredicate(
              (widget) => widget is Navigator,
              skipOffstage: false,
            )
            .last,
      );
      await tester.tap(find.byKey(const Key('users-increment')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('users-text')), 'draft');
      await tester.pump();
      users.scroll.jumpTo(160);
      await tester.pump();

      await setTwoPane(tester, router, value: false);
      await setTwoPane(tester, router, value: true);

      expect(
        identical(tester.state<UsersPageState>(find.byType(UsersPage)), users),
        isTrue,
      );
      expect(
        identical(
          tester.element(
            find
                .byWidgetPredicate(
                  (widget) => widget is Navigator,
                  skipOffstage: false,
                )
                .last,
          ),
          navigator,
        ),
        isTrue,
      );
      expect(find.text('users count 1'), findsOneWidget);
      expect(find.text('draft'), findsOneWidget);
      expect(users.scroll.offset, 160);

      // Push a detail: users slides into the left pane with its state.
      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      expect(
        identical(tester.state<UsersPageState>(find.byType(UsersPage)), users),
        isTrue,
      );
      expect(
        tester.getRect(find.byKey(const Key('page users'))),
        frameRect(tester, 'primary-frame'),
      );

      router.pop();
      await tester.pumpAndSettle();
      expect(
        identical(tester.state<UsersPageState>(find.byType(UsersPage)), users),
        isTrue,
      );
      expect(find.text('users count 1'), findsOneWidget);
      expect(users.scroll.offset, 160);
    });

    testWidgets('an open bottom sheet survives a mode switch', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byKey(const Key('page users'))),
          builder: (context) => const Text('sheet body'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('sheet body'), findsOneWidget);

      await setTwoPane(tester, router, value: false);
      expect(find.text('sheet body'), findsOneWidget);

      await setTwoPane(tester, router, value: true);
      expect(find.text('sheet body'), findsOneWidget);
    });
  });

  group('step 2: transitions', () {
    testWidgets('one pane: during a push the page below is painted', (
      tester,
    ) async {
      final router = await pumpApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('users list'), findsOneWidget);
      final Rect running = tester.getRect(
        find.byKey(const Key('page user-7'), skipOffstage: false),
      );
      final Size screen =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      // The incoming page is mid-slide: not settled yet.
      expect(running.left, greaterThan(0));
      expect(running.left, lessThan(screen.width));

      await tester.pumpAndSettle();
      expect(router.stack.last, const UserRoute(id: '7'));
    });

    testWidgets('two panes: the left page stands still during a push', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);
      final Rect left = frameRect(tester, 'primary-frame');

      await tester.tap(find.text('User 7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The left page is visible and did not move at all.
      expect(find.text('users list'), findsOneWidget);
      expect(tester.getRect(find.byKey(const Key('page users'))), left);
      // The incoming page is still animating in.
      final Rect incoming = tester.getRect(
        find.byKey(const Key('page user-7'), skipOffstage: false),
      );
      expect(incoming.left, isNot(left.left));

      await tester.pumpAndSettle();
    });

    testWidgets(
      'two panes: hidden pages keep their state across mode changes',
      (tester) async {
        final router = await pumpApp(tester);
        await setTwoPane(tester, router, value: true);

        await tester.tap(find.text('User 7'));
        await tester.pumpAndSettle();
        final UserPageState user7 = tester.state<UserPageState>(
          find.byType(UserPage),
        );
        await tester.tap(find.byKey(const Key('user-increment-7')));
        await tester.pump();
        expect(find.text('user count 1'), findsOneWidget);

        // Back to one pane and forward again: the detail page is still the
        // same State.
        await setTwoPane(tester, router, value: false);
        await setTwoPane(tester, router, value: true);
        expect(
          identical(tester.state<UserPageState>(find.byType(UserPage)), user7),
          isTrue,
        );
        expect(find.text('user count 1'), findsOneWidget);
      },
    );
  });

  group('step 2: heroes', () {
    testWidgets('one pane: the hero flies', (tester) async {
      final router = await pumpApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('hero shuttle')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hero shuttle')), findsNothing);
      expect(router.stack.last, const UserRoute(id: '7'));
    });

    testWidgets('two panes: no flight, each side keeps its own hero', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('hero shuttle')), findsNothing);
      final heroFinder = find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'hero-user-7',
      );
      expect(heroFinder, findsNWidgets(2));

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('hero shuttle')), findsNothing);
    });
  });

  group('step 3: back', () {
    testWidgets('system back pops exactly the top page in two-pane', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);
      await resumeApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      expect(
        tester.getRect(find.byKey(const Key('page user-7'))),
        frameRect(tester, 'secondary-frame'),
      );
      expect(
        tester.getRect(find.byKey(const Key('page users'))),
        frameRect(tester, 'primary-frame'),
      );
    });

    testWidgets('back button of the right pane removes the right page only, '
        'in one router update', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();
      router.addListener(() => _notifications++);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('page deep')),
          matching: find.byType(BackButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
      expect(_notifications, 1);
    });

    testWidgets('back button of the left pane removes both visible pages, '
        'in one router update', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();
      router.addListener(() {
        _notifications++;
      });

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('page user-7')),
          matching: find.byType(BackButton),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
      expect(
        tester.getRect(find.byKey(const Key('page users'))),
        frameRect(tester, 'primary-frame'),
      );
      expect(_notifications, 1);
    });

    testWidgets('the root page of the tab in the left pane has no back arrow', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('page users')),
          matching: find.byType(BackButton),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('page user-7')),
          matching: find.byType(BackButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('without a pointer, the pane is inferred from the focused '
        'page', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();
      router.addListener(() => _notifications++);

      // Focus something inside the left page, then pop without a pointer:
      // the pane comes from the focus.
      await tester.tap(find.byKey(const Key('user-text-7')));
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await Navigator.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).maybePop();
      await tester.pumpAndSettle();

      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
      expect(_notifications, 1);
    });

    testWidgets('PopScope(canPop: false) on the top page blocks system back, '
        'the back buttons and close(context)', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);
      await resumeApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const GuardedUserRoute(id: '9'));
      await tester.pumpAndSettle();
      final List<FoldableRoute> frozen = router.stack;

      // System back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(guardedPops, [false]);
      expect(router.stack, frozen);

      // Back button of the right pane.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('page user-9')),
          matching: find.byType(BackButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(guardedPops, [false, false]);
      expect(router.stack, frozen);

      // close(context).
      FoldableRouter.close(
        tester.element(find.byKey(const Key('page user-9'))),
      );
      await tester.pumpAndSettle();
      expect(guardedPops, [false, false, false]);
      expect(router.stack, frozen);
    });

    testWidgets('close(context) removes the page and every page above it', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();
      await FoldableRouter.of(
        tester.element(find.byKey(const Key('page user-7'))),
      ).open(const DeepRoute());
      await tester.pumpAndSettle();

      FoldableRouter.close(
        tester.element(find.byKey(const Key('page user-7'))),
      );
      await tester.pumpAndSettle();

      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
    });

    testWidgets('close(context) from the root page of the tab does nothing', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      FoldableRouter.close(tester.element(find.byKey(const Key('page users'))));
      await tester.pumpAndSettle();

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
    });

    testWidgets('close(context) also works in one pane', (tester) async {
      final router = await pumpApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('close-user-7')));
      await tester.pumpAndSettle();

      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
      expect(find.text('users list'), findsOneWidget);
    });

    androidTest('the predictive back gesture pops only the top page in '
        'two-pane mode; canceling changes nothing', (tester) async {
      final router = await pumpApp(tester);
      await setTwoPane(tester, router, value: true);
      await resumeApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      expect(await startBackGesture(tester), isTrue);
      await updateBackGesture(tester);
      await cancelBackGesture(tester);
      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);

      expect(await startBackGesture(tester), isTrue);
      await updateBackGesture(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('users list'), findsOneWidget);
      await commitBackGesture(tester);
      expect(router.stack, [const TwoPaneShell(), const UsersRoute()]);
    });

    androidTest('the predictive back gesture keeps the page below painted in '
        'one pane', (tester) async {
      final router = await pumpApp(tester);
      await resumeApp(tester);

      await tester.tap(find.text('User 7'));
      await tester.pumpAndSettle();

      expect(await startBackGesture(tester), isTrue);
      await updateBackGesture(tester);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('users list'), findsOneWidget);
      await cancelBackGesture(tester);

      expect(router.stack, [
        const TwoPaneShell(),
        const UsersRoute(),
        const UserRoute(id: '7'),
      ]);
    });
  });
}
