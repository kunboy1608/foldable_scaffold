import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:foldable_core/foldable_core.dart' show FoldablePaneRects;

import 'foldable_breakpoints.dart';
import 'foldable_fold.dart';
import 'foldable_navigation.dart';

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
    required this.placement,
    required this.navigationEdge,
    required this.navigationWidth,
    required this.railWidth,
    required this.paneAreaWidth,
    required this.textDirection,
    required this.fold,
    required this.foldLeft,
    required this.foldRight,
    required this.foldTop,
    required this.foldBottom,
    required this.paneAreaHeight,
    required this.splitsAtFold,
    required this.stacksAtFold,
    required this.foldSecondaryRatio,
    required this.hasSecondaryBody,
    required this.canSplit,
  });

  /// The full width of the scaffold (the [LayoutBuilder] constraint).
  final double scaffoldWidth;

  /// Where the navigation goes, as the resolver said.
  final FoldableNavigationPlacement placement;

  /// The physical edge of the navigation: [FoldableNavigationEdge.none],
  /// [FoldableNavigationEdge.top], [FoldableNavigationEdge.bottom],
  /// [FoldableNavigationEdge.left] or [FoldableNavigationEdge.right].
  final FoldableNavigationEdge navigationEdge;

  /// The width a navigation beside the panes takes, including the system inset
  /// on its side. Zero for a navigation above or below the panes, or none.
  final double navigationWidth;

  /// What the side navigation really takes: zero without a navigation to show.
  final double railWidth;

  /// The width left for the two panes and the divider.
  final double paneAreaWidth;

  final TextDirection textDirection;

  /// Whether the text direction is right-to-left.
  bool get isRtl => textDirection == TextDirection.rtl;

  /// The fold or hinge the layout follows, or null when none applies.
  final FoldableFold? fold;

  /// The left edge of a vertical fold in pane coordinates (after the rail).
  /// Zero for a horizontal fold, or none.
  final double foldLeft;

  /// The right edge of a vertical fold in pane coordinates (after the rail).
  /// Zero for a horizontal fold, or none.
  final double foldRight;

  /// The top edge of a horizontal fold in pane coordinates (below the app bar
  /// and the navigation above the panes). Zero for a vertical fold, or none, or
  /// when the pane area has not been measured.
  final double foldTop;

  /// The bottom edge of a horizontal fold in pane coordinates. Zero for a
  /// vertical fold, or none, or when the pane area has not been measured.
  final double foldBottom;

  /// The height of the pane area as measured, or null when it has not been (or
  /// there is no horizontal fold to need it).
  final double? paneAreaHeight;

  /// Whether the fold separates the screen into two usable panes, side by side
  /// (a vertical fold) or stacked ([stacksAtFold], a horizontal one).
  final bool splitsAtFold;

  /// Whether a separating horizontal fold stacks the panes, the body above the
  /// secondary body: there is a secondary body, and each side of the fold is at
  /// least `minBodySize` tall. When true, [splitsAtFold] is true as well.
  final bool stacksAtFold;

  /// The axis the panes are laid out along: [Axis.vertical] when they are
  /// stacked around a horizontal fold, [Axis.horizontal] otherwise.
  Axis get paneAxis => stacksAtFold ? Axis.vertical : Axis.horizontal;

  /// Where the fold starts along [paneAxis], in pane coordinates: [foldTop]
  /// when stacked, [foldLeft] otherwise.
  double get foldStart => stacksAtFold ? foldTop : foldLeft;

  /// Where the fold ends along [paneAxis], in pane coordinates.
  double get foldEnd => stacksAtFold ? foldBottom : foldRight;

  /// Where a divider on a flat fold would put the secondary pane, relative to
  /// the scaffold width, or null when there is no flat fold to start from.
  final double? foldSecondaryRatio;

  /// Whether the secondary body is shown at all.
  final bool hasSecondaryBody;

  /// Whether the scaffold may show two panes (wide enough, or splitting at
  /// a fold).
  final bool canSplit;
}

/// The fold or hinge the scaffold follows, or null.
///
/// The fold is in window coordinates: it only means something to a scaffold
/// that spans the window along the fold. A vertical fold needs the scaffold to
/// be as wide as the window; a horizontal one needs it to be as tall as the
/// window ([scaffoldHeight] defaults to unknown, which rules horizontal folds
/// out). A scaffold under an app bar of its own, inside a padding or beside a
/// side panel does not span the window, and ignores the fold of that
/// orientation.
FoldableFold? resolveFold({
  required double scaffoldWidth,
  double scaffoldHeight = double.infinity,
  required Size windowSize,
  required List<DisplayFeature> displayFeatures,
  required bool followFold,
}) {
  if (!followFold) return null;
  final spansWidth = (scaffoldWidth - windowSize.width).abs() < 1;
  final spansHeight = (scaffoldHeight - windowSize.height).abs() < 1;
  if (!spansWidth && !spansHeight) return null;
  return FoldableFold.fromFeatures(
    displayFeatures,
    windowSize,
    vertical: spansWidth,
    horizontal: spansHeight,
  );
}

