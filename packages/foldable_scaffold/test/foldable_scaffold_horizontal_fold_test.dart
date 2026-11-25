import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart'
    show PaneGeometry;
import 'package:material_ui/material_ui.dart';

const _window = Size(800, 1200);

/// A hinge across the middle of the 800x1200 window, 40 tall.
const _hingeBounds = Rect.fromLTRB(0, 580, 800, 620);

DisplayFeature _hinge([Rect bounds = _hingeBounds]) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureFlat,
);

DisplayFeature _halfOpenFold([double y = 600]) => DisplayFeature(
  bounds: Rect.fromLTRB(0, y, 800, y),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureHalfOpened,
);

DisplayFeature _flatHorizontalFold([double y = 600]) => DisplayFeature(
  bounds: Rect.fromLTRB(0, y, 800, y),
  type: DisplayFeatureType.fold,
  state: DisplayFeatureState.postureFlat,
);

DisplayFeature _verticalHinge(double left, double right) => DisplayFeature(
  bounds: Rect.fromLTRB(left, 0, right, 1200),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureFlat,
);

Finder get _body => find.byKey(const Key('body_builder'));
Finder get _secondary =>
    find.byKey(const Key('secondary_body_builder'), skipOffstage: false);
Finder get _divider => find.byKey(const Key('pane_divider'));

/// What a pane sees of the window.
class _Insets {
  EdgeInsets padding = EdgeInsets.zero;
  Size? constraints;
}

