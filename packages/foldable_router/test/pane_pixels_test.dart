import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

import 'pixel_utils.dart';

/// STEP 5 of the two-pane work: prove with *pixels* (not just `getRect`) that a
/// page is drawn where its frame is, in every frame — including the frames the
/// router itself produces while a navigation commits.
///
/// `getRect` reads `applyPaintTransform` after the frame finished painting, so
/// it cannot see a paint that used a stale rectangle. These tests grab the
/// actual rasterized layer and compare regions byte by byte.

// ---------------------------------------------------------------------------
// Test app: a two-branch shell whose A tab is two panes when wide enough.
// ---------------------------------------------------------------------------

final PixelConfig pixelConfig = PixelConfig();

class PixelConfig {
  bool twoPane = true;
  Axis axis = Axis.horizontal;
  int leftFlex = 2;
  int rightFlex = 3;
  double gap = 1;
}

class PixelShell extends FoldableShellRoute {
  const PixelShell();

  @override
  List<FoldableRoute> get branches => const [AListRoute(), BHomeRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) => Scaffold(
    body: shell.child,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.people), label: 'A'),
        NavigationDestination(icon: Icon(Icons.home), label: 'B'),
      ],
    ),
  );

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (!pixelConfig.twoPane) return null;
    if (panes.constraints.maxWidth < 840) return null;
    final Widget primary = KeyedSubtree(
      key: const Key('primary-frame'),
      child: panes.primary,
    );
    // The area of the right pane, always present (even without a second
    // page) so a test can learn the rectangle the top page is drawn in
    // whatever the stack is.
    final Widget right = KeyedSubtree(
      key: const Key('secondary-area'),
      child: panes.hasSecondary
          ? KeyedSubtree(
              key: const Key('secondary-frame'),
              child: panes.secondary,
            )
          : const SizedBox.expand(),
    );
    final Widget gutter = SizedBox(
      width: pixelConfig.axis == Axis.horizontal ? pixelConfig.gap : null,
      height: pixelConfig.axis == Axis.vertical ? pixelConfig.gap : null,
    );
    if (pixelConfig.axis == Axis.horizontal) {
      return Row(
        children: [
          Expanded(flex: pixelConfig.leftFlex, child: primary),
          gutter,
          Expanded(flex: pixelConfig.rightFlex, child: right),
        ],
      );
    }
    return Column(
      children: [
        Expanded(flex: pixelConfig.leftFlex, child: primary),
        gutter,
        Expanded(flex: pixelConfig.rightFlex, child: right),
      ],
    );
  }
}

class AListRoute extends FoldableRoute {
  const AListRoute();
  @override
  String get path => '/a';
  @override
  FoldableRoute? get parent => const PixelShell();
  @override
  Widget build(BuildContext context) => const AListPage();
}

class AItemRoute extends FoldableRoute {
  const AItemRoute({required this.id});
  final String id;
  @override
  String get path => '/a/item';
  @override
  Map<String, String?> get params => {'id': id};
  @override
  FoldableRoute? get parent => const AListRoute();
  @override
  Widget build(BuildContext context) => AItemPage(id: id);
}

/// A third page of the A branch, opened on top of [AItemRoute] (id `1`).
class ASubRoute extends FoldableRoute {
  const ASubRoute({required this.id});
  final String id;
  @override
  String get path => '/a/item/sub';
  @override
  Map<String, String?> get params => {'id': id};
  @override
  FoldableRoute? get parent => const AItemRoute(id: '1');
  @override
  Widget build(BuildContext context) => AItemPage(id: id);
}

class BHomeRoute extends FoldableRoute {
  const BHomeRoute();
  @override
  String get path => '/b';
  @override
  FoldableRoute? get parent => const PixelShell();
  @override
  Widget build(BuildContext context) => const BHomePage();
}

/// The left page of the test shell: static, high-contrast content (an icon
/// and text on a dark green fill) that never changes with the stack, plus a
/// counter used only by the state tests.
class AListPage extends StatefulWidget {
  const AListPage({super.key});
  @override
  State<AListPage> createState() => AListPageState();
}

