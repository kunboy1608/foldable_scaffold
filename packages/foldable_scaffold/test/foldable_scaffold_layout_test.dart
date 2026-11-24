import 'dart:ui'
    show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Rect, Size;

import 'package:flutter/widgets.dart' show EdgeInsets, TextDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_scaffold/src/foldable_breakpoints.dart';
import 'package:foldable_scaffold/src/foldable_navigation.dart';
import 'package:foldable_scaffold/src/foldable_scaffold_layout.dart';

DisplayFeature hinge(double left, double right, double height) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(left, 0, right, height),
    type: DisplayFeatureType.hinge,
    state: DisplayFeatureState.postureFlat,
  );
}

DisplayFeature foldFeature(
  double x,
  double height, {
  DisplayFeatureState state = DisplayFeatureState.postureFlat,
}) {
  return DisplayFeature(
    bounds: Rect.fromLTRB(x, 0, x, height),
    type: DisplayFeatureType.fold,
    state: state,
  );
}

/// [computeFrameGeometry] with the defaults of the scaffold (72/192 rail, 200
/// min pane, 24 divider, no navigation slot unless said otherwise).
FrameGeometry frameOf(
  Size size, {
  FoldableBreakpoints breakpoints = const FoldableBreakpoints.desktop(),
  TextDirection textDirection = TextDirection.ltr,
  EdgeInsets padding = EdgeInsets.zero,
  List<DisplayFeature> features = const [],
  bool followFold = true,
  double minBodySize = 200,
  double dividerSize = 24,
  double minWidthNavigation = 72,
  double maxWidthNavigation = 192,
  bool hasPrimaryNavigation = false,
  bool hasSecondaryBody = true,
  Size? windowSize,
  FoldableNavigationPlacement? placement,
}) {
  return computeFrameGeometry(
    scaffoldWidth: size.width,
    windowSize: windowSize ?? size,
    breakpoints: breakpoints,
    textDirection: textDirection,
    padding: padding,
    displayFeatures: features,
    followFold: followFold,
    minBodySize: minBodySize,
    dividerSize: dividerSize,
    placement:
        placement ??
        (size.width >= breakpoints.rail
            ? const FoldableNavigationPlacement.start()
            : const FoldableNavigationPlacement.bottom()),
    minWidthNavigation: minWidthNavigation,
    maxWidthNavigation: maxWidthNavigation,
    hasNavigation: hasPrimaryNavigation,
    hasSecondaryBody: hasSecondaryBody,
  );
}

/// [computePaneLayout] with the usual defaults. The min/max secondary sizes
/// come from [totalWidth] and [minBodySize], as the scaffold computes them.
PaneLayout panesOf({
  required double totalWidth,
  double? scaffoldWidth,
  double ratioSecondaryBody = 0.5,
  bool canSplitPanel = true,
  bool splitsAtFold = false,
  double foldLeft = 0,
  double foldRight = 0,
  bool isRtl = false,
  double minBodySize = 200,
  double dividerSize = 24,
  bool focusOnPrimaryBody = false,
  bool hasSecondaryBody = true,
  bool isHoveringDivider = false,
}) {
  final splitWidth = (totalWidth - dividerSize).clamp(0.0, double.infinity);
  final minPaneSize = minBodySize < splitWidth / 2
      ? minBodySize
      : splitWidth / 2;
  return computePaneLayout(
    totalExtent: totalWidth,
    scaffoldExtent: scaffoldWidth ?? totalWidth,
    ratioSecondaryBody: ratioSecondaryBody,
    canSplitPanel: canSplitPanel,
    splitsAtFold: splitsAtFold,
    foldStart: foldLeft,
    foldEnd: foldRight,
    isRtl: isRtl,
    minBodySize: minBodySize,
    dividerSize: dividerSize,
    minSecondarySize: minPaneSize,
    maxSecondarySize: splitWidth - minPaneSize,
    focusOnPrimaryBody: focusOnPrimaryBody,
    hasSecondaryBody: hasSecondaryBody,
    isHoveringDivider: isHoveringDivider,
  );
}

