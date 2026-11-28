import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A layout that declares its panes the way `FoldableScaffold` does: with one
/// page only the primary pane is visible, so the tab is one pane when the
/// second page is pushed and turns into two panes only a frame later, once
/// the layout shows the secondary body.
class _Shell extends FoldableShellRoute {
  const _Shell();

  @override
  List<FoldableShellChildRoute> get branches => const [_ListRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    return FoldablePaneLayout(
      primaryVisible: true,
      secondaryVisible: panes.hasSecondary,
      child: Row(
        children: <Widget>[
          Expanded(child: panes.primary),
          if (panes.hasSecondary) Expanded(child: panes.secondary),
        ],
      ),
    );
  }
}

class _ListRoute extends FoldableShellChildRoute {
  const _ListRoute();

  @override
  String get segment => 'list';

  @override
  FoldableShellParent get parent => const _Shell();

  @override
  Widget build(BuildContext context) => const _Page(label: 'list');
}

class _DetailRoute extends FoldableShellChildRoute {
  const _DetailRoute();

  @override
  String get segment => 'detail';

  @override
  FoldableShellParent get parent => const _ListRoute();

  @override
  Widget build(BuildContext context) => const _Page(label: 'detail');
}

class _Page extends StatelessWidget {
  const _Page({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: Key('page $label'),
    body: Center(child: Text(label)),
  );
}

void main() {
  testWidgets('a page pushed while the tab is one pane does not leave the '
      'page below shifted once the tab turns into two panes', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 600);
    addTearDown(tester.view.reset);

    final router = FoldableRouter(
      initial: const _Shell(),
      routes: <String, FoldableRouteFactory>{
        '/list': (params) => const _ListRoute(),
        '/list/detail': (params) => const _DetailRoute(),
      },
      notFoundBuilder: (context, uri) => const SizedBox.shrink(),
      // Its delegated transition slides the page below by a third of the
      // area: the shift that stayed on the left pane.
      pageTransitions: (context) => const CupertinoPageTransitionsBuilder(),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pumpAndSettle();

    final list = find.byKey(const Key('page list'));
    // One page: the lone pane takes the whole area.
    expect(tester.getRect(list), const Rect.fromLTRB(0, 0, 900, 600));

    await router.open(const _DetailRoute());
    await tester.pumpAndSettle();

    // Two panes: the list stays in the left pane, not 300 to its left.
    expect(tester.getRect(list), const Rect.fromLTRB(0, 0, 450, 600));
    expect(
      tester.getRect(find.byKey(const Key('page detail'))),
      const Rect.fromLTRB(450, 0, 900, 600),
    );
    // The left pane is painted where it is laid out: its centre shows the
    // list, and the detail is in the right pane.
    expect(tester.getCenter(find.text('list')), const Offset(225, 300));
    expect(tester.getCenter(find.text('detail')), const Offset(675, 300));

    // Back to one page: the list fills the area again, unshifted.
    router.pop();
    await tester.pumpAndSettle();
    expect(tester.getRect(list), const Rect.fromLTRB(0, 0, 900, 600));
    expect(tester.getCenter(find.text('list')), const Offset(450, 300));
    expect(tester.takeException(), isNull);
  });
}
