// PROTOTYPE ONLY. Uses the real FoldableRouter and FoldableScaffold, without
// changing router lib. buildPanes still returns measurement frames; this
// validates the fallback of hosting those frames in scaffold slots, not literal
// FoldablePaneTree widgets that are the pages themselves.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
// `FoldablePane` exists in both packages today (router's own enum and core's),
// so hide the scaffold's to use the router's (what `FoldableRouter.paneOf`
// returns). The report's plan has the router re-export the core enum to remove
// this clash — a real finding this prototype surfaces.
import 'package:foldable_scaffold/foldable_scaffold.dart' hide FoldablePane;

const _breakpoints = FoldableBreakpoints(rail: 100000, split: 840);
const _wide = Size(1200, 800);

class ProtoShell extends FoldableShellRoute {
  const ProtoShell();
  @override
  List<FoldableShellChildRoute> get branches => const [UsersRoot(), HomeRoot()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      shell.child;
  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (!_breakpoints.canSplit(
      panes.constraints.maxWidth,
      MediaQuery.sizeOf(context),
    )) {
      return null;
    }
    // Plain Row of frames: the mechanism the two_pane_test already exercises.
    // This is what isolates the *state/slot/mounted/back* answers below.
    return Row(
      children: [
        Expanded(flex: 2, child: panes.primary),
        const SizedBox(width: 1),
        Expanded(
          flex: 3,
          child: panes.hasSecondary
              ? panes.secondary
              : const Center(child: Text('empty')),
        ),
      ],
    );
  }
}

/// Same tab shape, but the frames are dropped into a *real* FoldableScaffold.
/// Only used to demonstrate the layout-protocol crash (the blocker).
class ScaffoldShell extends FoldableShellRoute {
  const ScaffoldShell();
  @override
  List<FoldableShellChildRoute> get branches => const [ScaffoldRoot()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      FoldableScaffold(
        key: const Key('real-scaffold-shell'),
        breakpoints: _breakpoints,
        followFold: false,
        avoidCutouts: false,
        paneAnimationDuration: const Duration(milliseconds: 250),
        appBar: AppBar(title: const Text('scaffold host')),
        navigationBuilder: (_, _, _, _) => const SizedBox.shrink(),
        body: const SizedBox.shrink(key: Key('scaffold-body-placeholder')),
        secondaryBody: const SizedBox.shrink(
          key: Key('scaffold-secondary-placeholder'),
        ),
        hasSecondaryBody: shell.hasSecondary,
        paneContent: (_, _) => shell.child,
        onSecondBodyClose: (_, _) => FoldableRouter.of(context).pop(),
      );
}

class ScaffoldRoot extends FoldableShellChildRoute {
  const ScaffoldRoot();
  @override
  String get segment => 'hosted';
  @override
  FoldableShellParent get parent => const ScaffoldShell();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('hosted root')),
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          key: const Key('hosted-push'),
          onPressed: () =>
              FoldableRouter.of(context).open(const ScaffoldDetail()),
          child: const Text('push detail'),
        ),
      ),
    ),
  );
}

class ScaffoldDetail extends FoldableShellChildRoute {
  const ScaffoldDetail();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const ScaffoldRoot();
  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('hosted detail'),
    appBar: AppBar(title: const Text('detail')),
    body: const Center(child: Text('hosted detail')),
  );
}

class UsersRoot extends FoldableShellChildRoute {
  const UsersRoot();
  @override
  String get segment => 'users';
  @override
  FoldableShellParent get parent => const ProtoShell();
  @override
  Widget build(BuildContext context) =>
      const StatePage(key: Key('users'), title: 'users');
}

class HomeRoot extends FoldableShellChildRoute {
  const HomeRoot();
  @override
  String get segment => '';
  @override
  FoldableShellParent get parent => const ProtoShell();
  @override
  Widget build(BuildContext context) => const Material(child: Text('home'));
}

class UserRoute extends FoldableShellChildRoute {
  const UserRoute();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const UsersRoot();
  @override
  Widget build(BuildContext context) =>
      const StatePage(key: Key('user'), title: 'user');
}

class DeepRoute extends FoldableShellChildRoute {
  const DeepRoute();
  @override
  String get segment => 'deep';
  @override
  FoldableShellParent get parent => const UserRoute();
  @override
  Widget build(BuildContext context) =>
      const Material(key: Key('deep'), child: Text('deep'));
}

class StatePage extends StatefulWidget {
  const StatePage({super.key, required this.title});
  final String title;
  @override
  StatePageState createState() => StatePageState();
}

class StatePageState extends State<StatePage> {
  int count = 0;
  final text = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Key('page-${widget.title}'),
    appBar: AppBar(title: Text(widget.title)),
    body: Column(
      children: [
        Text('${widget.title} count $count'),
        TextButton(
          key: Key('increment-${widget.title}'),
          onPressed: () => setState(() => count++),
          child: const Text('+'),
        ),
        TextField(key: Key('text-${widget.title}'), controller: text),
        TextButton(
          key: Key('push-${widget.title}'),
          onPressed: () {
            if (widget.title == 'users') {
              FoldableRouter.of(context).open(const UserRoute());
            } else {
              FoldableRouter.of(context).open(const DeepRoute());
            }
          },
          child: const Text('push'),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: 40,
            itemBuilder: (_, i) => SizedBox(height: 40, child: Text('item $i')),
          ),
        ),
      ],
    ),
  );
}

