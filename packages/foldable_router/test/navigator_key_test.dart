import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

class HomeRoute extends FoldableFlatRoute {
  const HomeRoute();
  @override
  String get segment => 'home';
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('home page')));
}

class DetailRoute extends FoldableFlatRoute {
  const DetailRoute();
  @override
  String get segment => 'detail';
  @override
  FoldableFlatRoute? get parent => const HomeRoute();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('detail page')));
}

Completer<void>? gate;

class SlowRoute extends FoldableFlatRoute {
  const SlowRoute();
  @override
  String get segment => 'slow';
  @override
  Future<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    await gate!.future;
    return null;
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('slow page')));
}

class Shell extends FoldableShellRoute {
  const Shell();
  @override
  List<FoldableShellChildRoute> get branches => const [
    TabRoute(),
    OtherTabRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.list), label: 'Tab'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Other'),
      ],
    ),
  );

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) => Row(
    children: <Widget>[
      Expanded(child: panes.primary),
      Expanded(
        child: panes.hasSecondary ? panes.secondary : const SizedBox.shrink(),
      ),
    ],
  );
}

class TabRoute extends FoldableShellChildRoute {
  const TabRoute();
  @override
  String get segment => 'tab';
  @override
  FoldableShellParent get parent => const Shell();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('tab page')));
}

class TabDetailRoute extends FoldableShellChildRoute {
  const TabDetailRoute();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const TabRoute();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('tab detail page')));
}

class OtherTabRoute extends FoldableShellChildRoute {
  const OtherTabRoute();
  @override
  String get segment => 'other';
  @override
  FoldableShellParent get parent => const Shell();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('other page')));
}

FoldableRouter createRouter(FoldableRoute initial) {
  final router = FoldableRouter(
    initial: initial,
    routes: {
      '/home': (_) => const HomeRoute(),
      '/home/detail': (_) => const DetailRoute(),
      '/slow': (_) => const SlowRoute(),
      '/tab': (_) => const TabRoute(),
      '/tab/detail': (_) => const TabDetailRoute(),
      '/other': (_) => const OtherTabRoute(),
    },
    notFoundBuilder: (context, uri) => Text('not found: $uri'),
    pendingBuilder: (context) => const Text('pending'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> pumpApp(
  WidgetTester tester,
  FoldableRoute initial,
) async {
  final router = createRouter(initial);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<String?> openDialog(FoldableRouter router) => showDialog<String>(
  context: router.navigatorKey.currentContext!,
  builder: (BuildContext context) => AlertDialog(
    title: const Text('global dialog'),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop('ok'),
        child: const Text('close dialog'),
      ),
    ],
  ),
);

void main() {
  testWidgets('null before the router is mounted and while pending', (
    tester,
  ) async {
    gate = Completer<void>();
    final router = createRouter(const SlowRoute());
    final GlobalKey<NavigatorState> key = router.navigatorKey;
    expect(key.currentState, isNull);
    expect(key.currentContext, isNull);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pump();
    expect(find.text('pending'), findsOneWidget);
    expect(key.currentContext, isNull);

    gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('slow page'), findsOneWidget);
    expect(key.currentState, isNotNull);
    expect(identical(router.navigatorKey, key), isTrue);
  });

  testWidgets('without a shell: dialog from the key, closed by its button '
      'and by the system back', (tester) async {
    final router = await pumpApp(tester, const HomeRoute());
    final BuildContext context = router.navigatorKey.currentContext!;
    // The context sees what a page context sees.
    expect(identical(FoldableRouter.of(context), router), isTrue);
    expect(Theme.of(context), isNotNull);

    // ignore: unawaited_futures
    router.open(const DetailRoute());
    await tester.pumpAndSettle();
    final stack = [const HomeRoute(), const DetailRoute()];

    String? result;
    // ignore: unawaited_futures
    openDialog(router).then((String? v) => result = v);
    await tester.pumpAndSettle();
    expect(find.text('global dialog'), findsOneWidget);
    await tester.tap(find.text('close dialog'));
    await tester.pumpAndSettle();
    expect(result, 'ok');
    expect(find.text('global dialog'), findsNothing);
    expect(router.stack, stack);

    // ignore: unawaited_futures
    openDialog(router);
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('global dialog'), findsNothing);
    expect(router.stack, stack, reason: 'back closed the dialog only');
    expect(tester.takeException(), isNull);
  });

  testWidgets('in a two-pane shell: the dialog is above the shell and back '
      'closes it first', (tester) async {
    final router = await pumpApp(tester, const Shell());
    final GlobalKey<NavigatorState> key = router.navigatorKey;
    // ignore: unawaited_futures
    router.open(const TabDetailRoute());
    await tester.pumpAndSettle();
    final stack = [const Shell(), const TabRoute(), const TabDetailRoute()];
    expect(router.stack, stack);

    // ignore: unawaited_futures
    openDialog(router);
    await tester.pumpAndSettle();
    expect(find.text('global dialog'), findsOneWidget);
    // On the root navigator: the barrier covers the bottom bar too.
    await tester.tap(find.text('Other'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('other page'), findsNothing);
    // (The tap on the barrier dismissed the dialog.)
    expect(find.text('global dialog'), findsNothing);
    expect(router.stack, stack);

    // ignore: unawaited_futures
    openDialog(router);
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('global dialog'), findsNothing);
    expect(router.stack, stack);

    // The key survives tab switches and leaving the shell.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('other page'), findsOneWidget);
    expect(key.currentState, isNotNull);
    // ignore: unawaited_futures
    router.open(const HomeRoute());
    await tester.pumpAndSettle();
    expect(identical(router.navigatorKey, key), isTrue);
    // ignore: unawaited_futures
    openDialog(router);
    await tester.pumpAndSettle();
    expect(find.text('global dialog'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
