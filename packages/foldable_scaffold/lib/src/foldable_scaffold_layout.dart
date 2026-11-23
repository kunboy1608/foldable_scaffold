import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';

import 'foldable_breakpoints.dart';
import 'foldable_fold.dart';

/// The result of the "outer frame" layout step: what the scaffold's width,
/// the window, the breakpoints, the text direction, the padding and the
/// display features imply about the navigation rail, the pane area and a
/// separating fold.
///
/// Pure: no [BuildContext], widget or state, so it can be tested without
/// pumping a widget.
class FrameGeometry {
  const FrameGeometry({
    required this.scaffoldWidth,
    required this.navigationWidth,
    required this.railWidth,
    required this.paneAreaWidth,
    required this.textDirection,
    required this.fold,
    required this.foldLeft,
    required this.foldRight,
    required this.splitsAtFold,
    required this.foldSecondaryRatio,
    required this.hasSecondaryBody,
    required this.canSplit,
  });

  /// The full width of the scaffold (the [LayoutBuilder] constraint).
  final double scaffoldWidth;

  /// The width the navigation rail would take, including the start-side inset.
  final double navigationWidth;

  /// What the rail really takes: zero without a navigation slot.
  final double railWidth;

  /// The width left for the two panes and the divider.
  final double paneAreaWidth;

  final TextDirection textDirection;

  /// Whether the text direction is right-to-left.
  bool get isRtl => textDirection == TextDirection.rtl;

  /// The vertical fold or hinge, or null when it does not apply.
  final FoldableFold? fold;

  /// The fold's left edge in pane coordinates (after the rail).
  final double foldLeft;

  /// The fold's right edge in pane coordinates (after the rail).
  final double foldRight;

  /// Whether the fold separates the screen into two usable panes.
  final bool splitsAtFold;

  /// Where a divider on a flat fold would put the secondary pane, relative to
  /// the scaffold width, or null when there is no flat fold to start from.
  final double? foldSecondaryRatio;

  /// Whether the secondary body is shown at all.
  final bool hasSecondaryBody;

  /// Whether the scaffold may show two panes (wide enough, or splitting at
  /// a fold).
  final bool canSplit;
}

/// The "outer frame" of the layout: from the scaffold width, the window, the
/// breakpoints, the text direction, the padding and the display features to
/// the navigation width, the pane area width and the fold state.
///
/// Does not depend on [BuildContext], a widget or the scaffold state, so it
/// can be tested without pumping a widget.
FrameGeometry computeFrameGeometry({
  required double scaffoldWidth,
  required Size windowSize,
  required FoldableBreakpoints breakpoints,
  required TextDirection textDirection,
  required EdgeInsets padding,
  required List<DisplayFeature> displayFeatures,
  required bool followFold,
  required double minBodySize,
  required double dividerSize,
  required double minWidthNavigation,
  required double maxWidthNavigation,
  required bool hasPrimaryNavigation,
  required bool hasSecondaryBody,
}) {
  final isRtl = textDirection == TextDirection.rtl;
  final isMediumSize = scaffoldWidth >= breakpoints.rail;
  final isMediumLargeSize = breakpoints.canSplit(scaffoldWidth, windowSize);

  // The rail sits on the start side of the window, so it adds the system
  // inset on that side (left in LTR, right in RTL).
  final startPadding = isRtl ? padding.right : padding.left;
  final navigationWidth = scaffoldWidth > breakpoints.wideRail
      ? maxWidthNavigation + startPadding
      : isMediumSize
      ? minWidthNavigation + startPadding
      : 0.0;
  // What the navigation really takes: nothing without a slot.
  final railWidth = !hasPrimaryNavigation ? 0.0 : navigationWidth;
  final paneAreaWidth = scaffoldWidth - railWidth;

  // The fold is in window coordinates: it only means something to a scaffold
  // that spans the window.
  final fold = followFold && (scaffoldWidth - windowSize.width).abs() < 1
      ? FoldableFold.fromFeatures(displayFeatures, windowSize)
      : null;

  // The pane area starts at the physical left edge, unless the rail is on
  // the left (LTR): in RTL the rail is on the right edge.
  final paneStartInPaneSpace = isRtl ? 0.0 : railWidth;
  final foldLeft = fold == null ? 0.0 : fold.bounds.left - paneStartInPaneSpace;
  final foldRight = fold == null
      ? 0.0
      : fold.bounds.right - paneStartInPaneSpace;

  // One pane on each side of a fold that cuts the screen, as long as both are
  // big enough to be useful.
  final splitsAtFold =
      fold != null &&
      fold.isSeparating &&
      foldLeft >= minBodySize &&
      paneAreaWidth - foldRight >= minBodySize;

  // Where the secondary pane ends up if the divider sits on a flat fold.
  // The secondary pane sits on the trailing side: left in RTL, right in LTR.
  final foldSecondaryRatio = fold == null || fold.isSeparating
      ? null
      : (isRtl
                ? fold.center - dividerSize / 2
                : scaffoldWidth - fold.center - dividerSize / 2) /
            scaffoldWidth;

  return FrameGeometry(
    scaffoldWidth: scaffoldWidth,
    navigationWidth: navigationWidth,
    railWidth: railWidth,
    paneAreaWidth: paneAreaWidth,
    textDirection: textDirection,
    fold: fold,
    foldLeft: foldLeft,
    foldRight: foldRight,
    splitsAtFold: splitsAtFold,
    foldSecondaryRatio: foldSecondaryRatio,
    hasSecondaryBody: hasSecondaryBody,
    canSplit: isMediumLargeSize || splitsAtFold,
  );
}

