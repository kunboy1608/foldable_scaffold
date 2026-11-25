import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart' hide FoldablePane;

const _breakpoints = FoldableBreakpoints(rail: 100000, split: 840);
const Size _wide = Size(1200, 800);
const Size _mid = Size(1000, 800);
const Size _narrow = Size(500, 800);
int _hostBuilds = 0;

class ProbePage extends StatefulWidget {
  const ProbePage({super.key, required this.label, this.next});
  final String label;
  final FoldableRoute? next;
  @override
  State<ProbePage> createState() => ProbePageState();
}

class ProbePageState extends State<ProbePage> {
  int count = 0;
  final text = TextEditingController();
  final scroll = ScrollController();
  FoldablePane? pane;
  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    pane = FoldableRouter.paneOf(context);
    return Scaffold(
      key: Key('page-${widget.label}'),
      appBar: AppBar(title: Text(widget.label)),
      body: Column(
        children: [
          Text('${widget.label} count $count'),
          TextButton(
            key: Key('inc-${widget.label}'),
            onPressed: () => setState(() => count++),
            child: const Text('+'),
          ),
          TextField(key: Key('text-${widget.label}'), controller: text),
          if (widget.next != null)
            TextButton(
              key: Key('push-${widget.label}'),
              onPressed: () => FoldableRouter.of(context).open(widget.next!),
              child: const Text('push'),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: 60,
              itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$i')),
            ),
          ),
        ],
      ),
    );
  }
}

class Shell extends FoldableShellRoute {
  const Shell();
  @override
  List<FoldableShellChildRoute> get branches => const [Root(), Other()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      FoldableScaffold(
        key: const Key('foldable-scaffold'),
        breakpoints: _breakpoints,
        followFold: false,
        avoidCutouts: false,
        paneAnimationDuration: const Duration(milliseconds: 250),
        appBar: AppBar(title: const Text('shell')),
        navigationBuilder: (_, _, _, _) => const SizedBox.shrink(),
        // paneContent covers the panes itself: no placeholder bodies.
        hasSecondaryBody: shell.hasSecondary,
        paneContent: (_, rects) {
          _hostBuilds++;
          return shell.child;
        },
      );
}

class Root extends FoldableShellChildRoute {
  const Root();
  @override
  String get segment => 'root';
  @override
  FoldableShellParent get parent => const Shell();
  @override
  Widget build(BuildContext context) =>
      const ProbePage(label: 'root', next: Detail());
}

class Detail extends FoldableShellChildRoute {
  const Detail();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const Root();
  @override
  Widget build(BuildContext context) =>
      const ProbePage(label: 'detail', next: Deep());
}

class Deep extends FoldableShellChildRoute {
  const Deep();
  @override
  String get segment => 'deep';
  @override
  FoldableShellParent get parent => const Detail();
  @override
  Widget build(BuildContext context) =>
      const Material(key: Key('deep-page'), child: Text('deep'));
}

class Other extends FoldableShellChildRoute {
  const Other();
  @override
  String get segment => '';
  @override
  FoldableShellParent get parent => const Shell();
  @override
  Widget build(BuildContext context) => const Material(child: Text('other'));
}

class SoloShell extends FoldableShellRoute {
  const SoloShell();
  @override
  List<FoldableShellChildRoute> get branches => const [SoloRoot()];
  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final rects = shell.hasSecondary
            ? FoldablePaneRects(
                primary: Rect.fromLTWH(0, 0, size.width * .4, size.height),
                secondary: Rect.fromLTWH(
                  size.width * .4 + 24,
                  0,
                  size.width * .6 - 24,
                  size.height,
                ),
                axis: Axis.horizontal,
              )
            : FoldablePaneRects(
                primary: Offset.zero & size,
                secondary: null,
                axis: Axis.horizontal,
              );
        return FoldablePaneRectsScope(rects: rects, child: shell.child);
      },
    ),
  );
}

