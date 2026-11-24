// A navigation inside the system strip of its edge (iPhone Duo's 84 wide side
// strip), lined up with the system icons and at the bottom.
import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';
import 'package:material_ui/material_ui.dart';

DisplayFeature _cutout(double l, double t, double r, double b) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(l, t, r, b),
    type: DisplayFeatureType.cutout,
    state: DisplayFeatureState.unknown,
  );
}

FoldableLayoutInfo _info({
  FoldableNavigationEdge? verticalBarEdge,
  double width = 300,
}) {
  return FoldableLayoutInfo(
    scaffoldSize: Size(width, 600),
    windowSize: Size(width, 600),
    platform: TargetPlatform.iOS,
    textDirection: TextDirection.ltr,
    padding: EdgeInsets.zero,
    breakpoints: const FoldableBreakpoints.handheld(),
    verticalBarEdge: verticalBarEdge,
  );
}

FrameGeometry _frame(
  FoldableNavigationPlacement placement, {
  EdgeInsets padding = EdgeInsets.zero,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return computeFrameGeometry(
    scaffoldWidth: 951,
    windowSize: const Size(951, 669),
    breakpoints: const FoldableBreakpoints.handheld(),
    textDirection: textDirection,
    padding: padding,
    displayFeatures: const [],
    followFold: true,
    minBodySize: 200,
    dividerSize: 24,
    placement: placement,
    minWidthNavigation: 72,
    maxWidthNavigation: 192,
    hasNavigation: true,
    hasSecondaryBody: false,
  );
}

void main() {
  group('FoldableNavigationPlacement', () {
    test('defaults: alignment start, not inside the inset', () {
      const p = FoldableNavigationPlacement(FoldableNavigationEdge.end);
      expect(p.alignment, FoldableNavigationAlignment.start);
      expect(p.insideInset, isFalse);
      expect(p.toString(), 'FoldableNavigationPlacement(end)');
    });

    test('equality, hashCode and toString include the new fields', () {
      const a = FoldableNavigationPlacement(
        FoldableNavigationEdge.end,
        alignment: FoldableNavigationAlignment.end,
        insideInset: true,
      );
      const same = FoldableNavigationPlacement.end(
        alignment: FoldableNavigationAlignment.end,
        insideInset: true,
      );
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(const FoldableNavigationPlacement.end()));
      expect(
        a,
        isNot(
          const FoldableNavigationPlacement.end(
            alignment: FoldableNavigationAlignment.end,
          ),
        ),
      );
      expect(
        a,
        isNot(const FoldableNavigationPlacement.end(insideInset: true)),
      );
      expect(a.toString(), contains('alignment: end'));
      expect(a.toString(), contains('insideInset: true'));
    });

    test('every named constructor takes the new parameters', () {
      const c = FoldableNavigationAlignment.center;
      expect(
        const FoldableNavigationPlacement.none(alignment: c, insideInset: true),
        const FoldableNavigationPlacement(
          FoldableNavigationEdge.none,
          alignment: c,
          insideInset: true,
        ),
      );
      expect(
        const FoldableNavigationPlacement.bottom(alignment: c).alignment,
        c,
      );
      expect(const FoldableNavigationPlacement.top(alignment: c).alignment, c);
      expect(
        const FoldableNavigationPlacement.start(
          extent: 80,
          alignment: c,
          insideInset: true,
        ),
        const FoldableNavigationPlacement(
          FoldableNavigationEdge.start,
          extent: 80,
          alignment: c,
          insideInset: true,
        ),
      );
      expect(
        const FoldableNavigationPlacement.left(insideInset: true).insideInset,
        isTrue,
      );
      expect(
        const FoldableNavigationPlacement.right(alignment: c).alignment,
        c,
      );
    });

    test(
      'the default resolver puts a vertical bar inside the strip, at the end',
      () {
        for (final edge in [
          FoldableNavigationEdge.start,
          FoldableNavigationEdge.end,
          FoldableNavigationEdge.left,
          FoldableNavigationEdge.right,
        ]) {
          final p = defaultNavigationPlacement(_info(verticalBarEdge: edge));
          expect(p.edge, edge);
          expect(p.alignment, FoldableNavigationAlignment.end);
          expect(p.insideInset, isTrue);
        }
      },
    );

    test('bottom bar and rail by breakpoint are unchanged', () {
      expect(
        defaultNavigationPlacement(_info(width: 300)),
        const FoldableNavigationPlacement.bottom(),
      );
      expect(
        defaultNavigationPlacement(_info(width: 900)),
        const FoldableNavigationPlacement.start(),
      );
    });
  });

  group('computeFrameGeometry with insideInset', () {
    const inside = FoldableNavigationPlacement.right(insideInset: true);

    test('the slot is the inset when there is one', () {
      final f = _frame(inside, padding: const EdgeInsets.only(right: 84));
      expect(f.navigationWidth, 84);
      expect(f.paneAreaWidth, 951 - 84);
    });

    test('the extent is ignored', () {
      final f = _frame(
        const FoldableNavigationPlacement.right(extent: 120, insideInset: true),
        padding: const EdgeInsets.only(right: 84),
      );
      expect(f.navigationWidth, 84);
    });

    test('without an inset it is the extent', () {
      expect(_frame(inside).navigationWidth, 72);
      expect(
        _frame(
          inside,
          padding: const EdgeInsets.only(left: 30),
        ).navigationWidth,
        72,
      );
    });

    test('left edge', () {
      final f = _frame(
        const FoldableNavigationPlacement.left(insideInset: true),
        padding: const EdgeInsets.only(left: 48),
      );
      expect(f.navigationWidth, 48);
      expect(f.paneAreaWidth, 951 - 48);
    });

    test('not inside the inset it is extent + inset', () {
      final f = _frame(
        const FoldableNavigationPlacement.right(),
        padding: const EdgeInsets.only(right: 84),
      );
      expect(f.navigationWidth, 72 + 84);
    });

    test('RTL: start resolves to the right and uses padding.right', () {
      final f = _frame(
        const FoldableNavigationPlacement.start(insideInset: true),
        padding: const EdgeInsets.only(left: 20, right: 84),
        textDirection: TextDirection.rtl,
      );
      expect(f.navigationEdge, FoldableNavigationEdge.right);
      expect(f.navigationWidth, 84);
    });
  });

  group('widgets', () {
    const landscape = Size(951, 669);
    const first = Key('first');
    const last = Key('last');
    const body = Key('body');
    const navKey = Key('primary_navigation_builder');
    EdgeInsets? seenPadding;
    BoxConstraints? seenConstraints;

    Future<void> pump(
      WidgetTester tester, {
      FakeViewPadding padding = const FakeViewPadding(right: 84, bottom: 35),
      List<DisplayFeature>? features,
      FoldableNavigationPlacement? placement,
      FoldableNavigationEdge? verticalBar = FoldableNavigationEdge.end,
      TextDirection direction = TextDirection.ltr,
      bool avoidCutouts = true,
      bool rail = false,
    }) async {
      seenPadding = null;
      seenConstraints = null;
      tester.view.physicalSize = landscape;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      tester.view.displayFeatures = features ?? [_cutout(867, 0, 951, 124)];
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Directionality(
            textDirection: direction,
            child: FoldableVerticalBarScope(
              edge: verticalBar,
              child: FoldableScaffold(
                avoidCutouts: avoidCutouts,
                appBar: AppBar(title: const Text('title')),
                navigationPlacement: placement == null
                    ? null
                    : (_) => placement,
                navigationBuilder: (context, p, constraints, insets) {
                  seenPadding = insets;
                  seenConstraints = constraints;
                  if (!p.isSide) return const SizedBox(height: 40);
                  if (rail) {
                    return NavigationRail(
                      selectedIndex: 0,
                      minWidth: constraints.maxWidth < 72
                          ? constraints.maxWidth
                          : 72,
                      groupAlignment: switch (p.alignment) {
                        FoldableNavigationAlignment.start => -1.0,
                        FoldableNavigationAlignment.center => 0.0,
                        FoldableNavigationAlignment.end => 1.0,
                      },
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.inbox, key: first),
                          label: Text('Inbox'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.send),
                          label: Text('Sent'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.star, key: last),
                          label: Text('Starred'),
                        ),
                      ],
                    );
                  }
                  // First at the top, last at the bottom, whatever the room.
                  return Column(
                    children: const [
                      Center(
                        child: SizedBox(key: first, width: 24, height: 24),
                      ),
                      Spacer(),
                      Center(child: SizedBox(key: last, width: 24, height: 24)),
                    ],
                  );
                },
                body: const SizedBox.expand(key: body),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Rect rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

    testWidgets(
      'the real iPhone Duo case: in the strip, in line, at the bottom',
      (tester) async {
        await pump(tester, rail: true);
        expect(tester.takeException(), isNull);

        expect(tester.getRect(find.byKey(navKey)).left, 867);
        expect(tester.getRect(find.byKey(navKey)).right, 951);
        expect(tester.getRect(find.byKey(navKey)).width, 84);
        expect(rect(tester, body).width, 951 - 84);
        expect(seenConstraints!.maxWidth, 84);
        // In line with the system icons (centre x 909).
        expect(rect(tester, first).center.dx, 909);
        expect(rect(tester, last).center.dx, 909);
        // At the bottom, over the home indicator.
        expect(rect(tester, last).bottom, lessThanOrEqualTo(669 - 35));
        expect(rect(tester, last).bottom, greaterThan(669 - 35 - 80));
        // Padding: the side is 0, the rest is the system's.
        expect(seenPadding, const EdgeInsets.only(bottom: 35));
      },
    );

    testWidgets(
      'a column fills the strip: first below the camera, last at the bottom',
      (tester) async {
        await pump(tester);
        expect(rect(tester, first).top, greaterThanOrEqualTo(124));
        expect(rect(tester, last).bottom, 669 - 35);
        expect(rect(tester, first).center.dx, 909);
      },
    );

    testWidgets('alignment start inside the strip still clears the camera', (
      tester,
    ) async {
      await pump(
        tester,
        placement: const FoldableNavigationPlacement.end(insideInset: true),
      );
      expect(rect(tester, first).top, greaterThanOrEqualTo(124));
      expect(rect(tester, first).center.dx, 909);
      // Start does not keep the home indicator off: the last item is lower.
      expect(rect(tester, last).bottom, 669);
    });

    testWidgets('the left edge with padding.left 48', (tester) async {
      await pump(
        tester,
        padding: const FakeViewPadding(left: 48, bottom: 35),
        features: [_cutout(0, 0, 48, 100)],
        verticalBar: FoldableNavigationEdge.left,
      );
      expect(tester.getRect(find.byKey(navKey)).left, 0);
      expect(tester.getRect(find.byKey(navKey)).width, 48);
      expect(rect(tester, body).left, 48);
      expect(rect(tester, first).center.dx, 24);
      expect(rect(tester, first).top, greaterThanOrEqualTo(100));
      expect(rect(tester, last).bottom, 669 - 35);
      expect(seenPadding, const EdgeInsets.only(bottom: 35));
    });

    testWidgets('RTL: start is on the right', (tester) async {
      await pump(
        tester,
        padding: const FakeViewPadding(left: 20, right: 84, bottom: 35),
        verticalBar: FoldableNavigationEdge.start,
        direction: TextDirection.rtl,
      );
      expect(tester.getRect(find.byKey(navKey)).width, 84);
      expect(rect(tester, first).center.dx, 909);
      expect(seenPadding, const EdgeInsets.only(left: 20, bottom: 35));
    });

    testWidgets('insideInset: false keeps the dev.8 layout', (tester) async {
      await pump(tester, placement: const FoldableNavigationPlacement.end());
      expect(tester.getRect(find.byKey(navKey)).right, 867);
      expect(tester.getRect(find.byKey(navKey)).width, 72);
      expect(rect(tester, body).width, 951 - 156);
      expect(rect(tester, first).center.dx, 867 - 36);
      expect(seenConstraints!.maxWidth, 72);
      expect(seenPadding, const EdgeInsets.only(bottom: 35));
      // Start alignment: no bottom inset added.
      expect(rect(tester, last).bottom, 669);
    });

    testWidgets('avoidCutouts: false only drops the cutout avoidance', (
      tester,
    ) async {
      await pump(tester, avoidCutouts: false);
      expect(tester.getRect(find.byKey(navKey)).width, 84);
      expect(rect(tester, first).center.dx, 909);
      // Still clear of the home indicator.
      expect(rect(tester, last).bottom, 669 - 35);
      // The camera is no longer avoided: the first item is at the top.
      expect(rect(tester, first).top, lessThan(124));
    });

    testWidgets('without a system inset the slot is the extent', (
      tester,
    ) async {
      await pump(tester, padding: FakeViewPadding.zero, features: const []);
      expect(tester.getRect(find.byKey(navKey)).width, 72);
      expect(seenPadding, EdgeInsets.zero);
    });
  });
}
