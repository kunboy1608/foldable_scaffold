import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_router/foldable_router.dart';

import 'pixel_utils.dart';

/// STEP 1 of the two-pane work: prove that a page always occupies the
/// rectangle of its placeholder frame, in the same frame, for arbitrary app
/// layouts — and that changing the layout never rebuilds the page state.

/// The layout the shell returns. Tests change it between pumps.
class PaneLayout {
  bool twoPane = false;
  Axis axis = Axis.horizontal;
  int leftFlex = 2;
  int rightFlex = 3;
  double gap = 24;
  bool gutterButton = false;
  bool omitSecondary = false;
}

final PaneLayout paneLayout = PaneLayout();

class LayoutShell extends FoldableShellRoute {
  const LayoutShell();

  @override
  List<FoldableRoute> get branches => const [AlphaRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Scaffold(body: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (!paneLayout.twoPane) return null;
    final Widget primary = KeyedSubtree(
      key: const Key('primary-frame'),
      child: panes.primary,
    );
    final Widget secondary = KeyedSubtree(
      key: const Key('secondary-frame'),
      child: panes.secondary,
    );
    final Widget right = paneLayout.omitSecondary
        ? const SizedBox.shrink()
        : panes.hasSecondary
        ? secondary
        : const Center(key: Key('empty-secondary'), child: Text('choose'));
    final Widget gutter = SizedBox(
      width: paneLayout.axis == Axis.horizontal ? paneLayout.gap : null,
      height: paneLayout.axis == Axis.vertical ? paneLayout.gap : null,
      child: paneLayout.gutterButton
          ? Center(
              child: IconButton(
                key: const Key('gutter'),
                iconSize: 16,
                icon: const Icon(Icons.close_fullscreen),
                onPressed: () => gutterTaps++,
              ),
            )
          : null,
    );
    if (paneLayout.axis == Axis.horizontal) {
      return Row(
        children: [
          Expanded(flex: paneLayout.leftFlex, child: primary),
          gutter,
          Expanded(flex: paneLayout.rightFlex, child: right),
        ],
      );
    }
    return Column(
      children: [
        Expanded(flex: paneLayout.leftFlex, child: primary),
        gutter,
        Expanded(flex: paneLayout.rightFlex, child: right),
      ],
    );
  }
}

int gutterTaps = 0;

class AlphaRoute extends FoldableRoute {
  const AlphaRoute();

  @override
  String get path => '/alpha';

  @override
  FoldableRoute? get parent => const LayoutShell();

  @override
  Widget build(BuildContext context) => const AlphaPage();
}

class BetaRoute extends FoldableRoute {
  const BetaRoute();

  @override
  String get path => '/alpha/beta';

  @override
  FoldableRoute? get parent => const AlphaRoute();

  @override
  Widget build(BuildContext context) => const BetaPage();
}

/// A page with everything whose state must survive: a counter, a text field
/// and a scroll offset.
class AlphaPage extends StatefulWidget {
  const AlphaPage({super.key});

  @override
  State<AlphaPage> createState() => AlphaPageState();
}

class AlphaPageState extends State<AlphaPage> {
  int count = 0;
  final TextEditingController text = TextEditingController();
  final ScrollController scroll = ScrollController();

  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FoldablePane pane = FoldableRouter.paneOf(context);
    return Material(
      key: const Key('page alpha'),
      child: Column(
        children: [
          Text('alpha pane ${pane.name}'),
          TextButton(
            key: const Key('alpha-increment'),
            onPressed: () => setState(() => count++),
            child: Text('alpha count $count'),
          ),
          TextField(key: const Key('alpha-text'), controller: text),
          TextButton(
            key: const Key('alpha-page-button'),
            onPressed: () => pageTaps++,
            child: const Text('page button'),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('alpha-list'),
              controller: scroll,
              itemCount: 50,
              itemBuilder: (context, index) =>
                  SizedBox(height: 40, child: Text('alpha item $index')),
            ),
          ),
        ],
      ),
    );
  }
}

int pageTaps = 0;

class BetaPage extends StatelessWidget {
  const BetaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      key: Key('page beta'),
      child: Center(child: Text('beta')),
    );
  }
}