FoldableRouter _createRouter() {
  final router = FoldableRouter(
    initial: const ProtoShell(),
    routes: {
      '/users': (_) => const UsersRoot(),
      '/users/detail': (_) => const UserRoute(),
      '/users/detail/deep': (_) => const DeepRoute(),
    },
    notFoundBuilder: (_, uri) => Text('not found: $uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> _pumpPlain(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _createRouter();
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

// Wide (1200 >= split 840): the plain-Row prototype reports two panes.
// Narrow (500): one pane. Surfaces are defined at top of file (_wide, _narrow).
const Size _narrow = Size(500, 800);

FoldablePane _pane(WidgetTester tester, String key) =>
    FoldableRouter.paneOf(tester.element(find.byKey(Key(key))));

void main() {
  testWidgets('[a] counter, TextField and scroll survive push then pop', (
    tester,
  ) async {
    final router = await _pumpPlain(tester, _wide);
    final state = tester.state<StatePageState>(find.byKey(const Key('users')));
    await tester.tap(find.byKey(const Key('increment-users')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-users')), 'draft');
    await tester.pump();
    state.scroll.jumpTo(120);
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-users')));
    await tester.pumpAndSettle();
    expect(router.stack.last, const UserRoute());
    router.pop();
    await tester.pumpAndSettle();
    expect(
      identical(
        tester.state<StatePageState>(find.byKey(const Key('users'))),
        state,
      ),
      isTrue,
    );
    expect(find.text('users count 1'), findsOneWidget);
    expect(find.text('draft'), findsOneWidget);
    expect(state.scroll.offset, 120);
  });

  testWidgets('[b] secondary -> primary keeps page State and inputs', (
    tester,
  ) async {
    final router = await _pumpPlain(tester, _wide);
    await tester.tap(find.byKey(const Key('push-users')));
    await tester.pumpAndSettle();
    expect(_pane(tester, 'page-user'), FoldablePane.secondary);
    final state = tester.state<StatePageState>(find.byKey(const Key('user')));
    final Rect secondary = tester.getRect(find.byKey(const Key('page-user')));
    await tester.enterText(find.byKey(const Key('text-user')), 'detail');
    await tester.pump();
    state.scroll.jumpTo(80);
    await tester.pump();

    await tester.tap(find.byKey(const Key('push-user')));
    await tester.pumpAndSettle();
    expect(router.stack.last, const DeepRoute());
    expect(_pane(tester, 'page-user'), FoldablePane.primary);
    expect(
      identical(
        tester.state<StatePageState>(find.byKey(const Key('user'))),
        state,
      ),
      isTrue,
    );
    expect(find.text('detail'), findsOneWidget);
    expect(state.scroll.offset, 80);
    expect(
      tester.getRect(find.byKey(const Key('page-user'))).left,
      lessThan(secondary.left),
    );
  });

  testWidgets('[c] the hidden deeper page stays mounted', (tester) async {
    await _pumpPlain(tester, _wide);
    await tester.tap(find.byKey(const Key('push-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-user')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-users')), findsNothing);
    expect(
      find.byKey(const Key('page-users'), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byKey(const Key('text-users')).hitTestable(), findsNothing);
  });

  testWidgets('[d] system back pops the top route in order', (tester) async {
    final router = await _pumpPlain(tester, _wide);
    await tester.tap(find.byKey(const Key('push-users')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-user')));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.stack.last, const UserRoute());
    expect(_pane(tester, 'page-user'), FoldablePane.secondary);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.stack, [const ProtoShell(), const UsersRoot()]);
  });

  testWidgets('one pane (narrow): State survives push/pop too', (tester) async {
    final router = await _pumpPlain(tester, _narrow);
    final state = tester.state<StatePageState>(find.byKey(const Key('users')));
    await tester.tap(find.byKey(const Key('increment-users')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-users')));
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    expect(
      identical(
        tester.state<StatePageState>(find.byKey(const Key('users'))),
        state,
      ),
      isTrue,
    );
    expect(find.text('users count 1'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // The headline finding: real router + real FoldableScaffold, with rects
  // passed as data. The old measurement crash must not occur.
  // -------------------------------------------------------------------------
  testWidgets('[blocker resolved] real scaffold uses pane rects as data', (
    tester,
  ) async {
    tester.view.physicalSize = _wide;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    final router = FoldableRouter(
      initial: const ScaffoldShell(),
      routes: {'/hosted': (_) => const ScaffoldRoot()},
      notFoundBuilder: (_, uri) => Text('not found: $uri'),
    );
    addTearDown(router.dispose);
    try {
      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router.routerConfig),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('hosted-push')));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previous;
      while (tester.takeException() != null) {}
    }

    expect(
      errors.where(
        (e) => e.exception.toString().contains(
          '_RenderPaneSlot was mutated in _RenderPaneFrame.performLayout',
        ),
      ),
      isEmpty,
    );
    expect(find.byKey(const Key('hosted detail')), findsOneWidget);
    expect(find.byKey(const Key('pane_divider')), findsOneWidget);

    // Both values come from the same render tree after the same pump: the
    // route page is positioned by the rect scope and the divider is positioned
    // by the scaffold's animated geometry.
    final Rect page = tester.getRect(find.byKey(const Key('hosted detail')));
    final Rect primary = tester.getRect(
      find.byKey(const Key('scaffold-body-placeholder')),
    );
    expect(page, isNot(primary));
    expect(page.width, greaterThan(0));
    expect(page.height, greaterThan(0));
  });
}
