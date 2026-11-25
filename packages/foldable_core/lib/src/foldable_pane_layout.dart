import 'package:flutter/widgets.dart';

import 'foldable_pane.dart';

/// The two-pane layout of the closest `FoldableScaffold`.
///
/// Published by `FoldableScaffold` above both of its panes; read by the
/// content of the panes (a router that builds them, an app page) to know
/// whether it is being shown in one pane or two, and along which axis.
///
/// The values are the *target* layout: they do not change on every frame of
/// the pane animation. [canSplit] only depends on the geometry (width,
/// breakpoints, fold, insets) and whether the scaffold was given a secondary
/// body, never on what the content does, so reading it can never feed back
/// into the layout.
///
/// Provider: `FoldableScaffold` (always, once around both panes). It replaces
/// `FoldableScaffoldScope` of the old core.
/// Consumer: router (pane host decides single vs split), app page, tests.
/// When there is no provider: [maybeOf] returns `null`; callers fall back to
/// a single-pane behaviour.
class FoldablePaneLayout extends InheritedWidget {
  const FoldablePaneLayout({
    required this.canSplit,
    required this.primaryVisible,
    required this.secondaryVisible,
    required this.axis,
    super.key,
    required super.child,
  });

  /// Whether the scaffold has room for two panes whatever the content: the
  /// layout is a split as soon as a secondary body exists and the geometry
  /// allows it.
  final bool canSplit;

  /// Whether the body pane is shown.
  final bool primaryVisible;

  /// Whether the secondary body pane is shown.
  final bool secondaryVisible;

  /// The axis the panes are laid out along once both are visible:
  /// [Axis.horizontal] side by side, [Axis.vertical] stacked around a
  /// horizontal hinge. Meaningless when [isSplit] is false.
  final Axis axis;

  /// Whether the two panes are shown together right now.
  bool get isSplit => primaryVisible && secondaryVisible;

  /// The pane a widget in the body slot is shown in, at target layout.
  FoldablePane get bodyPane => FoldablePane.primary;

  /// The closest layout, subscribing [context] to its changes.
  static FoldablePaneLayout of(BuildContext context) {
    final layout = maybeOf(context);
    assert(layout != null, 'No FoldableScaffold above $context');
    return layout!;
  }

  /// The closest layout, or null above any `FoldableScaffold`, subscribing
  /// [context] to its changes.
  static FoldablePaneLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldablePaneLayout>();

  /// The closest layout, or null, without subscribing [context] to changes.
  /// Safe to use in `initState` and callbacks.
  static FoldablePaneLayout? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FoldablePaneLayout>();

  @override
  bool updateShouldNotify(FoldablePaneLayout oldWidget) =>
      canSplit != oldWidget.canSplit ||
      primaryVisible != oldWidget.primaryVisible ||
      secondaryVisible != oldWidget.secondaryVisible ||
      axis != oldWidget.axis;
}