/// The bounds of the cutouts (cameras, a Dynamic Island) that apply to a
/// scaffold of [scaffoldWidth] x [scaffoldHeight] in a window of [windowSize].
///
/// Cutouts are in window coordinates, so they only apply when the scaffold
/// covers the window both ways (less than a pixel of difference, as for
/// [resolveFold]); otherwise the result is empty. Empty too when [avoid] is
/// false.
List<Rect> resolveCutouts({
  required double scaffoldWidth,
  required double scaffoldHeight,
  required Size windowSize,
  required List<DisplayFeature> displayFeatures,
  required bool avoid,
}) {
  if (!avoid) return const [];
  final spansWidth = (scaffoldWidth - windowSize.width).abs() < 1;
  final spansHeight = (scaffoldHeight - windowSize.height).abs() < 1;
  if (!spansWidth || !spansHeight) return const [];
  return [
    for (final feature in displayFeatures)
      if (feature.type == DisplayFeatureType.cutout) feature.bounds,
  ];
}

/// The extra insets that [area] (in window coordinates) needs to stay clear of
/// [cutouts], on top of the system insets [padding].
///
/// * [Axis.horizontal] (a bar across the top, such as an app bar): a cutout
///   that overlaps [area] and is on the right of its center pushes the right
///   edge in to the left side of the cutout, otherwise the left edge in to the
///   right side of the cutout. Only `left` and `right` are set.
/// * [Axis.vertical] (a rail along a side): a cutout above the center of
///   [area] pushes the top down to the bottom of the cutout, otherwise the
///   bottom up to the top of the cutout. Only `top` and `bottom` are set.
///
/// A cutout that lies entirely in the strip of the system [padding] (the
/// system already keeps content out of it, as on Android) is ignored, so the
/// space is not taken twice. Several cutouts give the largest inset on each
/// edge. The result is never negative; an empty [area] or no overlap gives
/// [EdgeInsets.zero].
///
/// Does not depend on [BuildContext] or a widget, so it can be tested without
/// pumping one.
EdgeInsets cutoutInsets({
  required Rect area,
  required List<Rect> cutouts,
  required EdgeInsets padding,
  required Size windowSize,
  required Axis axis,
}) {
  if (area.isEmpty) return EdgeInsets.zero;
  var left = 0.0;
  var top = 0.0;
  var right = 0.0;
  var bottom = 0.0;
  for (final c in cutouts) {
    final insidePadding =
        c.right <= padding.left ||
        c.left >= windowSize.width - padding.right ||
        c.bottom <= padding.top ||
        c.top >= windowSize.height - padding.bottom;
    if (insidePadding || !c.overlaps(area)) continue;
    if (axis == Axis.horizontal) {
      if (c.center.dx > area.center.dx) {
        right = math.max(right, area.right - c.left);
      } else {
        left = math.max(left, c.right - area.left);
      }
    } else {
      if (c.center.dy < area.center.dy) {
        top = math.max(top, c.bottom - area.top);
      } else {
        bottom = math.max(bottom, area.bottom - c.top);
      }
    }
  }
  return EdgeInsets.fromLTRB(
    math.max(left, 0),
    math.max(top, 0),
    math.max(right, 0),
    math.max(bottom, 0),
  );
}

