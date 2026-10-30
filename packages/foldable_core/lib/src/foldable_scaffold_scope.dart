import 'package:flutter/widgets.dart';

/// Exposes the layout mode of the nearest `FoldableScaffold` to its bodies.
class FoldableScaffoldScope extends InheritedWidget {
  const FoldableScaffoldScope({
    required this.canSplit,
    required super.child,
    super.key,
  });

  /// Whether the scaffold is wide enough to show body and secondary body
  /// side by side.
  final bool canSplit;

  /// The closest [FoldableScaffoldScope], if any.
  static FoldableScaffoldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldableScaffoldScope>();

  @override
  bool updateShouldNotify(FoldableScaffoldScope oldWidget) =>
      canSplit != oldWidget.canSplit;
}
