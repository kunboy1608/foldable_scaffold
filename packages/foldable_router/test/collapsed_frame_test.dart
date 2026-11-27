import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

/// A layout that keeps both frames placed but collapses the primary one to
/// zero width, the way `FoldableScaffold` does in one pane when it shows only
/// the secondary body. Its own chrome (a bar at the bottom) sits outside both
/// frames.
class CollapsedShell extends FoldableShellRoute {
  const CollapsedShell();

  @override
  List<FoldableShellChildRoute> get branches => const [ListRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    Widget content = Row(
      children: <Widget>[
        if (panes.hasSecondary)
          SizedBox(width: 0, child: panes.primary)
        else
          // The left of the lone pane follows [paneLeft] without the area
          // rebuilding or the frame changing size: only an offset moves.
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: paneLeft,
              builder: (context, left, child) => Stack(
                children: <Widget>[
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: 400,
                    child: child!,
                  ),
                ],
              ),
              child: panes.primary,
            ),
          ),
        if (panes.hasSecondary) Expanded(child: panes.secondary),
      ],
    );
    // Declared like a FoldableScaffold does: one pane visible at a time.
    if (declarePanes) {
      content = FoldablePaneLayout(
        primaryVisible: !panes.hasSecondary,
        secondaryVisible: panes.hasSecondary,
        child: content,
      );
    }
    return Column(
      children: <Widget>[
        Expanded(child: content),
        SizedBox(
          height: 80,
          width: double.infinity,
          child: TextButton(
            key: const Key('chrome'),
            onPressed: () => chromeTaps++,
            child: const Text('chrome'),
          ),
        ),
      ],
    );
  }
}

int chromeTaps = 0;

/// A layout whose lone pane (x 100 to 200) clips a frame of 300 aligned on its
/// right edge, like a pane of a FoldableScaffold sliding out to the left under
/// a navigation rail: the frame reaches x -100, over the chrome.
class ClippedShell extends FoldableShellRoute {
  const ClippedShell();

  @override
  List<FoldableShellChildRoute> get branches => const [ClippedRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) => Stack(
    children: <Widget>[
      Positioned.fill(
        child: TextButton(
          key: const Key('chrome'),
          onPressed: () => chromeTaps++,
          child: const Text('chrome'),
        ),
      ),
      Positioned(
        left: 100,
        top: 0,
        bottom: 0,
        width: 100,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerRight,
            minWidth: 300,
            maxWidth: 300,
            child: panes.primary,
          ),
        ),
      ),
    ],
  );
}

class ClippedRoute extends FoldableShellChildRoute {
  const ClippedRoute();

  @override
  String get segment => 'clipped';

  @override
  FoldableShellParent get parent => const ClippedShell();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('page clipped'),
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pageTaps++,
    ),
  );
}

int pageTaps = 0;

/// Whether the layout declares its panes ([FoldablePaneLayout]).
bool declarePanes = false;

/// The left of the lone pane, in the tab area.
final ValueNotifier<double> paneLeft = ValueNotifier<double>(0);

class ListRoute extends FoldableShellChildRoute {
  const ListRoute();

  @override
  String get segment => 'list';

  @override
  FoldableShellParent get parent => const CollapsedShell();

  @override
  Widget build(BuildContext context) => const _Page(label: 'list');
}

class DetailRoute extends FoldableShellChildRoute {
  const DetailRoute();

  @override
  String get segment => 'detail';

  @override
  FoldableShellParent get parent => const ListRoute();

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
  setUp(() {
    chromeTaps = 0;
    pageTaps = 0;
    declarePanes = false;
    paneLeft.value = 0;
  });