/// The result of the "pane geometry" step: the primary pane, the divider and
/// the secondary pane widths, plus whether the layout shows one or two panes.
///
/// Pure: no [BuildContext], widget or state, so it can be tested without
/// pumping a widget.
class PaneLayout {
  const PaneLayout({
    required this.geometry,
    required this.isSinglePane,
    required this.primaryVisible,
    required this.secondaryVisible,
  });

  final PaneGeometry geometry;
  final bool isSinglePane;
  final bool primaryVisible;
  final bool secondaryVisible;
}

/// The width of the primary pane, the divider and the secondary pane, after
/// the collapse rules have been applied.
class PaneGeometry {
  const PaneGeometry({
    required this.primaryWidth,
    required this.dividerWidth,
    required this.secondaryWidth,
  });

  final double primaryWidth;
  final double dividerWidth;
  final double secondaryWidth;

  /// Whether the primary pane has room.
  ///
  /// A pane of zero width is hidden: it is still laid out (so its state
  /// survives) but nothing of it is seen. The [FoldableScaffold] reads this on
  /// the *animated* geometry, so a pane that is sliding in or out (width
  /// between zero and its target) still counts as visible until the animation
  /// ends.
  bool get primaryVisible => primaryWidth > 0;

  /// Whether the secondary pane has room. See [primaryVisible].
  bool get secondaryVisible => secondaryWidth > 0;
}

