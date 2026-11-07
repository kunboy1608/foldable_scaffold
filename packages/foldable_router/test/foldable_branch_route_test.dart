import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

class _Tab extends BranchRoute {
  const _Tab(this.path, {this.hide = true, this.auto = false});

  @override
  final String path;

  final bool hide;

  /// An app bar without leading: Flutter adds the back button by itself.
  final bool auto;

  @override
  bool get hideBackButton => hide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: auto ? null : const FoldableBackButton(),
        title: Text('tab $path'),
      ),
    );
  }
}

class _Page extends FoldableRoute {
  const _Page();

  @override
  String get path => '/page';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const FoldableBackButton(),
        title: const Text('page'),
      ),
    );
  }
}

class _FoldableBarTab extends BranchRoute {
  const _FoldableBarTab(this.path);

  @override
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: FoldableAppBar(title: Text('bar $path')));
  }
}

class _AppBarPage extends FoldableRoute {
  const _AppBarPage();

  @override
  String get path => '/bar-page';

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: FoldableAppBar(title: const Text('pushed')));
  }
}

Future<FoldableRouter> _pump(WidgetTester tester, BranchRoute tab) async {
  final router = FoldableRouter.branches(branches: [tab]);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp(home: FoldableNavigator.stack(controller: router.controller)),
  );
  router.controller.push(const _Page().toPage<void>());
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('the page of a BranchRoute never shows a back button', (
    tester,
  ) async {
    final router = await _pump(tester, const _Tab('/tab'));
    expect(router.canPop, isTrue);

    // Only the pushed page has one.
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('FoldableAppBar leaves out the back button of a branch root', (
    tester,
  ) async {
    Future<void> pump(BranchRoute tab) async {
      final router = FoldableRouter.branches(branches: [tab]);
      addTearDown(router.dispose);
      router.controller.push(const _AppBarPage().toPage<void>());
      await tester.pumpWidget(
        MaterialApp(
          home: FoldableNavigator(
            controller: router.controller,
            builder: (context, body, secondary) => Row(
              children: [
                Expanded(child: body),
                Expanded(child: secondary ?? const SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(const _FoldableBarTab('/tab'));

    final inRoot = find.descendant(
      of: find.ancestor(
        of: find.text('bar /tab'),
        matching: find.byType(Scaffold),
      ),
      matching: find.byType(BackButton),
    );
    // No button, and no room taken by one: the title starts at the edge.
    expect(inRoot, findsNothing);
    final title = tester.getTopLeft(find.text('bar /tab')).dx;
    final scaffold = tester.getTopLeft(
      find.ancestor(of: find.text('bar /tab'), matching: find.byType(Scaffold)),
    );
    expect(title - scaffold.dx, lessThan(40));

    // The pushed page keeps Flutter's automatic back button.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a BranchRoute can keep its back button', (tester) async {
    final stack = FoldableRouter.branches(
      branches: const [_Tab('/tab', hide: false)],
    );
    addTearDown(stack.dispose);
    stack.controller.push(const _Page().toPage<void>());
    // Back on the root page: shown, because the stack can pop.
    await tester.pumpWidget(
      MaterialApp(
        home: FoldableNavigator(
          controller: stack.controller,
          builder: (context, body, secondary) => Row(
            children: [
              Expanded(child: body),
              Expanded(child: secondary ?? const SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNWidgets(2));
  });

  testWidgets('the automatic back icon of a branch root is empty', (
    tester,
  ) async {
    Future<void> pump(BranchRoute tab) async {
      final router = FoldableRouter.branches(branches: [tab]);
      addTearDown(router.dispose);
      router.controller.push(const _Page().toPage<void>());
      await tester.pumpWidget(
        MaterialApp(
          home: FoldableNavigator(
            controller: router.controller,
            builder: (context, body, secondary) => Row(
              children: [
                Expanded(child: body),
                Expanded(child: secondary ?? const SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final iconInRoot = find.descendant(
      of: find.ancestor(
        of: find.text('tab /tab'),
        matching: find.byType(Scaffold),
      ),
      matching: find.byType(Icon),
    );

    // The root shows a back arrow when it keeps the button...
    await pump(const _Tab('/tab', hide: false, auto: true));
    expect(iconInRoot, findsOneWidget);

    // ...and draws nothing when it hides it.
    await pump(const _Tab('/tab', auto: true));
    expect(iconInRoot, findsNothing);
  });
}