  Future<FoldableRouter> pumpRouter(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final router = FoldableRouter(
      initial: const CollapsedShell(),
      routes: <String, FoldableRouteFactory>{
        '/list': (params) => const ListRoute(),
        '/list/detail': (params) => const DetailRoute(),
      },
      notFoundBuilder: (context, uri) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a page in a collapsed frame is hidden and does not cover the '
      'chrome', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    final router = FoldableRouter(
      initial: const CollapsedShell(),
      routes: <String, FoldableRouteFactory>{
        '/list': (params) => const ListRoute(),
        '/list/detail': (params) => const DetailRoute(),
      },
      notFoundBuilder: (context, uri) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('chrome')));
    expect(chromeTaps, 1);

    await router.open(const DetailRoute());
    await tester.pumpAndSettle();

    // The detail fills its frame; the list, in the collapsed frame, is not
    // spread over the whole area.
    expect(
      tester.getRect(find.byKey(const Key('page detail'))),
      const Rect.fromLTRB(0, 0, 400, 720),
    );
    expect(find.byKey(const Key('page list')), findsNothing);
    expect(
      find.byKey(const Key('page list'), skipOffstage: false),
      findsOneWidget,
    );

    // The chrome below the frames still takes its taps.
    await tester.tap(find.byKey(const Key('chrome')));
    expect(chromeTaps, 2);

    // Back to one page: the list comes back in its frame.
    router.pop();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('page list'))),
      const Rect.fromLTRB(0, 0, 400, 720),
    );
  });

  testWidgets('one pane declared by the layout: the pages stay in their '
      'frames, before and after the window changes', (
    WidgetTester tester,
  ) async {
    declarePanes = true;
    final router = await pumpRouter(tester);
    final listRect = find.byKey(const Key('page list'));
    expect(tester.getRect(listRect), const Rect.fromLTRB(0, 0, 400, 720));

    // A size change rebuilds the area with the facts the layout reported:
    // one pane visible. The page must not spread over the chrome.
    tester.view.physicalSize = const Size(400, 700);
    await tester.pumpAndSettle();
    expect(tester.getRect(listRect), const Rect.fromLTRB(0, 0, 400, 620));
    expect(
      FoldableRouter.paneOf(tester.element(listRect)),
      FoldablePane.single,
    );
    await tester.tap(find.byKey(const Key('chrome')));
    expect(chromeTaps, 1);

    await router.open(const DetailRoute());
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('page detail'))),
      const Rect.fromLTRB(0, 0, 400, 620),
    );
    expect(find.byKey(const Key('page list')), findsNothing);
    await tester.tap(find.byKey(const Key('chrome')));
    expect(chromeTaps, 2);
  });

  testWidgets('a frame moved by an ancestor without laying out takes its '
      'page along', (WidgetTester tester) async {
    await pumpRouter(tester);
    final listRect = find.byKey(const Key('page list'));
    expect(tester.getRect(listRect).left, 0);

    paneLeft.value = 50;
    await tester.pumpAndSettle();
    expect(tester.getRect(listRect), const Rect.fromLTRB(50, 0, 450, 720));

    paneLeft.value = 0;
    await tester.pumpAndSettle();
    expect(tester.getRect(listRect), const Rect.fromLTRB(0, 0, 400, 720));
  });

  testWidgets('a page is cut to the visible part of its frame', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final router = FoldableRouter(
      initial: const ClippedShell(),
      routes: <String, FoldableRouteFactory>{
        '/clipped': (params) => const ClippedRoute(),
      },
      notFoundBuilder: (context, uri) => const SizedBox.shrink(),
    );
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router.routerConfig),
    );
    await tester.pumpAndSettle();

    // Laid out on the whole frame, not squeezed into what is visible.
    expect(
      tester.getRect(find.byKey(const Key('page clipped'))),
      const Rect.fromLTRB(-100, 0, 200, 800),
    );
    // Inside the visible part the page takes the tap; outside it, the chrome
    // below does, although the frame reaches there.
    await tester.tapAt(const Offset(150, 400));
    expect(pageTaps, 1);
    expect(chromeTaps, 0);
    await tester.tapAt(const Offset(50, 400));
    expect(chromeTaps, 1);
    expect(pageTaps, 1);
  });
}