class AListPageState extends State<AListPage> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Material(
    key: const Key('page a-list'),
    color: const Color(0xFF00AA00),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.list_alt, size: 120, color: Color(0xFF003300)),
          const SizedBox(height: 16),
          const Text(
            'static list',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003300),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'a count $count',
            style: const TextStyle(fontSize: 28, color: Color(0xFF003300)),
          ),
        ],
      ),
    ),
  );
}

class AItemPage extends StatefulWidget {
  const AItemPage({super.key, required this.id});
  final String id;
  @override
  State<AItemPage> createState() => AItemPageState();
}

class AItemPageState extends State<AItemPage> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) => Material(
    key: Key('page a-${widget.id}'),
    color: widget.id == '1'
        ? const Color(0xFF0000FF)
        : const Color(0xFF800080),
    child: Center(
      child: Text(
        'item ${widget.id} count $count',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        ),
      ),
    ),
  );
}

class BHomePage extends StatelessWidget {
  const BHomePage({super.key});
  @override
  Widget build(BuildContext context) => const Material(
    key: Key('page b'),
    color: Color(0xFFFF0000),
    child: SizedBox.expand(),
  );
}

FoldableRouter createRouter() => FoldableRouter(
  initial: const PixelShell(),
  routes: {
    '/a': (_) => const AListRoute(),
    '/a/item': (p) => AItemRoute(id: p['id']!),
    '/b': (_) => const BHomeRoute(),
  },
  notFoundBuilder: (context, uri) => const Text('not found'),
);

// ---------------------------------------------------------------------------
// Test helpers.
// ---------------------------------------------------------------------------

void setSize(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Rect frameRect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key), skipOffstage: false));

