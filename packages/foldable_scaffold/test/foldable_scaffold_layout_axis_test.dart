import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter/widgets.dart' show Axis, EdgeInsets, TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_core/foldable_core.dart';
import 'package:foldable_scaffold/src/foldable_navigation.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';

const _window = Size(800, 1200);

DisplayFeature _horizontalHinge([Rect? bounds]) => DisplayFeature(
  bounds: bounds ?? const Rect.fromLTRB(0, 580, 800, 620),
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureFlat,
);

/// The pane area of the scaffold of an 800x1200 window, as measured: [top]
/// below the top of the window, [bottom] above its bottom.
Rect _area({double top = 0, double bottom = 0}) =>
    Rect.fromLTRB(0, top, 800, 1200 - bottom);

FrameGeometry _frame({
  List<DisplayFeature>? features,
  Rect? area,
  double scaffoldHeight = 1200,
  bool hasSecondaryBody = true,
  double minBodySize = 200,
  TextDirection textDirection = TextDirection.ltr,
  bool followFold = true,
}) {
  return computeFrameGeometry(
    scaffoldWidth: 800,
    scaffoldHeight: scaffoldHeight,
    paneAreaRect: area ?? _area(),
    windowSize: _window,
    // A narrow window on desktop breakpoints: the width alone would not split.
    breakpoints: const FoldableBreakpoints.desktop(),
    textDirection: textDirection,
    padding: EdgeInsets.zero,
    displayFeatures: features ?? [_horizontalHinge()],
    followFold: followFold,
    minBodySize: minBodySize,
    dividerSize: 24,
    placement: const FoldableNavigationPlacement.bottom(),
    minWidthNavigation: 72,
    maxWidthNavigation: 192,
    hasNavigation: false,
    hasSecondaryBody: hasSecondaryBody,
  );
}

PaneLayout _panes(
  FrameGeometry frame, {
  double totalHeight = 1200,
  bool hasSecondaryBody = true,
  bool isRtl = false,
  double minBodySize = 200,
}) {
  return computePaneLayout(
    axis: frame.paneAxis,
    totalExtent: frame.stacksAtFold ? totalHeight : 800,
    scaffoldExtent: 800,
    ratioSecondaryBody: 0.5,
    canSplitPanel: frame.canSplit && hasSecondaryBody,
    splitsAtFold: frame.splitsAtFold,
    foldStart: frame.foldStart,
    foldEnd: frame.foldEnd,
    isRtl: isRtl,
    minBodySize: minBodySize,
    dividerSize: 24,
    minSecondarySize: 200,
    maxSecondarySize: 576,
    focusOnPrimaryBody: false,
    hasSecondaryBody: hasSecondaryBody,
    isHoveringDivider: false,
  );
}