/// The "outer frame" of the layout: from the scaffold width, the window, the
/// breakpoints, the text direction, the padding and the display features to
/// the navigation width, the pane area width and the fold state.
///
/// [scaffoldHeight] (default: unknown) is what lets a horizontal fold apply, see
/// [resolveFold]. [paneAreaRect] is where the pane area is, in window
/// coordinates, as measured after layout: the navigation above the panes and
/// the app bar are the user's widgets, so only a measure tells where the pane
/// area starts. Without it a horizontal fold cannot stack the panes.
///
/// Does not depend on [BuildContext], a widget or the scaffold state, so it
/// can be tested without pumping a widget.
FrameGeometry computeFrameGeometry({
  required double scaffoldWidth,
  double scaffoldHeight = double.infinity,
  Rect? paneAreaRect,
  required Size windowSize,
  required FoldableBreakpoints breakpoints,
  required TextDirection textDirection,
  required EdgeInsets padding,
  required List<DisplayFeature> displayFeatures,
  required bool followFold,
  required double minBodySize,
  required double dividerSize,
  required FoldableNavigationPlacement placement,
  required double minWidthNavigation,
  required double maxWidthNavigation,
  required bool hasNavigation,
  required bool hasSecondaryBody,
}) {
  final isRtl = textDirection == TextDirection.rtl;
  final isMediumLargeSize = breakpoints.canSplit(scaffoldWidth, windowSize);

  // A navigation beside the panes adds the system inset on its own side.
  final navigationEdge = placement.edge.resolve(textDirection);
  final sidePadding = switch (navigationEdge) {
    FoldableNavigationEdge.left => padding.left,
    FoldableNavigationEdge.right => padding.right,
    _ => 0.0,
  };
  final extent =
      placement.extent ??
      (scaffoldWidth > breakpoints.wideRail
          ? maxWidthNavigation
          : minWidthNavigation);
  // Inside the strip the slot is the strip; otherwise the extent plus it.
  final insideInset =
      placement.insideInset && navigationEdge.isSide && sidePadding > 0;
  final navigationWidth = !navigationEdge.isSide
      ? 0.0
      : (insideInset ? sidePadding : extent + sidePadding);
  // What the navigation really takes: nothing without a navigation to show.
  final railWidth = !hasNavigation ? 0.0 : navigationWidth;
  final paneAreaWidth = scaffoldWidth - railWidth;

  final fold = resolveFold(
    scaffoldWidth: scaffoldWidth,
    scaffoldHeight: scaffoldHeight,
    windowSize: windowSize,
    displayFeatures: displayFeatures,
    followFold: followFold,
  );
  final verticalFold = fold != null && fold.isVertical ? fold : null;
  final horizontalFold = fold != null && fold.isHorizontal ? fold : null;

  // The pane area starts at the physical left edge, unless the navigation is
  // on the left.
  final paneStartInPaneSpace = navigationEdge == FoldableNavigationEdge.left
      ? railWidth
      : 0.0;
  final foldLeft = verticalFold == null
      ? 0.0
      : verticalFold.bounds.left - paneStartInPaneSpace;
  final foldRight = verticalFold == null
      ? 0.0
      : verticalFold.bounds.right - paneStartInPaneSpace;

  // A horizontal fold is measured from where the pane area starts: below the
  // app bar and the navigation above the panes.
  final measured = horizontalFold != null && paneAreaRect != null;
  final foldTop = measured ? horizontalFold.bounds.top - paneAreaRect.top : 0.0;
  final foldBottom = measured
      ? horizontalFold.bounds.bottom - paneAreaRect.top
      : 0.0;
  final paneAreaHeight = measured ? paneAreaRect.height : null;

  // One pane on each side of a fold that cuts the screen, as long as both are
  // big enough to be useful.
  final splitsAtVerticalFold =
      verticalFold != null &&
      verticalFold.isSeparating &&
      foldLeft >= minBodySize &&
      paneAreaWidth - foldRight >= minBodySize;

  // One pane above and one below a horizontal fold that cuts the screen:
  // only with a secondary body to show, and with both sides at least
  // minBodySize tall (minBodySize is used for the height as well).
  final stacksAtFold =
      measured &&
      horizontalFold.isSeparating &&
      hasSecondaryBody &&
      foldTop >= minBodySize &&
      paneAreaHeight! - foldBottom >= minBodySize;
  final splitsAtFold = splitsAtVerticalFold || stacksAtFold;

  // Where the secondary pane ends up if the divider sits on a flat fold.
  // The secondary pane sits on the trailing side: left in RTL, right in LTR.
  final foldSecondaryRatio = verticalFold == null || verticalFold.isSeparating
      ? null
      : (isRtl
                ? verticalFold.center - dividerSize / 2
                : scaffoldWidth - verticalFold.center - dividerSize / 2) /
            scaffoldWidth;

  return FrameGeometry(
    scaffoldWidth: scaffoldWidth,
    placement: placement,
    navigationEdge: navigationEdge,
    navigationWidth: navigationWidth,
    railWidth: railWidth,
    paneAreaWidth: paneAreaWidth,
    textDirection: textDirection,
    fold: fold,
    foldLeft: foldLeft,
    foldRight: foldRight,
    foldTop: foldTop,
    foldBottom: foldBottom,
    paneAreaHeight: paneAreaHeight,
    splitsAtFold: splitsAtFold,
    stacksAtFold: stacksAtFold,
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

/// The extent of the primary pane, the divider and the secondary pane along
/// the [axis] they are laid out on, after the collapse rules have been applied.
///
/// Along [Axis.horizontal] the extents are widths and the panes sit side by
/// side; along [Axis.vertical] they are heights and the panes are stacked, the
/// primary pane on top. Everything else (the collapse rules, the animation, the
/// layout) is the same for both, which is the point of naming them extents.
class PaneGeometry {
  const PaneGeometry({
    required this.primaryExtent,
    required this.dividerExtent,
    required this.secondaryExtent,
    this.axis = Axis.horizontal,
  });

  final double primaryExtent;
  final double dividerExtent;
  final double secondaryExtent;

  /// The axis the panes are laid out along.
  final Axis axis;

  /// Whether the primary pane has room.
  ///
  /// A pane of zero extent is hidden: it is still laid out (so its state
  /// survives) but nothing of it is seen. The [FoldableScaffold] reads this on
  /// the *animated* geometry, so a pane that is sliding in or out (extent
  /// between zero and its target) still counts as visible until the animation
  /// ends.
  bool get primaryVisible => primaryExtent > 0;

  /// Whether the secondary pane has room. See [primaryVisible].
  bool get secondaryVisible => secondaryExtent > 0;

  @override
  bool operator ==(Object other) =>
      other is PaneGeometry &&
      other.axis == axis &&
      other.primaryExtent == primaryExtent &&
      other.dividerExtent == dividerExtent &&
      other.secondaryExtent == secondaryExtent;

  @override
  int get hashCode =>
      Object.hash(axis, primaryExtent, dividerExtent, secondaryExtent);
}

/// The "pane geometry" of the layout: from the pane area extent, the divider
/// ratio, the drag/hover state and the fold to the extent of each pane.
///
/// [axis] is the axis the panes are laid out along: [totalExtent] is the extent
/// of the pane area along it, and [foldStart] and [foldEnd] are the edges of the
/// fold along it, in pane coordinates, from the physical start (left or top).
/// Only a horizontal axis is mirrored by [isRtl]: stacked panes keep the
/// primary one on top in both directions. [scaffoldExtent] is what
/// [ratioSecondaryBody] is relative to; the ratio only applies without a fold
/// and the divider only moves along the horizontal axis.
///
/// Does not depend on [BuildContext], a widget or the scaffold state, so it
/// can be tested without pumping a widget.
PaneLayout computePaneLayout({
  Axis axis = Axis.horizontal,
  required double totalExtent,
  required double scaffoldExtent,
  required double ratioSecondaryBody,
  required bool canSplitPanel,
  required bool splitsAtFold,
  required double foldStart,
  required double foldEnd,
  required bool isRtl,
  required double minBodySize,
  required double dividerSize,
  required double minSecondarySize,
  required double maxSecondarySize,
  required bool focusOnPrimaryBody,
  required bool hasSecondaryBody,
  required bool isHoveringDivider,
}) {
  final splitExtent = (totalExtent - dividerSize).clamp(0.0, double.infinity);
  // The primary pane is at the far end of the axis in RTL, side by side only.
  final primaryIsAtEnd = axis == Axis.horizontal && isRtl;

  double secondaryTargetExtent = 0.0;
  double primaryTargetExtent = totalExtent;
  double dividerTargetExtent = 0.0;

  if (canSplitPanel && splitsAtFold) {
    // Around the fold or hinge: its area is the divider.
    // In RTL the body is on the right, the secondary body on the left.
    if (primaryIsAtEnd) {
      primaryTargetExtent = totalExtent - foldEnd;
      secondaryTargetExtent = foldStart;
    } else {
      primaryTargetExtent = foldStart;
      secondaryTargetExtent = totalExtent - foldEnd;
    }
    dividerTargetExtent = foldEnd - foldStart;
  } else if (canSplitPanel) {
    // The window may have been resized since the ratio was stored.
    secondaryTargetExtent = (ratioSecondaryBody * scaffoldExtent).clamp(
      minSecondarySize,
      maxSecondarySize,
    );
    dividerTargetExtent = dividerSize;
    primaryTargetExtent = splitExtent - secondaryTargetExtent;
  } else {
    if (!focusOnPrimaryBody && hasSecondaryBody) {
      secondaryTargetExtent = totalExtent;
      primaryTargetExtent = 0.0;
    } else {
      secondaryTargetExtent = 0.0;
      primaryTargetExtent = totalExtent;
    }
  }

  // A collapsed pane gives its room, and the divider's, to the other one.
  if (!isHoveringDivider) {
    if (primaryTargetExtent < minBodySize) {
      secondaryTargetExtent += primaryTargetExtent + dividerTargetExtent;
      primaryTargetExtent = 0;
      dividerTargetExtent = 0;
    }

    if (secondaryTargetExtent < minBodySize) {
      primaryTargetExtent += secondaryTargetExtent + dividerTargetExtent;
      secondaryTargetExtent = 0;
      dividerTargetExtent = 0;
    }
  }

  final geometry = PaneGeometry(
    axis: axis,
    primaryExtent: primaryTargetExtent.clamp(0.0, totalExtent),
    dividerExtent: dividerTargetExtent.clamp(0.0, totalExtent),
    secondaryExtent: secondaryTargetExtent.clamp(0.0, totalExtent),
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
///
/// Extents along different axes cannot be mixed (a width of 300 is not
/// "somewhere between" a height of 300 and a width of 500), so when the axis
/// changes the animation does not run: the geometry is the end one at once.
/// That is the fold or hinge changing the arrangement, which no animation
/// would make look right.
class PaneGeometryTween extends Tween<PaneGeometry> {
  PaneGeometryTween({required PaneGeometry end}) : super(end: end);

  @override
  bool operator ==(Object other) =>
      other is PaneGeometryTween && other.begin == begin && other.end == end;

  @override
  int get hashCode => Object.hash(begin, end);

  @override
  PaneGeometry lerp(double t) {
    final beginValue = begin ?? end!;
    final endValue = end!;
    if (beginValue.axis != endValue.axis) return endValue;
    return PaneGeometry(
      axis: endValue.axis,
      primaryExtent:
          beginValue.primaryExtent +
          (endValue.primaryExtent - beginValue.primaryExtent) * t,
      dividerExtent:
          beginValue.dividerExtent +
          (endValue.dividerExtent - beginValue.dividerExtent) * t,
      secondaryExtent:
          beginValue.secondaryExtent +
          (endValue.secondaryExtent - beginValue.secondaryExtent) * t,
    );
  }
}

/// The two pane rectangles of [geometry] laid out in a pane area of [size],
/// expressed in that area's coordinates.
///
/// This mirrors exactly where [FoldableScaffold] places the two panes
/// (`_PaneLayoutDelegate`): the same total-extent scale, the same start edge
/// (left in LTR, right in RTL side by side; always the top when stacked) and
/// the same order of subtractions and additions. Because the arithmetic is the
/// same, a page placed on [FoldablePaneRects] lands on the very pixels of the
/// pane the scaffold lays out, in the same frame, with no measurement and no
/// lag.
///
/// A collapsed pane (animated extent zero) comes back as `null`, so callers
/// treat "hidden" separately from a zero-size rectangle.
///
/// Pure: no [BuildContext], widget or state, so it can be tested without
/// pumping a widget.
FoldablePaneRects computePaneRects({
  required PaneGeometry geometry,
  required TextDirection textDirection,
  required Size size,
}) {
  final axis = geometry.axis;
  final isHorizontal = axis == Axis.horizontal;
  final extent = isHorizontal ? size.width : size.height;
  final crossExtent = isHorizontal ? size.height : size.width;
  final totalTargetExtent =
      geometry.primaryExtent +
      geometry.dividerExtent +
      geometry.secondaryExtent;
  final scale = totalTargetExtent > extent && totalTargetExtent > 0
      ? extent / totalTargetExtent
      : 1.0;

  // Same start edge and order as _PaneLayoutDelegate.performLayout.
  final fromEnd = isHorizontal && textDirection == TextDirection.rtl;
  var position = fromEnd ? extent : 0.0;

  Rect rectOf(double paneExtent) {
    final scaled = (paneExtent * scale).clamp(0.0, extent);
    final Rect rect;
    if (fromEnd) {
      position -= scaled;
      rect = isHorizontal
          ? Rect.fromLTWH(position, 0, scaled, crossExtent)
          : Rect.fromLTWH(0, position, crossExtent, scaled);
    } else {
      rect = isHorizontal
          ? Rect.fromLTWH(position, 0, scaled, crossExtent)
          : Rect.fromLTWH(0, position, crossExtent, scaled);
      position += scaled;
    }
    return rect;
  }

  final Rect primaryRaw = rectOf(geometry.primaryExtent);
  rectOf(geometry.dividerExtent); // advance past the divider
  final Rect secondaryRaw = rectOf(geometry.secondaryExtent);

  return FoldablePaneRects(
    primary: geometry.primaryVisible ? primaryRaw : null,
    secondary: geometry.secondaryVisible ? secondaryRaw : null,
    axis: axis,
  );
}

enum PaneSlot { primary, divider, secondary }
