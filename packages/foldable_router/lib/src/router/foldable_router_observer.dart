import 'package:flutter/foundation.dart';

import '../route/foldable_route.dart';

/// What kind of navigation a [FoldableNavigationEvent] describes.
///
/// Every user-visible navigation produces exactly one event, whether it went
/// through the router or straight through the controller: a back button,
/// system back or a swipe back, `goBranch` from a navigation rail, or a
/// `controller.pop`. A `controller.batch` is reported as one event.
enum FoldableNavigationKind {
  /// A route replaced the pages above its parent, or switched to a branch
  /// root: `go`, `goLocation`, `goUri` and the redirects behind them.
  ///
  /// Going to the root of a tab is one `go`, not a [branch] plus a [pop]. Also
  /// the kind of a direct `controller.setPages` that keeps the page count.
  go,

  /// A page was added on top of the current branch: `push`, `pushLocation`,
  /// `pushAndRemoveUntil` and `pushAndReplace`.
  ///
  /// Also the kind of a page added directly on the controller, whose event
  /// has no [FoldableNavigationEvent.route].
  push,

  /// Pages were removed from the current branch: `back`, `pop`, `popPage`,
  /// `popUntil`, `popToRoot`, the back button, system back and a swipe back.
  /// Its [FoldableNavigationEvent.route] is null.
  pop,

  /// Another branch (tab) is shown, as by `controller.goBranch` or by a
  /// navigation rail. Its [FoldableNavigationEvent.route] is null.
  ///
  /// Going to a route that is a branch root is a [go], not a [branch].
  branch,
}

/// One navigation, for [FoldableRouterObserver]s such as a log or dev tools.
@immutable
class FoldableNavigationEvent {
  const FoldableNavigationEvent({
    required this.kind,
    required this.uri,
    required this.branch,
    required this.depth,
    this.route,
  });

  /// What happened.
  final FoldableNavigationKind kind;

  /// The route that was opened, when the router knows it: a
  /// [FoldableNavigationKind.go] or [FoldableNavigationKind.push] made through
  /// the router. Null for pops, branch switches and changes made directly on
  /// the controller.
  final FoldableRoute? route;

  /// The URL the router shows after the navigation.
  final Uri uri;

  /// The branch on screen after the navigation.
  final int branch;

  /// Number of pages in the branch on screen after the navigation.
  final int depth;
}

/// Listens to the navigations of a [FoldableRouter].
///
/// Add one with [FoldableRouterConfig.observers], for example to log what the
/// user opens or to drive `foldable_dev_tools`.
class FoldableRouterObserver {
  const FoldableRouterObserver();

  /// Called after every navigation, once per navigation.
  void onNavigation(FoldableNavigationEvent event) {}
}