FoldableRouter createRouter() {
  final router = FoldableRouter(
    initial: const LayoutShell(),
    routes: {
      '/alpha': (params) => const AlphaRoute(),
      '/alpha/beta': (params) => const BetaRoute(),
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

/// Rebuilds the app once (one frame), the way an app reacts to the state
/// that decides its pane layout.
Future<void> rebuild(WidgetTester tester, FoldableRouter router) async {
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.routerConfig),
  );
}

Rect frameRect(WidgetTester tester, String key) =>
    tester.getRect(find.byKey(Key(key), skipOffstage: false));

/// Proves, at the pixel level, that the (already `getRect`-verified) pages stay
/// drawn in their frames across a redundant rebuild: a page that is laid out on
/// its frame but painted on a stale rectangle would move here even though
/// `getRect` still passes.
Future<void> expectPagesStayInFramesAcrossRebuild(
  WidgetTester tester,
  FoldableRouter router,
  List<String> frameKeys,
) async {
  final regions = [
    for (final key in frameKeys) frameRect(tester, key),
  ];
  final Screenshot before = await capture(tester);
  await rebuild(tester, router);
  await tester.pumpAndSettle();
  final Screenshot after = await capture(tester);
  for (var i = 0; i < frameKeys.length; i++) {
    expect(
      after.diff(before, region: regions[i]),
      0,
      reason:
          'the pixels of ${frameKeys[i]} changed across a redundant rebuild',
    );
  }
}

void main() {
  setUp(() {
    paneLayout
      ..twoPane = false
      ..axis = Axis.horizontal
      ..leftFlex = 2
      ..rightFlex = 3
      ..gap = 24
      ..gutterButton = false
      ..omitSecondary = false;
    gutterTaps = 0;
    pageTaps = 0;
  });

  testWidgets('a) pages occupy the rectangle of their frame, asymmetric row '
      'with a gap', (tester) async {
    final router = await pumpApp(tester);
    paneLayout.twoPane = true;
    await rebuild(tester, router);
    expect(find.byKey(const Key('page alpha')), findsOneWidget);
    // [A] with two panes: A on the left, right pane empty.
    expect(find.byKey(const Key('empty-secondary')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      frameRect(tester, 'primary-frame'),
    );

    await router.open(const BetaRoute());
    await tester.pumpAndSettle();
    // [A, B]: A left, B right.
    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      frameRect(tester, 'primary-frame'),
    );
    expect(
      tester.getRect(find.byKey(const Key('page beta'))),
      frameRect(tester, 'secondary-frame'),
    );
    // The frames are asymmetric (2:3) and separated by the gap.
    final Rect left = frameRect(tester, 'primary-frame');
    final Rect right = frameRect(tester, 'secondary-frame');
    expect(left.width / right.width, closeTo(2 / 3, 0.01));
    expect(right.left - left.right, 24);

    // Pixel check: the pages really are painted on those frames, and a
    // redundant rebuild does not move them.
    await expectPagesStayInFramesAcrossRebuild(tester, router, [
      'primary-frame',
      'secondary-frame',
    ]);
  });

  testWidgets('a) pages occupy the rectangle of their frame, vertical '
      'column', (tester) async {
    paneLayout
      ..twoPane = true
      ..axis = Axis.vertical
      ..leftFlex = 1
      ..rightFlex = 2;
    final router = await pumpApp(tester);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      frameRect(tester, 'primary-frame'),
    );
    expect(
      tester.getRect(find.byKey(const Key('page beta'))),
      frameRect(tester, 'secondary-frame'),
    );
    final Rect top = frameRect(tester, 'primary-frame');
    final Rect bottom = frameRect(tester, 'secondary-frame');
    expect(top.height / bottom.height, closeTo(1 / 2, 0.01));
    expect(bottom.top - top.bottom, 24);

    // Pixel check: the pages are painted on those frames, and a redundant
    // rebuild does not move them.
    await expectPagesStayInFramesAcrossRebuild(tester, router, [
      'primary-frame',
      'secondary-frame',
    ]);
  });

  testWidgets('b) after a resize, ONE pump puts every page in its new frame', (
    tester,
  ) async {
    final router = await pumpApp(tester);
    paneLayout.twoPane = true;
    await rebuild(tester, router);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();
    final Rect before = frameRect(tester, 'secondary-frame');

    tester.view.physicalSize = const Size(1200, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump();

    final Rect after = frameRect(tester, 'secondary-frame');
    expect(after, isNot(before));
    expect(
      tester.getRect(find.byKey(const Key('page beta'))),
      after,
      reason: 'the page must follow its frame on the very same frame',
    );
    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      frameRect(tester, 'primary-frame'),
    );
  });

  testWidgets('b) after a ratio change, ONE pump puts every page in its new '
      'frame', (tester) async {
    final router = await pumpApp(tester);
    paneLayout.twoPane = true;
    await rebuild(tester, router);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();

    paneLayout.leftFlex = 3;
    paneLayout.rightFlex = 4;
    paneLayout.gap = 40;
    await rebuild(tester, router);

    final Rect left = frameRect(tester, 'primary-frame');
    final Rect right = frameRect(tester, 'secondary-frame');
    expect(right.left - left.right, 40);
    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      left,
      reason: 'no frame of lag after a ratio change',
    );
    expect(tester.getRect(find.byKey(const Key('page beta'))), right);
  });

  testWidgets('c) taps in the gap reach the panes layout, taps in a frame '
      'reach the page', (tester) async {
    final router = await pumpApp(tester);
    paneLayout
      ..twoPane = true
      ..gutterButton = true;
    await rebuild(tester, router);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gutter')));
    await tester.pump();
    expect(gutterTaps, 1);
    expect(pageTaps, 0);

    await tester.tap(find.byKey(const Key('alpha-page-button')));
    await tester.pump();
    expect(pageTaps, 1);
    expect(gutterTaps, 1);

    // A tap in the gap does not reach the pages.
    final Rect left = frameRect(tester, 'primary-frame');
    final Rect right = frameRect(tester, 'secondary-frame');
    await tester.tapAt(Offset((left.right + right.left) / 2, left.center.dy));
    await tester.pump();
    expect(pageTaps, 1);
  });

  testWidgets('d) flipping one <-> two panes keeps the page state and the '
      'navigator', (tester) async {
    final router = await pumpApp(tester);
    final AlphaPageState state = tester.state<AlphaPageState>(
      find.byType(AlphaPage),
    );
    final Element navigator = tester.element(
      find
          .byWidgetPredicate(
            (widget) => widget is Navigator,
            skipOffstage: false,
          )
          .last,
    );
    await tester.tap(find.byKey(const Key('alpha-increment')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('alpha-text')), 'draft');
    await tester.pump();
    state.scroll.jumpTo(160);
    await tester.pump();

    for (var i = 0; i < 4; i++) {
      paneLayout.twoPane = i.isEven;
      await rebuild(tester, router);
      expect(
        identical(tester.state<AlphaPageState>(find.byType(AlphaPage)), state),
        isTrue,
        reason: 'the State of the page must survive the mode switch',
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
        reason: 'the Navigator of the tab must not be rebuilt',
      );
      expect(find.text('alpha count 1'), findsOneWidget);
      expect(find.text('draft'), findsOneWidget);
      expect(state.scroll.offset, 160);
    }

    // Two panes again: the page moved to the left frame with its state.
    paneLayout.twoPane = true;
    await rebuild(tester, router);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();
    expect(
      identical(tester.state<AlphaPageState>(find.byType(AlphaPage)), state),
      isTrue,
    );
    expect(
      tester.getRect(find.byKey(const Key('page alpha'))),
      frameRect(tester, 'primary-frame'),
    );
  });

  testWidgets('a two-pane tab that forgets its secondary frame reports a '
      'clear error', (tester) async {
    paneLayout
      ..twoPane = true
      ..omitSecondary = true;
    final router = await pumpApp(tester);
    await router.open(const BetaRoute());
    await tester.pumpAndSettle();

    final Object? error = tester.takeException();
    expect(error, isA<FlutterError>());
    expect(error.toString(), contains('does not place its secondary pane'));
  });
}