/// The "pane geometry" of the layout: from the pane area width, the divider
/// ratio, the drag/hover state and the fold to the width of each pane.
///
/// Does not depend on [BuildContext], a widget or the scaffold state, so it
/// can be tested without pumping a widget.
PaneLayout computePaneLayout({
  required double totalWidth,
  required double scaffoldWidth,
  required double ratioSecondaryBody,
  required bool canSplitPanel,
  required bool splitsAtFold,
  required double foldLeft,
  required double foldRight,
  required bool isRtl,
  required double minBodySize,
  required double dividerSize,
  required double minSecondarySize,
  required double maxSecondarySize,
  required bool focusOnPrimaryBody,
  required bool hasSecondaryBody,
  required bool isHoveringDivider,
}) {
  final splitWidth = (totalWidth - dividerSize).clamp(0.0, double.infinity);

  double secondaryTargetWidth = 0.0;
  double primaryTargetWidth = totalWidth;
  double dividerTargetWidth = 0.0;

  if (canSplitPanel && splitsAtFold) {
    // Around the hinge: its area is the divider.
    // In RTL the body is on the right, the secondary body on the left.
    if (isRtl) {
      primaryTargetWidth = totalWidth - foldRight;
      secondaryTargetWidth = foldLeft;
    } else {
      primaryTargetWidth = foldLeft;
      secondaryTargetWidth = totalWidth - foldRight;
    }
    dividerTargetWidth = foldRight - foldLeft;
  } else if (canSplitPanel) {
    // The window may have been resized since the ratio was stored.
    secondaryTargetWidth = (ratioSecondaryBody * scaffoldWidth).clamp(
      minSecondarySize,
      maxSecondarySize,
    );
    dividerTargetWidth = dividerSize;
    primaryTargetWidth = splitWidth - secondaryTargetWidth;
  } else {
    if (!focusOnPrimaryBody && hasSecondaryBody) {
      secondaryTargetWidth = totalWidth;
      primaryTargetWidth = 0.0;
    } else {
      secondaryTargetWidth = 0.0;
      primaryTargetWidth = totalWidth;
    }
  }

  // A collapsed pane gives its room, and the divider's, to the other one.
  if (!isHoveringDivider) {
    if (primaryTargetWidth < minBodySize) {
      secondaryTargetWidth += primaryTargetWidth + dividerTargetWidth;
      primaryTargetWidth = 0;
      dividerTargetWidth = 0;
    }

    if (secondaryTargetWidth < minBodySize) {
      primaryTargetWidth += secondaryTargetWidth + dividerTargetWidth;
      secondaryTargetWidth = 0;
      dividerTargetWidth = 0;
    }
  }

  final geometry = PaneGeometry(
    primaryWidth: primaryTargetWidth.clamp(0.0, totalWidth),
    dividerWidth: dividerTargetWidth.clamp(0.0, totalWidth),
    secondaryWidth: secondaryTargetWidth.clamp(0.0, totalWidth),
  );

  final primaryVisible = geometry.primaryVisible;
  final secondaryVisible = geometry.secondaryVisible;
  final isSinglePane = !primaryVisible || !secondaryVisible;

  return PaneLayout(
    geometry: geometry,
    isSinglePane: isSinglePane,
    primaryVisible: primaryVisible,
    secondaryVisible: secondaryVisible,
  );
}