void main() {
  group('computeFrameGeometry: breakpoints', () {
    test('desktop splits from exactly 1200', () {
      expect(frameOf(const Size(1199, 600)).canSplit, isFalse);
      expect(frameOf(const Size(1200, 600)).canSplit, isTrue);
      expect(frameOf(const Size(1400, 600)).canSplit, isTrue);
      // A tall window does not help on desktop: only the width counts.
      expect(frameOf(const Size(800, 1300)).canSplit, isFalse);
    });

    test('handheld needs the width and the short side of the window', () {
      const handheld = FoldableBreakpoints.handheld();

      // Inner screen of a foldable or a tablet: 600 wide, 600 on its short side.
      expect(
        frameOf(const Size(635, 841), breakpoints: handheld).canSplit,
        isTrue,
      );
      expect(
        frameOf(const Size(800, 1280), breakpoints: handheld).canSplit,
        isTrue,
      );
      // A phone, even held sideways, and a narrow window of a tablet.
      expect(
        frameOf(const Size(360, 800), breakpoints: handheld).canSplit,
        isFalse,
      );
      expect(
        frameOf(const Size(900, 400), breakpoints: handheld).canSplit,
        isFalse,
      );
      expect(
        frameOf(const Size(500, 1200), breakpoints: handheld).canSplit,
        isFalse,
      );
    });
  });

  group('computeFrameGeometry: navigation rail', () {
    test('takes the narrow width from rail and the wide one from wideRail', () {
      expect(frameOf(const Size(500, 600)).navigationWidth, 0);
      expect(frameOf(const Size(800, 600)).navigationWidth, 72);
      expect(frameOf(const Size(1500, 600)).navigationWidth, 192);
    });

    test('reserves no room without a navigation slot', () {
      final frame = frameOf(const Size(1400, 600));
      expect(frame.navigationWidth, 192);
      expect(frame.railWidth, 0);
      expect(frame.paneAreaWidth, 1400);
    });

    test('the rail takes the pane area from the left in LTR', () {
      final frame = frameOf(const Size(1400, 600), hasPrimaryNavigation: true);
      expect(frame.railWidth, 192);
      expect(frame.paneAreaWidth, 1400 - 192);
    });

    test('the rail takes the start-side inset in RTL', () {
      final frame = frameOf(
        const Size(900, 600),
        textDirection: TextDirection.rtl,
        padding: const EdgeInsets.only(right: 44),
        hasPrimaryNavigation: true,
      );
      expect(frame.isRtl, isTrue);
      expect(frame.navigationWidth, closeTo(72 + 44, 0.01));
      expect(frame.railWidth, closeTo(116, 0.01));
      expect(frame.paneAreaWidth, closeTo(900 - 116, 0.01));
    });
  });

  group('computeFrameGeometry: folds', () {
    test('a fold needs the scaffold to span the window', () {
      final frame = frameOf(
        const Size(600, 700),
        windowSize: const Size(1000, 700),
        features: [hinge(480, 520, 700)],
      );
      expect(frame.fold, isNull);
      expect(frame.splitsAtFold, isFalse);
      expect(frame.foldSecondaryRatio, isNull);
    });

    test('a separating hinge splits the panes at it', () {
      final frame = frameOf(
        const Size(1000, 700),
        features: [hinge(480, 520, 700)],
      );
      expect(frame.fold, isNotNull);
      expect(frame.fold!.isSeparating, isTrue);
      expect(frame.foldLeft, closeTo(480, 0.01));
      expect(frame.foldRight, closeTo(520, 0.01));
      expect(frame.splitsAtFold, isTrue);
      // A separating fold splits even where the breakpoints would not.
      expect(frame.canSplit, isTrue);
    });

    test('a hinge too close to an edge does not split', () {
      final frame = frameOf(
        const Size(1000, 700),
        features: [hinge(100, 140, 700)],
      );
      // The left side would be 100 wide, under minBodySize.
      expect(frame.foldLeft, closeTo(100, 0.01));
      expect(frame.splitsAtFold, isFalse);
      expect(frame.canSplit, isFalse);
    });

    test('a flat fold only gives the starting ratio of the divider', () {
      final frame = frameOf(
        const Size(1400, 800),
        features: [foldFeature(900, 800)],
      );
      expect(frame.fold!.isSeparating, isFalse);
      expect(frame.splitsAtFold, isFalse);
      expect(frame.foldSecondaryRatio, closeTo(488 / 1400, 0.0001));
    });

    test('the flat fold ratio is mirrored in RTL', () {
      final frame = frameOf(
        const Size(1400, 800),
        textDirection: TextDirection.rtl,
        features: [foldFeature(900, 800)],
      );
      expect(frame.foldSecondaryRatio, closeTo(888 / 1400, 0.0001));
    });

    test('followFold false ignores the fold', () {
      final frame = frameOf(
        const Size(1000, 700),
        features: [hinge(480, 520, 700)],
        followFold: false,
      );
      expect(frame.fold, isNull);
      expect(frame.splitsAtFold, isFalse);
    });
  });

  group('computePaneLayout: two panes', () {
    test('splits the pane area around the divider at the ratio', () {
      final layout = panesOf(totalWidth: 1200);
      expect(layout.geometry.primaryExtent, closeTo(576, 0.01));
      expect(layout.geometry.dividerExtent, closeTo(24, 0.01));
      expect(layout.geometry.secondaryExtent, closeTo(600, 0.01));
      expect(layout.isSinglePane, isFalse);
      expect(layout.primaryVisible, isTrue);
      expect(layout.secondaryVisible, isTrue);
    });

    test('the ratio is relative to the scaffold width, not the pane area', () {
      // 1400 scaffold wide, 192 of rail: the panes share 1208.
      final layout = panesOf(totalWidth: 1208, scaffoldWidth: 1400);
      expect(layout.geometry.secondaryExtent, closeTo(700, 0.01));
      expect(layout.geometry.primaryExtent, closeTo(484, 0.01));
      expect(layout.geometry.dividerExtent, closeTo(24, 0.01));
    });

    test('a flat fold starts the divider on the crease in LTR', () {
      final layout = panesOf(
        totalWidth: 1400,
        scaffoldWidth: 1400,
        ratioSecondaryBody: 488 / 1400,
      );
      expect(layout.geometry.primaryExtent, closeTo(888, 0.01));
      expect(layout.geometry.dividerExtent, closeTo(24, 0.01));
      expect(layout.geometry.secondaryExtent, closeTo(488, 0.01));
    });

    test('a flat fold starts the divider on the crease in RTL', () {
      final layout = panesOf(
        totalWidth: 1400,
        scaffoldWidth: 1400,
        ratioSecondaryBody: 888 / 1400,
        isRtl: true,
      );
      expect(layout.geometry.primaryExtent, closeTo(488, 0.01));
      expect(layout.geometry.dividerExtent, closeTo(24, 0.01));
      expect(layout.geometry.secondaryExtent, closeTo(888, 0.01));
    });

    test('a separating fold gives each side its own width', () {
      final ltr = panesOf(
        totalWidth: 1000,
        splitsAtFold: true,
        foldLeft: 480,
        foldRight: 520,
      );
      expect(ltr.geometry.primaryExtent, closeTo(480, 0.01));
      expect(ltr.geometry.dividerExtent, closeTo(40, 0.01));
      expect(ltr.geometry.secondaryExtent, closeTo(480, 0.01));

      // In RTL the body is on the right, the secondary body on the left.
      final rtl = panesOf(
        totalWidth: 1000,
        splitsAtFold: true,
        foldLeft: 400,
        foldRight: 460,
        isRtl: true,
      );
      expect(rtl.geometry.primaryExtent, closeTo(540, 0.01));
      expect(rtl.geometry.dividerExtent, closeTo(60, 0.01));
      expect(rtl.geometry.secondaryExtent, closeTo(400, 0.01));
    });
  });

  group('computePaneLayout: collapsing panes', () {
    test('a pane under minBodySize gives its room to the other', () {
      // Two panes of 800 do not fit in 1400, so the body gives way.
      final layout = panesOf(totalWidth: 1400, minBodySize: 800);
      expect(layout.geometry.primaryExtent, 0);
      expect(layout.geometry.dividerExtent, 0);
      expect(layout.geometry.secondaryExtent, closeTo(1400, 0.01));
      expect(layout.isSinglePane, isTrue);
      expect(layout.primaryVisible, isFalse);
      expect(layout.secondaryVisible, isTrue);
    });

    test('while dragging the divider a narrow pane does not collapse', () {
      // The window only holds panes of 138 each, under minBodySize; while the
      // user drags, neither pane collapses.
      final layout = panesOf(
        totalWidth: 300,
        scaffoldWidth: 300,
        ratioSecondaryBody: 0.5,
        isHoveringDivider: true,
      );
      expect(layout.geometry.primaryExtent, closeTo(138, 0.01));
      expect(layout.geometry.dividerExtent, closeTo(24, 0.01));
      expect(layout.geometry.secondaryExtent, closeTo(138, 0.01));
      expect(layout.primaryVisible, isTrue);
      expect(layout.secondaryVisible, isTrue);
      expect(layout.isSinglePane, isFalse);
    });

    test('a window narrower than two minBodySize panes shows one pane', () {
      // Same geometry, but released: the primary pane collapses.
      final layout = panesOf(
        totalWidth: 300,
        scaffoldWidth: 300,
        ratioSecondaryBody: 0.5,
      );
      expect(layout.geometry.primaryExtent, 0);
      expect(layout.geometry.dividerExtent, 0);
      expect(layout.geometry.secondaryExtent, closeTo(300, 0.01));
      expect(layout.isSinglePane, isTrue);
      expect(layout.primaryVisible, isFalse);
      expect(layout.secondaryVisible, isTrue);
    });
  });

  group('computePaneLayout: one pane', () {
    test('shows the secondary body alone below the split width', () {
      final layout = panesOf(totalWidth: 800, canSplitPanel: false);
      expect(layout.geometry.primaryExtent, 0);
      expect(layout.geometry.dividerExtent, 0);
      expect(layout.geometry.secondaryExtent, closeTo(800, 0.01));
      expect(layout.isSinglePane, isTrue);
      expect(layout.primaryVisible, isFalse);
      expect(layout.secondaryVisible, isTrue);
    });

    test('focusOnPrimaryBody keeps the body instead', () {
      final layout = panesOf(
        totalWidth: 800,
        canSplitPanel: false,
        focusOnPrimaryBody: true,
      );
      expect(layout.geometry.primaryExtent, closeTo(800, 0.01));
      expect(layout.geometry.dividerExtent, 0);
      expect(layout.geometry.secondaryExtent, 0);
      expect(layout.isSinglePane, isTrue);
      expect(layout.primaryVisible, isTrue);
      expect(layout.secondaryVisible, isFalse);
    });

    test('without a secondary body the body takes the width', () {
      final layout = panesOf(
        totalWidth: 800,
        canSplitPanel: false,
        hasSecondaryBody: false,
      );
      expect(layout.geometry.primaryExtent, closeTo(800, 0.01));
      expect(layout.geometry.secondaryExtent, 0);
      expect(layout.primaryVisible, isTrue);
      expect(layout.secondaryVisible, isFalse);
    });
  });

  group('computeSnapTarget', () {
    test('snaps the secondary body to a width near the release', () {
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 380,
          snapWidths: const [360],
          snapThreshold: 32,
        ),
        360,
      );
    });

    test('the body snaps too, whichever pane is nearer', () {
      // A 360 wide body leaves 1376 - 360 = 1016 to the secondary body.
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 1016,
          snapWidths: const [360],
          snapThreshold: 32,
        ),
        1016,
      );
    });

    test('the threshold is inclusive', () {
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 392,
          snapWidths: const [360],
          snapThreshold: 32,
        ),
        360,
      );
    });

    test('a release far from every width does not snap', () {
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 650,
          snapWidths: const [360, 412],
          snapThreshold: 32,
        ),
        isNull,
      );
    });

    test('a width outside the pane bounds is skipped', () {
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 210,
          snapWidths: const [100],
          snapThreshold: 32,
        ),
        isNull,
      );
    });

    test('does nothing without widths', () {
      expect(
        computeSnapTarget(
          screenWidth: 1400,
          splitWidth: 1376,
          minSecondarySize: 200,
          maxSecondarySize: 1176,
          currentSecondarySize: 380,
          snapWidths: const [],
          snapThreshold: 32,
        ),
        isNull,
      );
      expect(
        computeSnapTarget(
          screenWidth: 0,
          splitWidth: 0,
          minSecondarySize: 0,
          maxSecondarySize: 0,
          currentSecondarySize: 0,
          snapWidths: const [360],
          snapThreshold: 32,
        ),
        isNull,
      );
    });
  });

  group('computeKeyboardSecondarySize', () {
    double step({
      double current = 500,
      int direction = -1,
      double pixels = 16,
      bool isRtl = false,
      double min = 200,
      double max = 800,
    }) {
      return computeKeyboardSecondarySize(
        currentSecondarySize: current,
        direction: direction,
        step: pixels,
        isRtl: isRtl,
        minSecondarySize: min,
        maxSecondarySize: max,
      );
    }

    test('follows the drag: left grows the secondary pane in LTR', () {
      expect(step(), 516);
      expect(step(direction: 1), 484);
    });

    test(
      'follows the drag in RTL, where the secondary pane is on the left',
      () {
        expect(step(isRtl: true), 484);
        expect(step(direction: 1, isRtl: true), 516);
      },
    );

    test('stays within the range of the divider', () {
      expect(step(current: 795), 800);
      expect(step(current: 205, direction: 1), 200);
      expect(step(current: 795, pixels: 64), 800);
    });

    test('a bigger step goes further, and clamps the same way', () {
      expect(step(pixels: 64), 564);
      expect(step(current: 790, pixels: 64), 800);
    });
  });

  group('computeSecondaryPanePercent', () {
    test('is the share of the pane area, in percent', () {
      expect(
        computeSecondaryPanePercent(secondarySize: 500, splitWidth: 1000),
        50,
      );
      expect(
        computeSecondaryPanePercent(secondarySize: 360, splitWidth: 1000),
        36,
      );
      expect(
        computeSecondaryPanePercent(secondarySize: 700, splitWidth: 1376),
        51,
      );
    });

    test('is zero when there is no pane area', () {
      expect(computeSecondaryPanePercent(secondarySize: 0, splitWidth: 0), 0);
    });
  });
}
