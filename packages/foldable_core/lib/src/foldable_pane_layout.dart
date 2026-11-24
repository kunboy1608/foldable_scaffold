import 'package:flutter/widgets.dart';

/// Which panes of the enclosing `FoldableScaffold` are shown, based on the
/// target layout (not the animated one).
class FoldablePaneLayout extends InheritedWidget {
  const FoldablePaneLayout({
    required this.primaryVisible,
    required this.secondaryVisible,
    required super.child,
    this.axis = Axis.horizontal,
    super.key,
  });

  /// Whether the body pane is shown.
  final bool primaryVisible;

  /// Whether the secondary body pane is shown.
  final bool secondaryVisible;

  /// The axis the two panes are laid out along: [Axis.horizontal] for panes side
  /// by side (the usual layout, and the default), [Axis.vertical] when they are
  /// stacked, the body above the secondary body, around a horizontal hinge.
  ///
  /// Only meaningful while both panes are visible.
  final Axis axis;

  /// The layout of the enclosing `FoldableScaffold`, if any.
  static FoldablePaneLayout? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FoldablePaneLayout>();
  }

  @override
  bool updateShouldNotify(FoldablePaneLayout oldWidget) =>
      primaryVisible != oldWidget.primaryVisible ||
      secondaryVisible != oldWidget.secondaryVisible ||
      axis != oldWidget.axis;
}
