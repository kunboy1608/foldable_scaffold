import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

class HomeRoute extends FoldableFlatRoute {
  const HomeRoute();

  @override
  String get path => '/home';

  @override
  Widget build(BuildContext context) => const Text('home');
}

class TypesShell extends FoldableShellRoute {
  const TypesShell();

  @override
  List<FoldableShellChildRoute> get branches => const [
    TabOneRoute(),
    TabTwoRoute(),
    SettingsTabRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Column(
    children: [
      Text('shell tab ${shell.currentIndex}'),
      Expanded(child: shell.child),
    ],
  );
}

class TabOneRoute extends FoldableShellChildRoute {
  const TabOneRoute();

  @override
  String get path => '/one';

  @override
  FoldableShellParent get parent => const TypesShell();

  @override
  Widget build(BuildContext context) => const Text('tab one');
}

class TabTwoRoute extends FoldableShellChildRoute {
  const TabTwoRoute();

  @override
  String get path => '/two';

  @override
  FoldableShellParent get parent => const TypesShell();

  @override
  Widget build(BuildContext context) => const Text('tab two');
}

class TwoDetailRoute extends FoldableShellChildRoute {
  const TwoDetailRoute({required this.id});

  final String id;

  @override
  String get path => '/two/detail';

  @override
  Map<String, Object?> get params => {'id': id};

  @override
  FoldableShellParent get parent => const TabTwoRoute();

  @override
  Widget build(BuildContext context) => Text('two detail $id');
}

/// Below the shell without being one of its branches.
class OrphanRoute extends FoldableShellChildRoute {
  const OrphanRoute();

  @override
  String get path => '/orphan';

  @override
  FoldableShellParent get parent => const TypesShell();

  @override
  Widget build(BuildContext context) => const Text('orphan');
}

/// A flat route whose redirect answers with [target].
class RedirectingRoute extends FoldableFlatRoute {
  const RedirectingRoute(this.target);

  final FoldableRoute target;

  @override
  String get path => '/redirecting';

  @override
  FoldableRoute? redirect(BuildContext context, RouteState state) =>
      state.target == this ? target : null;

  @override
  Widget build(BuildContext context) => const Text('should not be built');
}

class PickerRoute extends FoldableFlatRoute {
  const PickerRoute();

  @override
  String get path => '/pick';

  @override
  Widget build(BuildContext context) => const Text('picker');
}

/// The README example: one page shown both in a tab and full screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const Text('settings');
}

mixin SettingsBody {
  Widget build(BuildContext context) => const SettingsScreen();
}

class SettingsTabRoute extends FoldableShellChildRoute with SettingsBody {
  const SettingsTabRoute();

  @override
  String get path => '/settings';

  @override
  FoldableShellParent get parent => const TypesShell();
}

class SettingsFullRoute extends FoldableFlatRoute with SettingsBody {
  const SettingsFullRoute();

  @override
  String get path => '/settings/full';
}

Future<FoldableRouter> pumpRouter(
  WidgetTester tester, {
  FoldableRoute initial = const HomeRoute(),
}) async {
  final router = FoldableRouter(
    initial: initial,
    routes: {
      '/one': (params) => const TabOneRoute(),
      '/two': (params) => const TabTwoRoute(),
      '/two/detail': (params) => TwoDetailRoute(id: params.getString('id')),
      '/pick': (params) => const PickerRoute(),
      '/settings': (params) => const SettingsTabRoute(),
      '/settings/full': (params) => const SettingsFullRoute(),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('T1 a push redirected inside a shell is committed like open', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    var notifications = 0;
    router.addListener(() => notifications++);

    final result = router.push<String>(
      const RedirectingRoute(TwoDetailRoute(id: '7')),
    );
    await tester.pumpAndSettle();

    await expectLater(result, completion(isNull));
    expect(router.stack, [
      const TypesShell(),
      const TabTwoRoute(),
      const TwoDetailRoute(id: '7'),
    ]);
    expect(router.location, Uri.parse('/two/detail?id=7'));
    expect(find.text('shell tab 1'), findsOneWidget);
    expect(find.text('two detail 7'), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(router.isNavigating.value, isFalse);
    expect(notifications, 1);
    expect(tester.takeException(), isNull);

    // Same result as open of the redirect target.
    await router.open(const TabOneRoute());
    await tester.pumpAndSettle();
    await router.open(const TwoDetailRoute(id: '7'));
    await tester.pumpAndSettle();
    expect(router.stack, [
      const TypesShell(),
      const TabTwoRoute(),
      const TwoDetailRoute(id: '7'),
    ]);
  });

  testWidgets('T2 a push redirected to the shell opens its first branch', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    var notifications = 0;
    router.addListener(() => notifications++);

    final result = router.push<String>(const RedirectingRoute(TypesShell()));
    await tester.pumpAndSettle();

    await expectLater(result, completion(isNull));
    expect(router.stack, [const TypesShell(), const TabOneRoute()]);
    expect(find.text('shell tab 0'), findsOneWidget);
    expect(find.text('tab one'), findsOneWidget);
    expect(notifications, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T3 a push redirected to another flat route pushes it', (
    tester,
  ) async {
    final router = await pumpRouter(tester);
    var notifications = 0;
    router.addListener(() => notifications++);

    final result = router.push<String>(const RedirectingRoute(PickerRoute()));
    await tester.pumpAndSettle();

    expect(router.stack, [const HomeRoute(), const PickerRoute()]);
    expect(find.text('picker'), findsOneWidget);
    expect(notifications, 1);

    router.pop('green');
    await tester.pumpAndSettle();
    await expectLater(result, completion('green'));
    expect(router.stack, [const HomeRoute()]);
  });

  testWidgets('T4 a route below the shell but in no branch is still an error', (
    tester,
  ) async {
    final router = await pumpRouter(tester, initial: const TypesShell());

    await expectLater(router.open(const OrphanRoute()), throwsStateError);
    await tester.pumpAndSettle();
    expect(router.stack, [const TypesShell(), const TabOneRoute()]);

    // Also when a push is redirected there.
    await expectLater(
      router.push<void>(const RedirectingRoute(OrphanRoute())),
      throwsStateError,
    );
    await tester.pumpAndSettle();
    expect(router.stack, [const TypesShell(), const TabOneRoute()]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one page in a tab and full screen through a shared mixin', (
    tester,
  ) async {
    final router = await pumpRouter(tester, initial: const TypesShell());

    await router.open(const SettingsTabRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [const TypesShell(), const SettingsTabRoute()]);
    expect(find.text('shell tab 2'), findsOneWidget);
    expect(find.text('settings'), findsOneWidget);

    router.push<void>(const SettingsFullRoute());
    await tester.pumpAndSettle();
    expect(router.stack, [
      const TypesShell(),
      const SettingsTabRoute(),
      const SettingsFullRoute(),
    ]);
    expect(router.location, Uri.parse('/settings/full'));
    expect(find.text('settings'), findsOneWidget);
  });
}
