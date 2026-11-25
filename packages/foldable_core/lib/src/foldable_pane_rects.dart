import 'package:flutter/widgets.dart';

/// Two pane rectangles exposed by a layout (a scaffold shell, or an app
/// computing them itself) as pure data.
///
/// The rectangles describe the pane area of a split layout: [primary] is the
/// body pane and [secondary] is the secondary pane. They are expressed in the
/// coordinate space of the pane area, not in window coordinates, so the same
/// value can be reused by any widget placed at the top-left of that area.
///
/// A pane that is not shown right now is `null` rather than `Rect.zero`:
/// `Rect.zero` is a legitimate zero-size rectangle at the origin (it could
/// appear momentarily during an animation), so conflating "not shown" with a
/// zero-size rectangle would force every caller to distinguish the two cases
/// by hand. `null` means there is no pane to lay out in that slot.
///
/// [axis] is the axis the panes are laid out along: [Axis.horizontal] side by
/// side, [Axis.vertical] stacked (around a horizontal hinge).
///
/// Provider: none — this is pure data. The scaffold package publishes an
/// animated [FoldablePaneRects] through [FoldablePaneRectsScope] from its own
/// build phase; an app that only uses the router package computes the same
/// value itself (for example with a `LayoutBuilder`) and wraps its shell in a
/// [FoldablePaneRectsScope].
///
/// Consumer: the router package places each page in its pane rectangle directly
/// (no measurement, no layout loop, no frame of lag).
@immutable
class FoldablePaneRects {
  /// Creates the pane rectangles.
  const FoldablePaneRects({
    required this.primary,
    required this.secondary,
    required this.axis,
  });

  /// The body pane rectangle, or `null` when the primary pane is not shown.
  final Rect? primary;

  /// The secondary pane rectangle, or `null` when the secondary pane is not
  /// shown.
  final Rect? secondary;

  /// The axis the panes are laid out along.
  final Axis axis;

  /// Whether both panes are shown right now.
  bool get isSplit => primary != null && secondary != null;

  /// Whether the secondary pane is shown right now.
  bool get secondaryVisible => secondary != null;

  /// Whether the primary pane is shown right now.
  bool get primaryVisible => primary != null;