/// A widget with a state of its own, to check that panes keep theirs.
class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  static final created = <String, int>{};

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  @override
  void initState() {
    super.initState();
    _Counter.created.update(widget.label, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

/// The navigation to put in the way of the panes.
enum _Nav { none, top, bottom }

/// Pumps a [FoldableScaffold] filling a window of [size], with [features].
///
/// It runs as a desktop on purpose: an 800 wide window would never show two
/// panes there, so two panes are the hinge's doing.
Future<void> _pump(
  WidgetTester tester, {
  Size size = _window,
  List<DisplayFeature> features = const [],
  bool appBar = false,
  _Nav nav = _Nav.none,
  double topInset = 0,
  double bottomInset = 0,
  bool extendBody = false,
  bool secondary = true,
  bool followFold = true,
  double minBodySize = 200,
  TextDirection textDirection = TextDirection.ltr,
  FoldableScaffoldController? controller,
  _Insets? bodyInsets,
  _Insets? secondaryInsets,
  Duration paneAnimationDuration = const Duration(milliseconds: 250),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.displayFeatures = features;
  tester.view.viewPadding = FakeViewPadding(top: topInset, bottom: bottomInset);
  tester.view.padding = FakeViewPadding(top: topInset, bottom: bottomInset);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: TargetPlatform.linux),
      builder: (context, child) =>
          Directionality(textDirection: textDirection, child: child!),
      home: FoldableScaffold(
        controller: controller,
        followFold: followFold,
        minBodySize: minBodySize,
        extendBody: extendBody,
        paneAnimationDuration: paneAnimationDuration,
        appBar: appBar ? AppBar(title: const Text('title')) : null,
        navigationPlacement: (_) => switch (nav) {
          _Nav.none => const FoldableNavigationPlacement.none(),
          _Nav.top => const FoldableNavigationPlacement.top(),
          _Nav.bottom => const FoldableNavigationPlacement.bottom(),
        },
        navigationBuilder: (context, placement, constraints, padding) =>
            SizedBox(
              height: nav == _Nav.top ? 70 : 60,
              child: Text('nav ${placement.edge.name}'),
            ),
        bodyBuilder: (context, constraints) {
          bodyInsets
            ?..padding = MediaQuery.paddingOf(context)
            ..constraints = constraints.biggest;
          return const _Counter(label: 'body');
        },
        secondaryBodyBuilder: secondary
            ? (context, constraints) {
                secondaryInsets
                  ?..padding = MediaQuery.paddingOf(context)
                  ..constraints = constraints.biggest;
                return const _Counter(label: 'secondary');
              }
            : null,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

bool _paneIsHidden(WidgetTester tester, String text) {
  final exclude = tester.widget<ExcludeFocus>(
    find
        .ancestor(
          of: find.text(text, skipOffstage: false),
          matching: find.byType(ExcludeFocus),
        )
        .first,
  );
  return exclude.excluding;
}

void main() {
  setUp(_Counter.created.clear);

  group('a horizontal hinge stacks the panes', () {
    testWidgets('the body is on top, the secondary body below, the hinge is '
        'the divider', (tester) async {
      await _pump(tester, features: [_hinge()]);

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(_rectOf(tester, _divider), _hingeBounds);
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
      expect(find.text('body'), findsOneWidget);
      expect(find.text('secondary'), findsOneWidget);
    });

    testWidgets('a half-open fold separates like a hinge', (tester) async {
      await _pump(tester, features: [_halfOpenFold()]);

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 600));
      expect(_rectOf(tester, _divider), const Rect.fromLTRB(0, 600, 800, 600));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 600, 800, 1200),
      );
    });

    testWidgets('canSplit is true whatever the width, and the controller '
        'says the panes are stacked', (tester) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, features: [_hinge()], controller: controller);

      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .canSplit,
        isTrue,
      );
      expect(
        tester.widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout)).axis,
        Axis.vertical,
      );
      expect(controller.isSplit, isTrue);
      expect(controller.isStacked, isTrue);
      expect(controller.axis, Axis.vertical);
      // The secondary pane is as wide as the pane area.
      expect(controller.secondaryWidth, 800);
    });

    testWidgets('the panes get tight constraints along the axis', (
      tester,
    ) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        features: [_hinge()],
        bodyInsets: body,
        secondaryInsets: secondary,
      );

      expect(body.constraints, const Size(800, 580));
      expect(secondary.constraints, const Size(800, 580));
    });

    testWidgets('without a hinge the same window shows one pane', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, controller: controller);

      expect(_rectOf(tester, _secondary), const Rect.fromLTRB(0, 0, 800, 1200));
      expect(_rectOf(tester, _body).width, 0);
      expect(controller.isSplit, isFalse);
      expect(controller.axis, isNull);
      expect(controller.isStacked, isFalse);
      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .canSplit,
        isFalse,
      );
    });

    testWidgets('RTL does not flip it: the body stays on top', (tester) async {
      await _pump(
        tester,
        features: [_hinge()],
        textDirection: TextDirection.rtl,
      );

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });

    testWidgets('no secondary body: nothing to stack', (tester) async {
      await _pump(tester, features: [_hinge()], secondary: false);

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 1200));
      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .canSplit,
        isFalse,
      );
    });

    testWidgets('a hinge too close to an edge leaves the usual layout', (
      tester,
    ) async {
      // The top screen would be 150 tall, under minBodySize (200).
      await _pump(
        tester,
        features: [_hinge(const Rect.fromLTRB(0, 150, 800, 190))],
      );

      expect(_rectOf(tester, _body).width, 0);
      expect(_rectOf(tester, _secondary), const Rect.fromLTRB(0, 0, 800, 1200));
    });

    testWidgets('minBodySize is the minimum height too', (tester) async {
      const bounds = Rect.fromLTRB(0, 250, 800, 290);
      await _pump(tester, features: [_hinge(bounds)], minBodySize: 250);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 250));

      await _pump(tester, features: [_hinge(bounds)], minBodySize: 251);
      expect(_rectOf(tester, _body).width, 0);
    });

    testWidgets('followFold: false ignores it', (tester) async {
      await _pump(tester, features: [_hinge()], followFold: false);

      expect(_rectOf(tester, _body).width, 0);
    });

    testWidgets('a scaffold that is not as tall as the window ignores it', (
      tester,
    ) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = [_hinge()];
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: Column(
            children: [
              const SizedBox(height: 100),
              Expanded(
                child: FoldableScaffold(
                  body: const Text('body'),
                  secondaryBody: const Text('secondary'),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(_body).width, 0);
      expect(tester.getSize(_secondary).height, 1100);
    });
  });

  group('the divider at a horizontal hinge', () {
    testWidgets('is not a handle: no focus and no semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester, features: [_hinge()]);

        expect(_rectOf(tester, _divider).height, 40);
        expect(
          find.descendant(of: _divider, matching: find.byType(Focus)),
          findsNothing,
        );
        expect(find.bySemanticsLabel('Resize panes'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('a drag on it moves nothing', (tester) async {
      await _pump(tester, features: [_hinge()]);

      await tester.dragFrom(const Offset(400, 600), const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });

    testWidgets('setSecondaryWidth and resetDivider do nothing', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(tester, features: [_hinge()], controller: controller);

      controller.setSecondaryWidth(300);
      controller.setSecondaryWidth(300, snap: true);
      controller.resetDivider();
      await tester.pumpAndSettle();

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
      expect(controller.secondaryWidth, 800);
      expect(controller.isStacked, isTrue);
    });
  });

  group('a flat horizontal fold and vertical folds', () {
    testWidgets('a flat horizontal fold is ignored: the width decides', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        features: [_flatHorizontalFold()],
        controller: controller,
      );

      // 800 wide on desktop: one pane.
      expect(_rectOf(tester, _secondary), const Rect.fromLTRB(0, 0, 800, 1200));
      expect(controller.isSplit, isFalse);

      // And a wide window keeps its side-by-side panes, divider in the middle.
      await _pump(
        tester,
        size: const Size(1400, 1200),
        features: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(0, 600, 1400, 600),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
        controller: controller,
      );
      expect(controller.isSplit, isTrue);
      expect(controller.axis, Axis.horizontal);
      expect(_rectOf(tester, _body).top, 0);
      expect(_rectOf(tester, _secondary).top, 0);
      expect(_rectOf(tester, _body).left, 0);
      expect(_rectOf(tester, _secondary).left, greaterThan(500));
    });

    testWidgets('a vertical hinge is what it was: side by side', (
      tester,
    ) async {
      final controller = FoldableScaffoldController();
      addTearDown(controller.dispose);
      await _pump(
        tester,
        features: [_verticalHinge(380, 420)],
        controller: controller,
      );

      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 380, 1200));
      expect(_rectOf(tester, _divider), const Rect.fromLTRB(380, 0, 420, 1200));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(420, 0, 800, 1200),
      );
      expect(controller.axis, Axis.horizontal);
      expect(controller.isStacked, isFalse);
      expect(controller.secondaryWidth, 380);
    });

    testWidgets('with both, the first fold of the list decides', (
      tester,
    ) async {
      await _pump(tester, features: [_verticalHinge(380, 420), _hinge()]);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 380, 1200));

      await _pump(tester, features: [_hinge(), _verticalHinge(380, 420)]);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
    });
  });

  group('the pane area is measured: what is above and below the panes', () {
    testWidgets('an app bar and a status bar inset move the panes, not the '
        'hinge', (tester) async {
      await _pump(tester, features: [_hinge()], appBar: true, topInset: 40);

      // The app bar is 56 tall and sits under the 40 of the status bar.
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 96, 800, 580));
      expect(_rectOf(tester, _divider), _hingeBounds);
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });

    testWidgets('a navigation above the panes is subtracted as well', (
      tester,
    ) async {
      await _pump(
        tester,
        features: [_hinge()],
        appBar: true,
        nav: _Nav.top,
        topInset: 40,
      );

      // 40 + 56 + 70 above the panes.
      expect(find.text('nav top'), findsOneWidget);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 166, 800, 580));
      expect(_rectOf(tester, _divider), _hingeBounds);
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });

    testWidgets('a navigation below the panes ends the area before the '
        'window', (tester) async {
      await _pump(
        tester,
        features: [_hinge()],
        appBar: true,
        nav: _Nav.bottom,
        topInset: 40,
        bottomInset: 20,
      );

      // The bottom bar takes 60, and the inset of the gesture bar goes into it.
      expect(find.text('nav bottom'), findsOneWidget);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 96, 800, 580));
      expect(_rectOf(tester, _divider), _hingeBounds);
      final secondary = _rectOf(tester, _secondary);
      expect(secondary.top, 620);
      expect(secondary.bottom, _rectOf(tester, find.text('nav bottom')).top);
    });

    testWidgets('a top navigation can leave too little room above the hinge', (
      tester,
    ) async {
      // The panes would start 166 down: the hinge at 280 leaves 114 above.
      await _pump(
        tester,
        features: [_hinge(const Rect.fromLTRB(0, 280, 800, 320))],
        appBar: true,
        nav: _Nav.top,
        topInset: 40,
      );

      expect(_rectOf(tester, _body).width, 0);
      expect(_rectOf(tester, _secondary).top, 166);

      // Without the navigation there are 184 above it: still too little, and
      // with a smaller minBodySize there is room.
      await _pump(
        tester,
        features: [_hinge(const Rect.fromLTRB(0, 280, 800, 320))],
        appBar: true,
        nav: _Nav.top,
        topInset: 40,
        minBodySize: 114,
      );
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 166, 800, 280));
    });

    testWidgets('the first frame is not shown before the area is measured', (
      tester,
    ) async {
      await _pump(
        tester,
        features: [_hinge()],
        appBar: true,
        nav: _Nav.top,
        topInset: 40,
        settle: false,
      );

      Opacity paneOpacity() => tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(FoldablePaneLayout),
              matching: find.byType(Opacity),
            )
            .first,
      );

      // The estimate knows the app bar, not the navigation: it is wrong, and
      // it is not shown.
      expect(paneOpacity().opacity, 0);

      // The next frame has the measure: the panes are where they belong at
      // once, with no slide from the estimate.
      await tester.pump();
      expect(paneOpacity().opacity, 1);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 166, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });

    testWidgets('no hinge, no hidden frame: a plain scaffold is unchanged', (
      tester,
    ) async {
      await _pump(tester, appBar: true, settle: false);

      final opacity = tester.widget<Opacity>(
        find
            .descendant(
              of: find.byType(FoldablePaneLayout),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 1);
    });

    testWidgets('the pane area keeps being measured: a navigation that '
        'appears moves the hinge inside it', (tester) async {
      // Starts without a top navigation (hinge 580..620 below an app bar).
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = [_hinge()];
      addTearDown(tester.view.reset);

      Widget build(bool withNav) => MaterialApp(
        theme: ThemeData(platform: TargetPlatform.linux),
        home: FoldableScaffold(
          appBar: AppBar(title: const Text('title')),
          navigationPlacement: (_) => withNav
              ? const FoldableNavigationPlacement.top()
              : const FoldableNavigationPlacement.none(),
          navigationBuilder: (context, placement, constraints, padding) =>
              const SizedBox(height: 70, child: Text('nav')),
          body: const Text('body'),
          secondaryBody: const Text('secondary'),
        ),
      );

      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body).top, 56);

      await tester.pumpWidget(build(true));
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 126, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
    });
  });

  group('the posture changes', () {
    testWidgets('adding and removing the hinge keeps the state of both '
        'panes', (tester) async {
      await _pump(tester);
      expect(_Counter.created, {'body': 1, 'secondary': 1});

      // The device opens its hinge: the panes stack.
      tester.view.displayFeatures = [_hinge()];
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
      expect(_Counter.created, {'body': 1, 'secondary': 1});

      // And closes it again.
      tester.view.displayFeatures = const [];
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body).width, 0);
      expect(_rectOf(tester, _secondary), const Rect.fromLTRB(0, 0, 800, 1200));
      expect(_Counter.created, {'body': 1, 'secondary': 1});
    });

    testWidgets('a half-open fold that flattens leaves the stacking', (
      tester,
    ) async {
      await _pump(tester, features: [_halfOpenFold()]);
      expect(_rectOf(tester, _body).height, 600);

      tester.view.displayFeatures = [_flatHorizontalFold()];
      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body).width, 0);
      expect(_Counter.created, {'body': 1, 'secondary': 1});
    });

    testWidgets('the first frame laid out with the new hinge is the final one, '
        'the pane area already known', (tester) async {
      await _pump(tester, appBar: true, nav: _Nav.top);
      tester.view.displayFeatures = [_hinge()];
      // The test binding hands a change of the window over one frame late.
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));

      // 56 + 70 above the panes, known from the previous frames: no frame with
      // the panes at a wrong place, and no slide from the old layout.
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 126, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
      // And it stays there while the (empty) animation runs out.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_rectOf(tester, _body).bottom, 580);
      expect(_rectOf(tester, _secondary).top, 620);
    });

    testWidgets('a move between side by side and stacked does not animate the '
        'extents across axes', (tester) async {
      await _pump(tester, features: [_verticalHinge(380, 420)]);
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 380, 1200));

      tester.view.displayFeatures = [_hinge()];
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      // At once the final layout: no pane 380 wide sliding into one 580 tall.
      expect(_rectOf(tester, _body), const Rect.fromLTRB(0, 0, 800, 580));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(0, 620, 800, 1200),
      );
      // And it stays there while the (empty) animation runs out.
      await tester.pump(const Duration(milliseconds: 100));
      expect(_rectOf(tester, _body).bottom, 580);
      expect(_rectOf(tester, _secondary).top, 620);
    });

    testWidgets('moving the hinge within the stacked layout animates the '
        'panes', (tester) async {
      await _pump(tester, features: [_hinge()]);

      tester.view.displayFeatures = [
        _hinge(const Rect.fromLTRB(0, 780, 800, 820)),
      ];
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 125));
      final mid = _rectOf(tester, _body).bottom;
      expect(mid, greaterThan(580));
      expect(mid, lessThan(780));

      await tester.pumpAndSettle();
      expect(_rectOf(tester, _body).bottom, 780);
      expect(_rectOf(tester, _secondary).top, 820);
    });

    testWidgets('no layout error on any frame of the change', (tester) async {
      await _pump(tester, appBar: true, nav: _Nav.top, topInset: 40);
      tester.view.displayFeatures = [_hinge()];
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('the hidden pane, along the vertical axis', () {
    testWidgets('both panes stacked are live', (tester) async {
      await _pump(tester, features: [_hinge()]);

      expect(_paneIsHidden(tester, 'body'), isFalse);
      expect(_paneIsHidden(tester, 'secondary'), isFalse);
    });

    testWidgets('a pane without height is hidden, by its extent', (
      tester,
    ) async {
      // The keyboard eats the room of the pane area before the next
      // measure: for that one frame the panes are stacked in a pane area
      // shorter than the hinge, and the secondary pane has no height.
      await _pump(
        tester,
        features: [_hinge()],
        paneAnimationDuration: Duration.zero,
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 700);
      await tester.pump();

      expect(tester.getSize(_secondary).height, 0);
      expect(_paneIsHidden(tester, 'secondary'), isTrue);
      expect(_paneIsHidden(tester, 'body'), isFalse);
      expect(
        tester
            .widget<FoldablePaneLayout>(find.byType(FoldablePaneLayout))
            .secondaryVisible,
        isFalse,
      );
      expect(_Counter.created['secondary'], 1);
    });

    test('PaneGeometry visibility comes from the extent, on any axis', () {
      const geometry = PaneGeometry(
        primaryExtent: 0,
        dividerExtent: 0,
        secondaryExtent: 300,
        axis: Axis.vertical,
      );

      expect(geometry.primaryVisible, isFalse);
      expect(geometry.secondaryVisible, isTrue);
    });
  });

  group('what the panes see of the window when stacked', () {
    testWidgets('the pane on top has no inset under it, the one below none '
        'above it', (tester) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        features: [_hinge()],
        topInset: 40,
        bottomInset: 20,
        bodyInsets: body,
        secondaryInsets: secondary,
      );

      // No app bar: the status bar inset is the pane on top's.
      expect(body.padding.top, 40);
      expect(body.padding.bottom, 0);
      expect(secondary.padding.top, 0);
      expect(secondary.padding.bottom, 20);
    });

    testWidgets('an app bar took the top inset already', (tester) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        features: [_hinge()],
        appBar: true,
        topInset: 40,
        bottomInset: 20,
        bodyInsets: body,
        secondaryInsets: secondary,
      );

      expect(body.padding.top, 0);
      expect(body.padding.bottom, 0);
      expect(secondary.padding.top, 0);
      expect(secondary.padding.bottom, 20);
    });

    testWidgets('with extendBody the pane below pads for the bottom bar', (
      tester,
    ) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        features: [_hinge()],
        nav: _Nav.bottom,
        extendBody: true,
        bottomInset: 20,
        bodyInsets: body,
        secondaryInsets: secondary,
      );

      expect(body.padding.bottom, 0);
      expect(secondary.padding.bottom, 60);
    });

    testWidgets('side by side nothing changes: both panes see the same', (
      tester,
    ) async {
      final body = _Insets();
      final secondary = _Insets();
      await _pump(
        tester,
        features: [_verticalHinge(380, 420)],
        topInset: 40,
        bottomInset: 20,
        bodyInsets: body,
        secondaryInsets: secondary,
      );

      expect(body.padding, secondary.padding);
      expect(body.padding.top, 40);
      expect(body.padding.bottom, 20);
    });
  });

  group('the navigation stays outside the panes', () {
    testWidgets('a rail on the side takes its width, the hinge still '
        'stacks', (tester) async {
      tester.view.physicalSize = _window;
      tester.view.devicePixelRatio = 1;
      tester.view.displayFeatures = [_hinge()];
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.linux),
          home: FoldableScaffold(
            appBar: AppBar(title: const Text('title')),
            primaryNavigation: const SizedBox(width: 80, child: Text('rail')),
            body: const Text('body'),
            secondaryBody: const Text('secondary'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 800 wide on desktop: the default placement is a rail on the start side.
      expect(_rectOf(tester, _body), const Rect.fromLTRB(72, 56, 800, 580));
      expect(_rectOf(tester, _divider), const Rect.fromLTRB(72, 580, 800, 620));
      expect(
        _rectOf(tester, _secondary),
        const Rect.fromLTRB(72, 620, 800, 1200),
      );
      expect(find.text('rail'), findsOneWidget);
    });
  });
}