Future<FoldableRouter> pumpApp(WidgetTester tester) async {
  final router = createRouter();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rectangle the top page of a two-pane tab is drawn in.
Rect secondaryArea(WidgetTester tester) =>
    frameRect(tester, 'secondary-area');

/// Number of pixels that differ from [other] *outside* [area].
///
/// Splits the screen into the four bands around [area] so the exact count is
/// kept (the areas are disjoint and together cover everything outside it).
int outsideDiff(Screenshot a, Screenshot b, Rect area) {
  final Rect screen = Rect.fromLTWH(
    0,
    0,
    a.width.toDouble(),
    a.height.toDouble(),
  );
  final Rect clip = area.intersect(screen);
  // A pixel that straddles the edge of the pane is *partly* inside it, so it
  // is not required to stay identical (rounding the pane rectangle would
  // otherwise count its own anti-aliased border). Use floor/ceil so only
  // pixels fully outside are compared.
  final double left = clip.left.floorToDouble();
  final double top = clip.top.floorToDouble();
  final double right = clip.right.ceilToDouble();
  final double bottom = clip.bottom.ceilToDouble();
  final List<Rect> bands = <Rect>[
    Rect.fromLTRB(screen.left, screen.top, screen.right, top),
    Rect.fromLTRB(screen.left, bottom, screen.right, screen.bottom),
    Rect.fromLTRB(screen.left, top, left, bottom),
    Rect.fromLTRB(right, top, screen.right, bottom),
  ];
  var total = 0;
  for (final Rect band in bands) {
    if (band.width > 0 && band.height > 0) {
      total += a.diff(b, region: band);
    }
  }
  return total;
}

/// Runs [act], then captures the first frame that follows it and every 16 ms
/// frame, for as long as the transition keeps scheduling frames.
Future<List<Screenshot>> framesAfter(
  WidgetTester tester,
  Future<void> Function() act,
) async {
  await act();
  await tester.pump();
  final List<Screenshot> shots = <Screenshot>[await capture(tester)];
  // Do not stop at the first two identical frames: some transitions have a
  // quiet start (the Zoom scrim only starts at 20% of the animation), and the
  // bug lives in the later frames.
  while (tester.binding.hasScheduledFrame && shots.length < 60) {
    await tester.pump(const Duration(milliseconds: 16));
    shots.add(await capture(tester));
  }
  return shots;
}

/// Every frame produced by [act] must keep every pixel outside the right pane
/// of the two-pane tab identical to the settled image.
Future<void> expectOutsideSecondaryStable(
  WidgetTester tester,
  Future<void> Function() act, {
  required String scenario,
}) async {
  final Rect area = frameRect(tester, 'secondary-area');
  final List<Screenshot> frames = await framesAfter(tester, act);
  await tester.pumpAndSettle();
  final Screenshot settled = await capture(tester);
  var worst = 0;
  var worstFrame = -1;
  for (var i = 0; i < frames.length; i++) {
    final int d = outsideDiff(frames[i], settled, area);
    if (d > worst) {
      worst = d;
      worstFrame = i;
    }
  }
  expect(
    worst,
    0,
    reason: '$scenario: up to $worst pixels painted outside the right pane '
        '(worst frame $worstFrame of ${frames.length})',
  );
}

void main() {
  setUp(() {
    pixelConfig
      ..twoPane = true
      ..axis = Axis.horizontal
      ..leftFlex = 2
      ..rightFlex = 3
      ..gap = 1;
  });

  testWidgets(
    'T1 open() the route already shown in two panes changes no pixel',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();

      final Screenshot before = await capture(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot after = await capture(tester);

      expect(
        after.diff(before),
        0,
        reason: 're-opening the visible route must not repaint anything',
      );
    },
  );

  testWidgets(
    'T2a growing one pane to two matches a direct two-pane build',
    (tester) async {
      // Direct two-pane image at the wide size, same stack.
      setSize(tester, 1400, 900);
      var router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot direct = await capture(tester);

      // Same stack built narrow, then grown to the wide size.
      setSize(tester, 700, 900);
      router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      // One pane while narrow.
      expect(
        find.byKey(const Key('primary-frame'), skipOffstage: false),
        findsNothing,
      );

      setSize(tester, 1400, 900);
      await tester.pumpAndSettle();
      final Screenshot grown = await capture(tester);

      expect(
        grown.diff(direct),
        0,
        reason: 'growing to two panes must equal a direct two-pane build',
      );
    },
  );

  testWidgets(
    'T2b wide -> narrow -> wide matches a direct two-pane build',
    (tester) async {
      setSize(tester, 1400, 900);
      var router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot direct = await capture(tester);

      router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();

      setSize(tester, 700, 900);
      await tester.pumpAndSettle();
      setSize(tester, 1400, 900);
      await tester.pumpAndSettle();
      final Screenshot back = await capture(tester);

      expect(
        back.diff(direct),
        0,
        reason: 'a round trip through the narrow size must land identically',
      );
    },
  );

  testWidgets(
    'T3 replacing the right page leaves the left pane identical every frame '
    'and never paints outside the right frame',
    (tester) async {
      setSize(tester, 1400, 900);
      pixelConfig.gap = 16;
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();

      final Rect left = frameRect(tester, 'primary-frame');
      final Rect right = frameRect(tester, 'secondary-frame');
      final Screenshot before = await capture(tester);
      final double tabHeight =
          tester.getTopLeft(find.byType(NavigationBar)).dy;
      // The gutter between the panes, a pixel away from the frame edges so
      // anti-aliasing of the panes' own borders does not count.
      final Rect gutter = Rect.fromLTRB(
        left.right + 2,
        0,
        right.left - 2,
        tabHeight,
      );

      await router.open(const AItemRoute(id: '42'));
      final List<Screenshot> frames = await captureFrames(tester);

      for (var i = 0; i < frames.length; i++) {
        expect(
          frames[i].diff(before, region: left),
          0,
          reason: 'left pane changed in transition frame $i',
        );
        // No page may spill into the gutter between the two frames.
        expect(
          frames[i].diff(before, region: gutter),
          0,
          reason: 'a page escaped the right frame into the gutter in frame $i',
        );
      }
    },
  );

  testWidgets(
    'T4 pop in two panes: remaining pages sit right on the first frame and '
    'the settled image matches a direct build of the target stack',
    (tester) async {
      setSize(tester, 1400, 900);
      // Direct image of the target stack [shell, list, a-1].
      var router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot direct = await capture(tester);
      final Rect left = frameRect(tester, 'primary-frame');

      // Build [shell, list, a-1, a-sub] and pop back.
      router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await router.open(const ASubRoute(id: '42'));
      await tester.pumpAndSettle();
      expect(router.stack.length, 4);

      router.pop();
      await tester.pump();
      final Screenshot firstFrame = await capture(tester);
      // The left pane is already the direct target's left pane.
      expect(
        firstFrame.diff(direct, region: left),
        0,
        reason: 'the left pane must not move on the first frame after pop',
      );

      await tester.pumpAndSettle();
      final Screenshot settled = await capture(tester);
      expect(
        settled.diff(direct),
        0,
        reason: 'after settling the pop must equal a direct build',
      );
    },
  );

  testWidgets(
    'T4 close(context) in two panes settles to a direct build of the target '
    'stack',
    (tester) async {
      setSize(tester, 1400, 900);
      var router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot direct = await capture(tester);
      final Rect left = frameRect(tester, 'primary-frame');

      router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await router.open(const ASubRoute(id: '42'));
      await tester.pumpAndSettle();

      FoldableRouter.close(
        tester.element(find.byKey(const Key('page a-42'))),
      );
      await tester.pump();
      final Screenshot firstFrame = await capture(tester);
      expect(
        firstFrame.diff(direct, region: left),
        0,
        reason: 'the left pane must not move on the first frame after close',
      );

      await tester.pumpAndSettle();
      final Screenshot settled = await capture(tester);
      expect(
        settled.diff(direct),
        0,
        reason: 'after settling close must equal a direct build',
      );
    },
  );

  testWidgets(
    'T5 switching tabs away and back changes no pixel',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot before = await capture(tester);

      await tapTab(tester, 'B');
      await tapTab(tester, 'A');
      final Screenshot after = await capture(tester);

      expect(
        after.diff(before),
        0,
        reason: 'a tab round trip must land on the identical image',
      );
    },
  );

  testWidgets(
    'T5 a MediaQuery change that does not resize the tab changes no pixel in '
    'the tab area',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();

      final double tabHeight =
          tester.getTopLeft(find.byType(NavigationBar)).dy;
      final Rect tabArea = Rect.fromLTRB(0, 0, 1400, tabHeight);
      final Screenshot before = await capture(tester);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue,
      );
      await tester.pumpAndSettle();

      final Screenshot after = await capture(tester);
      expect(
        after.diff(before, region: tabArea),
        0,
        reason: 'a MediaQuery change must not move or repaint the pages',
      );
    },
  );

  testWidgets(
    'T6 asymmetric 2:3 row with a gap is stable across a superfluous rebuild',
    (tester) async {
      setSize(tester, 1400, 900);
      pixelConfig
        ..leftFlex = 2
        ..rightFlex = 3
        ..gap = 24;
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot before = await capture(tester);

      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      expect((await capture(tester)).diff(before), 0);
    },
  );

  testWidgets(
    'T6 vertical Column layout is stable across a superfluous rebuild',
    (tester) async {
      setSize(tester, 1400, 900);
      pixelConfig
        ..axis = Axis.vertical
        ..leftFlex = 1
        ..rightFlex = 2
        ..gap = 24;
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      final Screenshot before = await capture(tester);

      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      expect((await capture(tester)).diff(before), 0);
    },
  );

  // -------------------------------------------------------------------------
  // Transitions of a two-pane tab paint inside their own pane.
  //
  // The report: on Linux (Zoom, Material) replacing the right page painted a
  // surface scrim over the whole left pane for ~250 ms, because the page
  // transition wrapped the pane frame instead of the other way round. These
  // tests watch every frame and require every pixel outside the right frame
  // to equal the settled image.
  // -------------------------------------------------------------------------

  const TargetPlatformVariant panePlatforms = TargetPlatformVariant(
    <TargetPlatform>{
      TargetPlatform.linux,
      TargetPlatform.android,
      TargetPlatform.iOS,
    },
  );

  testWidgets(
    'P1 [A,B] -> open(B\') never paints outside the right pane',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      await expectOutsideSecondaryStable(
        tester,
        () => router.open(const AItemRoute(id: '42')),
        scenario: '[A,B] -> [A,B\']',
      );
    },
    variant: panePlatforms,
  );

  testWidgets(
    'P2 [A] -> [A,B] never paints outside the right pane',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await tester.pumpAndSettle();
      await expectOutsideSecondaryStable(
        tester,
        () => router.open(const AItemRoute(id: '1')),
        scenario: '[A] -> [A,B]',
      );
    },
    variant: panePlatforms,
  );

  testWidgets(
    'P3 [A,B] -> pop to [A] never paints outside the right pane',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      await expectOutsideSecondaryStable(
        tester,
        () async => router.pop(),
        scenario: '[A,B] -> [A]',
      );
    },
    variant: panePlatforms,
  );

  testWidgets(
    'P4 [A,B] -> [A,B,C] never paints outside the right pane',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await tester.pumpAndSettle();
      await expectOutsideSecondaryStable(
        tester,
        () => router.open(const ASubRoute(id: '42')),
        scenario: '[A,B] -> [A,B,C]',
      );
    },
    variant: panePlatforms,
  );

  testWidgets(
    'P5 [A,B,C] -> pop to [A,B] never paints outside the right pane',
    (tester) async {
      setSize(tester, 1400, 900);
      final router = await pumpApp(tester);
      await router.open(const AItemRoute(id: '1'));
      await router.open(const ASubRoute(id: '42'));
      await tester.pumpAndSettle();
      await expectOutsideSecondaryStable(
        tester,
        () async => router.pop(),
        scenario: '[A,B,C] -> [A,B]',
      );
    },
    variant: panePlatforms,
  );

  // -------------------------------------------------------------------------
  // Page state survives pane moves and mode changes (requirement 3).
  // -------------------------------------------------------------------------

  Finder aItemPage(String id) => find.byWidgetPredicate(
    (Widget widget) => widget is AItemPage && widget.id == id,
    skipOffstage: false,
  );
  AListPageState aListState(WidgetTester tester) => tester
      .state<AListPageState>(find.byType(AListPage, skipOffstage: false));

  AItemPageState aItemState(WidgetTester tester, String id) =>
      tester.state<AItemPageState>(aItemPage(id));

  testWidgets('(a) one <-> two panes keeps the State of the page', (
    tester,
  ) async {
    setSize(tester, 1400, 900);
    await pumpApp(tester);
    await tester.pumpAndSettle();

    final AListPageState state = aListState(tester);
    state.increment();
    await tester.pump();
    expect(find.textContaining('a count 1', skipOffstage: false), findsOneWidget);

    for (final double width in <double>[700, 1400, 700, 1400]) {
      setSize(tester, width, 900);
      await tester.pumpAndSettle();
      expect(
        identical(aListState(tester), state),
        isTrue,
        reason: 'the State must survive a resize to width $width',
      );
      expect(find.textContaining('a count 1', skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('(b) a page pushed into another pane keeps its State', (
    tester,
  ) async {
    setSize(tester, 1400, 900);
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();
    await router.open(const AItemRoute(id: '1'));
    await tester.pumpAndSettle();

    final AListPageState list = aListState(tester);
    final AItemPageState item = aItemState(tester, '1');
    list.increment();
    item.increment();
    await tester.pump();
    expect(find.textContaining('a count 1', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('item 1 count 1', skipOffstage: false), findsOneWidget);

    // Pushing C hides A and moves B from the right pane to the left one.
    await router.open(const ASubRoute(id: '42'));
    await tester.pumpAndSettle();

    expect(
      identical(aListState(tester), list),
      isTrue,
      reason: 'the hidden left page must keep its State',
    );
    expect(
      identical(aItemState(tester, '1'), item),
      isTrue,
      reason: 'the page that changed pane must keep its State',
    );
    expect(find.textContaining('a count 1', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('item 1 count 1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('(c) a page hidden deep in the stack keeps its State', (
    tester,
  ) async {
    setSize(tester, 1400, 900);
    final router = await pumpApp(tester);
    await tester.pumpAndSettle();
    await router.open(const AItemRoute(id: '1'));
    await router.open(const ASubRoute(id: '42'));
    await tester.pumpAndSettle();

    final AListPageState list = aListState(tester);
    final AItemPageState item = aItemState(tester, '1');
    list.increment();
    item.increment();
    await tester.pump();

    // A is hidden under two pages; pop them back one by one.
    router.pop();
    await tester.pumpAndSettle();
    expect(identical(aListState(tester), list), isTrue);
    expect(identical(aItemState(tester, '1'), item), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(
      identical(aListState(tester), list),
      isTrue,
      reason: 'the page that reappears from deep in the stack keeps its State',
    );
    expect(
      find.textContaining('a count 1', skipOffstage: false),
      findsOneWidget,
    );
  });
}