  /// Computes a side-by-side layout for [size].
  ///
  /// [secondaryExtent] is the width of the secondary pane. Alternatively,
  /// [secondaryFraction] expresses that width as a fraction of the available
  /// width after [dividerExtent]. The primary pane is on the leading side in
  /// [textDirection], and the secondary pane is on the trailing side.
  static FoldablePaneRects sideBySide(
    Size size, {
    double? secondaryExtent,
    double? secondaryFraction,
    double dividerExtent = 0,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final width = _resolveSecondaryExtent(
      availableExtent: size.width - dividerExtent,
      extent: secondaryExtent,
      fraction: secondaryFraction,
    );
    // A pane with no room is not shown at all: `null`, not a zero-size rect.
    // The remaining pane takes the whole area, so no empty divider gap is
    // left behind either.
    if (width <= 0) {
      return FoldablePaneRects(
        primary: size.isEmpty ? null : Offset.zero & size,
        secondary: null,
        axis: Axis.horizontal,
      );
    }
    final primaryWidth = size.width - dividerExtent - width;
    if (primaryWidth <= 0) {
      return FoldablePaneRects(
        primary: null,
        secondary: Offset.zero & size,
        axis: Axis.horizontal,
      );
    }
    final primary = textDirection == TextDirection.ltr
        ? Rect.fromLTWH(0, 0, primaryWidth, size.height)
        : Rect.fromLTWH(width + dividerExtent, 0, primaryWidth, size.height);
    final secondary = textDirection == TextDirection.ltr
        ? Rect.fromLTWH(primaryWidth + dividerExtent, 0, width, size.height)
        : Rect.fromLTWH(0, 0, width, size.height);
    return FoldablePaneRects(
      primary: primary,
      secondary: secondary,
      axis: Axis.horizontal,
    );
  }

  /// Computes a stacked layout for [size].
  ///
  /// [secondaryExtent] is the height of the secondary pane. Alternatively,
  /// [secondaryFraction] expresses that height as a fraction of the available
  /// height after [dividerExtent]. The primary pane is above the secondary
  /// pane. [textDirection] is accepted for API symmetry and has no effect.
  static FoldablePaneRects stacked(
    Size size, {
    double? secondaryExtent,
    double? secondaryFraction,
    double dividerExtent = 0,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    final height = _resolveSecondaryExtent(
      availableExtent: size.height - dividerExtent,
      extent: secondaryExtent,
      fraction: secondaryFraction,
    );
    // A pane with no room is not shown at all: `null`, not a zero-size rect.
    // The remaining pane takes the whole area, so no empty divider gap is
    // left behind either.
    if (height <= 0) {
      return FoldablePaneRects(
        primary: size.isEmpty ? null : Offset.zero & size,
        secondary: null,
        axis: Axis.vertical,
      );
    }
    final primaryHeight = size.height - dividerExtent - height;
    if (primaryHeight <= 0) {
      return FoldablePaneRects(
        primary: null,
        secondary: Offset.zero & size,
        axis: Axis.vertical,
      );
    }
    return FoldablePaneRects(
      primary: Rect.fromLTWH(0, 0, size.width, primaryHeight),
      secondary: Rect.fromLTWH(
        0,
        primaryHeight + dividerExtent,
        size.width,
        height,
      ),
      axis: Axis.vertical,
    );
  }

  static double _resolveSecondaryExtent({
    required double availableExtent,
    required double? extent,
    required double? fraction,
  }) {
    assert(availableExtent >= 0, 'Available pane extent must be non-negative');
    assert(
      (extent == null) != (fraction == null),
      'Specify exactly one of secondaryExtent or secondaryFraction',
    );
    assert(extent == null || extent >= 0 && extent <= availableExtent);
    assert(fraction == null || fraction >= 0 && fraction <= 1);
    return extent ?? availableExtent * fraction!;
  }

  @override
  bool operator ==(Object other) =>
      other is FoldablePaneRects &&
      other.primary == primary &&
      other.secondary == secondary &&
      other.axis == axis;

  @override
  int get hashCode => Object.hash(primary, secondary, axis);
}

/// Publishes the animated pane rectangles of a scaffold (or any other pane
/// layout) down its pane subtree.
///
/// The scaffold package builds this scope above the pane content in its own
/// build phase, so the rectangles are already the animated values of the
/// current frame. A router hosted there places its pages directly in them and
/// never measures a frame, which removes both the cross-layout-pass mutation
/// crash and the one-frame lag of deferring to a post-frame callback.
///
/// Provider: the scaffold package around its pane content (via its
/// `paneContent` slot), or the app when it uses the router package without a
/// scaffold.
///
/// Consumer: the router package's pane host.
///
/// When there is no provider: [maybeOf] returns `null`; callers fall back to
/// their own rectangle computation.
class FoldablePaneRectsScope extends InheritedWidget {
  /// Creates the scope.
  const FoldablePaneRectsScope({
    required this.rects,
    super.key,
    required super.child,
  });

  /// The pane rectangles exposed to the subtree.
  final FoldablePaneRects rects;

  /// The closest scope, subscribing [context]: the caller rebuilds when the
  /// rectangles change.
  static FoldablePaneRectsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldablePaneRectsScope>();

  /// The closest scope, without subscribing (safe in `initState`, callbacks).
  static FoldablePaneRectsScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FoldablePaneRectsScope>();

  /// The rectangles of the closest scope, or `null` when there is none.
  static FoldablePaneRects? rectsOf(BuildContext context) =>
      maybeOf(context)?.rects;

  @override
  bool updateShouldNotify(FoldablePaneRectsScope oldWidget) =>
      rects != oldWidget.rects;
}
