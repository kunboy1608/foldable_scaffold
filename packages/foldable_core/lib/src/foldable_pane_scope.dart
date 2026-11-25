import 'package:flutter/widgets.dart';

import 'foldable_pane.dart';

/// Private to the package that published the scope.
///
/// `foldable_router` puts the stack entry of the page here, so that
/// `FoldableRouter.close` can find it; core never reads it and an app should
/// leave it null.
abstract interface class FoldablePaneOwner {}

/// The slot the calling widget is drawn in.
///
/// Published by whoever owns the slot: `FoldableScaffold` around the content
/// of each of its panes, `foldable_router` around each page when it draws the
/// pages itself (a shell tab without a `FoldableScaffold`).
///
/// Provider: `FoldableScaffold` (one scope per pane, `owner: null`) and
/// `foldable_router` (one scope per page, `owner: the stack entry`).
/// Consumer: pages through `FoldablePaneScope.paneOf` or directly, and
/// `FoldableRouter.paneOf` / `close` which read `owner`.
/// When there is no provider: [paneOf] returns [FoldablePane.single] — that is
/// also the historical fallback of `FoldableRouter.paneOf` without a
/// `PaneScope`.
class FoldablePaneScope extends InheritedWidget {
  const FoldablePaneScope({
    required this.pane,
    this.owner,
    super.key,
    required super.child,
  });

  /// The slot the subtree is shown in.
  final FoldablePane pane;

  /// Private to the package that published the scope.
  final FoldablePaneOwner? owner;

  /// The closest scope, subscribing [context].
  static FoldablePaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldablePaneScope>();

  /// The closest scope, without subscribing (safe in `initState`, callbacks).
  static FoldablePaneScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<FoldablePaneScope>();

  /// The pane of the closest scope, or [FoldablePane.single] when there is
  /// none. Subscribes [context].
  static FoldablePane paneOf(BuildContext context) =>
      maybeOf(context)?.pane ?? FoldablePane.single;

  @override
  bool updateShouldNotify(FoldablePaneScope oldWidget) =>
      pane != oldWidget.pane || owner != oldWidget.owner;
}