/// The width the secondary pane should snap to when the divider is released,
/// or null when there is no snap target within [snapThreshold].
///
/// Either pane can snap: [splitWidth] minus a candidate width is the width
/// the secondary pane would have if the primary pane took that width.
///
/// Pure: no [BuildContext], widget or state.
double? computeSnapTarget({
  required double screenWidth,
  required double splitWidth,
  required double minSecondarySize,
  required double maxSecondarySize,
  required double currentSecondarySize,
  required List<double> snapWidths,
  required double snapThreshold,
}) {
  if (snapWidths.isEmpty || screenWidth <= 0) return null;
  final secondary = currentSecondarySize.clamp(
    minSecondarySize,
    maxSecondarySize,
  );
  double? best;
  var bestDistance = snapThreshold;
  for (final width in snapWidths) {
    // The secondary body takes the width, or the body does.
    for (final candidate in [width, splitWidth - width]) {
      if (candidate < minSecondarySize || candidate > maxSecondarySize) {
        continue;
      }
      final distance = (secondary - candidate).abs();
      if (distance <= bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
  }
  return best;
}

/// The size of the secondary pane after the divider is moved by one keyboard
/// step of [step] logical pixels in the physical [direction] (-1 towards the
/// left of the screen, 1 towards the right), clamped to the range of the
/// divider.
///
/// The arrow keys follow the mouse: in [TextDirection.rtl] the secondary pane
/// is on the left, so an arrow to the left makes it narrower, exactly as
/// dragging the divider to the left does.
///
/// Pure: no [BuildContext], widget or state.
double computeKeyboardSecondarySize({
  required double currentSecondarySize,
  required int direction,
  required double step,
  required bool isRtl,
  required double minSecondarySize,
  required double maxSecondarySize,
}) {
  // The same sign as a pointer drag: a pointer moving right is a positive
  // delta, which grows the secondary pane in RTL and shrinks it in LTR.
  final signedDelta = isRtl ? direction * step : -direction * step;
  return (currentSecondarySize + signedDelta).clamp(
    minSecondarySize,
    maxSecondarySize,
  );
}

/// The share of the pane area taken by the secondary pane, in percent, as a
/// screen reader reads it: 50 when the two panes are as wide.
///
/// Pure: no [BuildContext], widget or state.
int computeSecondaryPanePercent({
  required double secondarySize,
  required double splitWidth,
}) {
  if (splitWidth <= 0) return 0;
  final percent = (secondarySize / splitWidth * 100).round();
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

/// Animates between two [PaneGeometry] values.
class PaneGeometryTween extends Tween<PaneGeometry> {
  PaneGeometryTween({required PaneGeometry end}) : super(end: end);

  @override
  PaneGeometry lerp(double t) {
    final beginValue = begin ?? end!;
    final endValue = end!;
    return PaneGeometry(
      primaryWidth:
          beginValue.primaryWidth +
          (endValue.primaryWidth - beginValue.primaryWidth) * t,
      dividerWidth:
          beginValue.dividerWidth +
          (endValue.dividerWidth - beginValue.dividerWidth) * t,
      secondaryWidth:
          beginValue.secondaryWidth +
          (endValue.secondaryWidth - beginValue.secondaryWidth) * t,
    );
  }
}

/// Positions the primary pane, the divider and the secondary pane side by
/// side, left to right in [TextDirection.ltr] and right to left in
/// [TextDirection.rtl].
class FoldablePaneLayoutDelegate extends MultiChildLayoutDelegate {
  FoldablePaneLayoutDelegate({
    required this.geometry,
    required this.textDirection,
  });

  final PaneGeometry geometry;
  final TextDirection textDirection;

  @override
  void performLayout(Size size) {
    final totalTargetWidth =
        geometry.primaryWidth + geometry.dividerWidth + geometry.secondaryWidth;
    final scale = totalTargetWidth > size.width && totalTargetWidth > 0
        ? size.width / totalTargetWidth
        : 1.0;

    final primaryWidth = geometry.primaryWidth * scale;
    final dividerWidth = geometry.dividerWidth * scale;
    final secondaryWidth = geometry.secondaryWidth * scale;

    // Children are laid out from the start edge: left in LTR, right in RTL.
    var xOffset = textDirection == TextDirection.rtl ? size.width : 0.0;

    if (hasChild(PaneSlot.primary)) {
      layoutChild(
        PaneSlot.primary,
        BoxConstraints.tightFor(width: primaryWidth, height: size.height),
      );
      if (textDirection == TextDirection.rtl) {
        xOffset -= primaryWidth;
        positionChild(PaneSlot.primary, Offset(xOffset, 0));
      } else {
        positionChild(PaneSlot.primary, Offset(xOffset, 0));
        xOffset += primaryWidth;
      }
    }

    if (hasChild(PaneSlot.divider)) {
      layoutChild(
        PaneSlot.divider,
        BoxConstraints.tightFor(width: dividerWidth, height: size.height),
      );
      if (textDirection == TextDirection.rtl) {
        xOffset -= dividerWidth;
        positionChild(PaneSlot.divider, Offset(xOffset, 0));
      } else {
        positionChild(PaneSlot.divider, Offset(xOffset, 0));
        xOffset += dividerWidth;
      }
    }

    if (hasChild(PaneSlot.secondary)) {
      layoutChild(
        PaneSlot.secondary,
        BoxConstraints.tightFor(width: secondaryWidth, height: size.height),
      );
      if (textDirection == TextDirection.rtl) {
        xOffset -= secondaryWidth;
        positionChild(PaneSlot.secondary, Offset(xOffset, 0));
      } else {
        positionChild(PaneSlot.secondary, Offset(xOffset, 0));
        xOffset += secondaryWidth;
      }
    }
  }

  @override
  bool shouldRelayout(covariant FoldablePaneLayoutDelegate oldDelegate) {
    return geometry.primaryWidth != oldDelegate.geometry.primaryWidth ||
        geometry.dividerWidth != oldDelegate.geometry.dividerWidth ||
        geometry.secondaryWidth != oldDelegate.geometry.secondaryWidth;
  }
}

enum PaneSlot { primary, divider, secondary }
