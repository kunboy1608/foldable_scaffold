import 'package:flutter/foundation.dart';

import '../route/foldable_route.dart';

/// What kind of navigation a [FoldableNavigationEvent] describes.
enum FoldableNavigationKind {
  /// A route replaced the pages above its parent.
  go,

  /// A page was added on top of the current branch.
  push,

  /// A page was removed.
  pop,

  /// Another branch (tab) is shown.
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

  /// The route that was opened, when there is one ([FoldableNavigationKind.go]
  /// and [FoldableNavigationKind.push]).
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

  /// Called after every navigation.
  void onNavigation(FoldableNavigationEvent event) {}
}