class SoloRoot extends FoldableShellChildRoute {
  const SoloRoot();
  @override
  String get segment => 'solo';
  @override
  FoldableShellParent get parent => const SoloShell();
  @override
  Widget build(BuildContext context) =>
      const ProbePage(label: 'solo', next: SoloDetail());
}

class SoloDetail extends FoldableShellChildRoute {
  const SoloDetail();
  @override
  String get segment => 'detail';
  @override
  FoldableShellParent get parent => const SoloRoot();
  @override
  Widget build(BuildContext context) => const ProbePage(label: 'solo-detail');
}

FoldableRouter _make(FoldableRoute initial, Map<String, FoldableRoute> routes) {
  final router = FoldableRouter(
    initial: initial,
    routes: {for (final e in routes.entries) e.key: (_) => e.value},
    notFoundBuilder: (_, uri) => Text('$uri'),
  );
  addTearDown(router.dispose);
  return router;
}

Future<FoldableRouter> _pump(
  WidgetTester tester,
  FoldableRoute initial,
  Map<String, FoldableRoute> routes,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = _make(initial, routes);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

/// The rectangles the scaffold published around the pane content this frame.
FoldablePaneRects? _hostRects(WidgetTester tester) {
  final scope = tester.firstElement(find.byType(FoldablePaneRectsScope));
  return (scope.widget as FoldablePaneRectsScope).rects;
}

void _expectRects(WidgetTester tester) {
  final rects = _hostRects(tester);
  expect(rects, isNotNull);
  final primary = rects!.primary!;
  final secondary = rects.secondary;
  // The rects are in pane-area coordinates; the page rects are global. Put the
  // pane-area origin back from the primary page, then compare rectangles.
  final origin =
      tester.getRect(find.byKey(const Key('page-root'))).topLeft -
      primary.topLeft;
  Rect at(Rect r) =>
      Rect.fromLTWH(origin.dx + r.left, origin.dy + r.top, r.width, r.height);
  expect(tester.getRect(find.byKey(const Key('page-root'))), at(primary));
  final detail = find.byKey(const Key('page-detail'));
  // A lone visible page occupies the primary pane; in a split, detail is on
  // the secondary pane.
  expect(
    tester.getRect(detail),
    secondary != null ? at(secondary) : at(primary),
  );
}

void main() {
  setUp(() {
    _hostBuilds = 0;
  });

  testWidgets(
    '[a] real router and scaffold survive width changes and divider drag',
    (tester) async {
      final router = await _pump(tester, const Shell(), {
        '/root': const Root(),
        '/root/detail': const Detail(),
      }, _wide);
      await tester.tap(find.byKey(const Key('push-root')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pane_divider')), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('pane_divider')),
        const Offset(-60, 0),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = _narrow;
      await tester.pumpAndSettle();
      tester.view.physicalSize = _wide;
      await tester.pumpAndSettle();
      expect(router.stack.last, const Detail());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '[b] page rectangles equal scaffold panes after each animation and drag pump',
    (tester) async {
      await _pump(tester, const Shell(), {
        '/root': const Root(),
        '/root/detail': const Detail(),
      }, _wide);
      await tester.tap(find.byKey(const Key('push-root')));
      await tester.pumpAndSettle();
      _expectRects(tester);
      tester.view.physicalSize = _mid;
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        _expectRects(tester);
      }
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('pane_divider'))),
      );
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(-20, 0));
        await tester.pump();
        _expectRects(tester);
      }
      await gesture.up();
      await tester.pumpAndSettle();
      _expectRects(tester);
    },
  );

  testWidgets(
    '[c] counter, text, scroll and mounted hidden slot survive push/pop and slot move',
    (tester) async {
      final router = await _pump(tester, const Shell(), {
        '/root': const Root(),
        '/root/detail': const Detail(),
        '/root/detail/deep': const Deep(),
      }, _wide);
      final root = tester.state<ProbePageState>(find.byType(ProbePage).first);
      await tester.tap(find.byKey(const Key('inc-root')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('text-root')), 'root text');
      await tester.pump();
      root.scroll.jumpTo(100);
      await tester.pump();
      await tester.tap(find.byKey(const Key('push-root')));
      await tester.pumpAndSettle();
      final detail = tester.state<ProbePageState>(find.byType(ProbePage).last);
      expect(detail.pane, FoldablePane.secondary);
      await tester.enterText(
        find.byKey(const Key('text-detail')),
        'detail text',
      );
      await tester.pump();
      detail.scroll.jumpTo(80);
      await tester.pump();
      await tester.tap(find.byKey(const Key('push-detail')));
      await tester.pumpAndSettle();
      expect(detail.pane, FoldablePane.primary);
      expect(find.byKey(const Key('page-root')), findsNothing);
      expect(
        find.byKey(const Key('page-root'), skipOffstage: false),
        findsOneWidget,
      );
      expect(
        identical(
          tester.state<ProbePageState>(find.byType(ProbePage).last),
          detail,
        ),
        isTrue,
      );
      expect(find.text('detail text'), findsOneWidget);
      expect(detail.scroll.offset, 80);
      router.pop();
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.state<ProbePageState>(find.byType(ProbePage).first),
          root,
        ),
        isTrue,
      );
      expect(find.text('root count 1'), findsOneWidget);
      expect(find.text('root text'), findsOneWidget);
      expect(root.scroll.offset, 100);
    },
  );

  testWidgets('[d] narrow shows secondary only and keeps primary mounted', (
    tester,
  ) async {
    final router = await _pump(tester, const Shell(), {
      '/root': const Root(),
      '/root/detail': const Detail(),
    }, _narrow);
    final root = tester.state<ProbePageState>(find.byType(ProbePage).first);
    await tester.tap(find.byKey(const Key('inc-root')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-root')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page-detail')), findsOneWidget);
    expect(find.byKey(const Key('page-root')), findsNothing);
    expect(
      find.byKey(const Key('page-root'), skipOffstage: false),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      identical(
        tester.state<ProbePageState>(find.byType(ProbePage).first),
        root,
      ),
      isTrue,
    );
    expect(find.text('root count 1'), findsOneWidget);
    expect(router.stack.last, const Root());
  });

  testWidgets('[e] back/pop and Hero remain safe', (tester) async {
    final router = await _pump(tester, const Shell(), {
      '/root': const Root(),
      '/root/detail': const Detail(),
      '/root/detail/deep': const Deep(),
    }, _wide);
    await tester.tap(find.byKey(const Key('push-root')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('push-detail')));
    await tester.pumpAndSettle();
    expect(router.stack.last, const Deep());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.stack.last, const Detail());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.stack.last, const Root());
    expect(tester.takeException(), isNull);
  });

  testWidgets('[f] standalone router computes rects and survives push/back', (
    tester,
  ) async {
    final router = await _pump(tester, const SoloShell(), {
      '/solo': const SoloRoot(),
      '/solo/detail': const SoloDetail(),
    }, _wide);
    final solo = tester.state<ProbePageState>(find.byType(ProbePage).first);
    await tester.tap(find.byKey(const Key('inc-solo')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('text-solo')), 'kept');
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-solo')));
    await tester.pumpAndSettle();
    expect(router.stack.last, const SoloDetail());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      identical(
        tester.state<ProbePageState>(
          find.byType(ProbePage, skipOffstage: false).first,
        ),
        solo,
      ),
      isTrue,
    );
    expect(find.text('kept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('[count] pose and divider drag build counts stay bounded', (
    tester,
  ) async {
    await _pump(tester, const Shell(), {
      '/root': const Root(),
      '/root/detail': const Detail(),
    }, _wide);
    await tester.tap(find.byKey(const Key('push-root')));
    await tester.pumpAndSettle();
    _hostBuilds = 0;
    tester.view.physicalSize = _mid;
    await tester.pumpAndSettle();
    final poseBuilds = _hostBuilds;
    _hostBuilds = 0;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('pane_divider'))),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-15, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    final dragBuilds = _hostBuilds;
    debugPrint('[count] pose=$poseBuilds drag=$dragBuilds');
    expect(poseBuilds, lessThan(120));
    expect(dragBuilds, lessThan(60));
  });
}
