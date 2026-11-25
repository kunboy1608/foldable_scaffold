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
/// their own rect computation (or to the legacy frame measurement of the
/// router package).
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