void main() {
  group('computeFrameGeometry: a horizontal hinge', () {
    test('stacks the panes when both sides are tall enough', () {
      final frame = _frame();

      expect(frame.fold?.isHorizontal, isTrue);
      expect(frame.stacksAtFold, isTrue);
      expect(frame.splitsAtFold, isTrue);
      expect(frame.canSplit, isTrue, reason: 'whatever the width');
      expect(frame.paneAxis, Axis.vertical);
      expect(frame.foldTop, 580);
      expect(frame.foldBottom, 620);
      expect(frame.paneAreaHeight, 1200);
      expect(frame.foldStart, 580);
      expect(frame.foldEnd, 620);
      // The vertical numbers stay out of the horizontal ones.
      expect(frame.foldLeft, 0);
      expect(frame.foldRight, 0);
    });

    test('the pane area starts where it was measured', () {
      // An app bar and a top navigation of 56 + 80 above the panes, a bottom
      // bar of 60 under them: the hinge is 136 higher in the pane area.
      final frame = _frame(area: _area(top: 136, bottom: 60));

      expect(frame.foldTop, 580 - 136);
      expect(frame.foldBottom, 620 - 136);
      expect(frame.paneAreaHeight, 1200 - 136 - 60);
      expect(frame.stacksAtFold, isTrue);
    });

    test('each side needs minBodySize, in height', () {
      // The top side is 199 tall.
      expect(
        _frame(
          features: [_horizontalHinge(const Rect.fromLTRB(0, 199, 800, 239))],
        ).stacksAtFold,
        isFalse,
      );
      expect(
        _frame(
          features: [_horizontalHinge(const Rect.fromLTRB(0, 200, 800, 240))],
        ).stacksAtFold,
        isTrue,
      );
      // The bottom side is 199 tall.
      expect(
        _frame(
          features: [_horizontalHinge(const Rect.fromLTRB(0, 961, 800, 1001))],
        ).stacksAtFold,
        isFalse,
      );
      expect(
        _frame(
          features: [_horizontalHinge(const Rect.fromLTRB(0, 960, 800, 1000))],
        ).stacksAtFold,
        isTrue,
      );
    });

    test('minBodySize is the one that decides, for the height too', () {
      final features = [
        _horizontalHinge(const Rect.fromLTRB(0, 300, 800, 340)),
      ];

      expect(_frame(features: features, minBodySize: 300).stacksAtFold, isTrue);
      expect(
        _frame(features: features, minBodySize: 301).stacksAtFold,
        isFalse,
      );
    });

    test('the app bar can leave too little room above the hinge', () {
      // The hinge is 580 down the window but the pane area starts 400 down.
      final frame = _frame(area: _area(top: 400));

      expect(frame.foldTop, 180);
      expect(frame.stacksAtFold, isFalse);
      expect(frame.paneAxis, Axis.horizontal);
      expect(frame.canSplit, isFalse, reason: 'back to the usual rule');
    });

    test('without a secondary body there is nothing to stack', () {
      final frame = _frame(hasSecondaryBody: false);

      expect(frame.stacksAtFold, isFalse);
      expect(frame.canSplit, isFalse);
    });

    test('an area that was not measured cannot stack', () {
      final frame = computeFrameGeometry(
        scaffoldWidth: 800,
        scaffoldHeight: 1200,
        windowSize: _window,
        breakpoints: const FoldableBreakpoints.desktop(),
        textDirection: TextDirection.ltr,
        padding: EdgeInsets.zero,
        displayFeatures: [_horizontalHinge()],
        followFold: true,
        minBodySize: 200,
        dividerSize: 24,
        placement: const FoldableNavigationPlacement.bottom(),
        minWidthNavigation: 72,
        maxWidthNavigation: 192,
        hasNavigation: false,
        hasSecondaryBody: true,
      );

      expect(frame.fold?.isHorizontal, isTrue);
      expect(frame.stacksAtFold, isFalse);
      expect(frame.paneAreaHeight, isNull);
    });

    test('a scaffold that is not as tall as the window ignores it', () {
      final frame = _frame(scaffoldHeight: 1100);

      expect(frame.fold, isNull);
      expect(frame.stacksAtFold, isFalse);
    });

    test('followFold: false ignores it', () {
      expect(_frame(followFold: false).fold, isNull);
    });

    test('a flat horizontal fold is ignored: the width decides', () {
      final features = [
        const DisplayFeature(
          bounds: Rect.fromLTRB(0, 600, 800, 600),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureFlat,
        ),
      ];
      final narrow = _frame(features: features);

      expect(narrow.fold, isNull);
      expect(narrow.canSplit, isFalse);
      expect(narrow.paneAxis, Axis.horizontal);
    });

    test('the direction does not matter to the stacking', () {
      final ltr = _frame();
      final rtl = _frame(textDirection: TextDirection.rtl);

      expect(rtl.stacksAtFold, ltr.stacksAtFold);
      expect(rtl.foldTop, ltr.foldTop);
      expect(rtl.foldBottom, ltr.foldBottom);
    });

    test('a vertical fold is what it was', () {
      final frame = _frame(
        features: [
          const DisplayFeature(
            bounds: Rect.fromLTRB(390, 0, 410, 1200),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );

      expect(frame.fold?.isVertical, isTrue);
      expect(frame.splitsAtFold, isTrue);
      expect(frame.stacksAtFold, isFalse);
      expect(frame.paneAxis, Axis.horizontal);
      expect(frame.foldLeft, 390);
      expect(frame.foldRight, 410);
      expect(frame.foldStart, 390);
      expect(frame.foldEnd, 410);
    });

    test('the first fold wins when there are both', () {
      const vertical = DisplayFeature(
        bounds: Rect.fromLTRB(390, 0, 410, 1200),
        type: DisplayFeatureType.hinge,
        state: DisplayFeatureState.postureFlat,
      );

      expect(
        _frame(features: [vertical, _horizontalHinge()]).paneAxis,
        Axis.horizontal,
      );
      expect(
        _frame(features: [_horizontalHinge(), vertical]).paneAxis,
        Axis.vertical,
      );
    });
  });

  group('computePaneLayout: along the vertical axis', () {
    test('the body is above the hinge, the secondary body below it', () {
      final layout = _panes(_frame());
      final geometry = layout.geometry;

      expect(geometry.axis, Axis.vertical);
      expect(geometry.primaryExtent, 580);
      expect(geometry.dividerExtent, 40);
      expect(geometry.secondaryExtent, 580);
      expect(layout.isSinglePane, isFalse);
    });

    test('measured from the pane area', () {
      final layout = _panes(
        _frame(area: _area(top: 136, bottom: 60)),
        totalHeight: 1004,
      );
      final geometry = layout.geometry;

      expect(geometry.primaryExtent, 444);
      expect(geometry.dividerExtent, 40);
      expect(geometry.secondaryExtent, 1004 - 484);
    });

    test('RTL does not flip it', () {
      final ltr = _panes(_frame());
      final rtl = _panes(_frame(textDirection: TextDirection.rtl), isRtl: true);

      expect(rtl.geometry.primaryExtent, ltr.geometry.primaryExtent);
      expect(rtl.geometry.secondaryExtent, ltr.geometry.secondaryExtent);
      expect(rtl.geometry.axis, Axis.vertical);
    });

    test('the sides of an uneven hinge keep their own size', () {
      final layout = _panes(
        _frame(
          features: [_horizontalHinge(const Rect.fromLTRB(0, 300, 800, 330))],
        ),
      );

      expect(layout.geometry.primaryExtent, 300);
      expect(layout.geometry.dividerExtent, 30);
      expect(layout.geometry.secondaryExtent, 870);
    });

    test('without a secondary body the body takes everything', () {
      final frame = _frame(hasSecondaryBody: false);
      final layout = _panes(frame, hasSecondaryBody: false);

      expect(layout.geometry.axis, Axis.horizontal);
      expect(layout.isSinglePane, isTrue);
      expect(layout.geometry.primaryExtent, 800);
      expect(layout.geometry.secondaryExtent, 0);
    });

    test('too little room: the usual single pane', () {
      final frame = _frame(
        features: [_horizontalHinge(const Rect.fromLTRB(0, 100, 800, 140))],
      );
      final layout = _panes(frame);

      expect(frame.stacksAtFold, isFalse);
      expect(layout.geometry.axis, Axis.horizontal);
      expect(layout.isSinglePane, isTrue);
      // The secondary body replaces the body when there is one pane.
      expect(layout.geometry.primaryExtent, 0);
      expect(layout.geometry.secondaryExtent, 800);
    });

    test('a collapsing side hands its room to the other pane', () {
      // Forced stacking with a stale fold: the top side is under minBodySize.
      final layout = computePaneLayout(
        axis: Axis.vertical,
        totalExtent: 1000,
        scaffoldExtent: 800,
        ratioSecondaryBody: 0.5,
        canSplitPanel: true,
        splitsAtFold: true,
        foldStart: 100,
        foldEnd: 140,
        isRtl: false,
        minBodySize: 200,
        dividerSize: 24,
        minSecondarySize: 200,
        maxSecondarySize: 576,
        focusOnPrimaryBody: false,
        hasSecondaryBody: true,
        isHoveringDivider: false,
      );

      expect(layout.geometry.primaryExtent, 0);
      expect(layout.geometry.dividerExtent, 0);
      expect(layout.geometry.secondaryExtent, 1000);
      expect(layout.primaryVisible, isFalse);
    });
  });

  group('PaneGeometryTween', () {
    const side = PaneGeometry(
      primaryExtent: 300,
      dividerExtent: 24,
      secondaryExtent: 476,
    );
    const stacked = PaneGeometry(
      primaryExtent: 580,
      dividerExtent: 40,
      secondaryExtent: 580,
      axis: Axis.vertical,
    );

    test('interpolates on one axis', () {
      const other = PaneGeometry(
        primaryExtent: 500,
        dividerExtent: 24,
        secondaryExtent: 276,
      );
      final tween = PaneGeometryTween(end: other)..begin = side;

      final half = tween.lerp(0.5);
      expect(half.axis, Axis.horizontal);
      expect(half.primaryExtent, 400);
      expect(half.secondaryExtent, 376);
    });

    test('snaps to the end when the axis changes', () {
      final tween = PaneGeometryTween(end: stacked)..begin = side;

      for (final t in [0.0, 0.3, 1.0]) {
        final value = tween.lerp(t);
        expect(value.axis, Axis.vertical);
        expect(value.primaryExtent, 580);
        expect(value.dividerExtent, 40);
        expect(value.secondaryExtent, 580);
      }
    });

    test('snaps back as well', () {
      final tween = PaneGeometryTween(end: side)..begin = stacked;

      expect(tween.lerp(0.4).axis, Axis.horizontal);
      expect(tween.lerp(0.4).primaryExtent, 300);
    });
  });
}
