import 'package:flutter/foundation.dart';

import 'foldable_route.dart';

/// The context handed to [FoldableRoute.redirect].
@immutable
class RouteState {
  /// Creates a route state.
  const RouteState({required this.route, required this.target});

  /// The route whose `redirect` is being evaluated.
  final FoldableRoute route;

  /// The route this navigation is heading to.
  ///
  /// Equal to [route] when the target itself is being checked, and a
  /// descendant of [route] when an ancestor is being checked. During
  /// `FoldableRouter.refresh` it is the top of the current stack.
  final FoldableRoute target;

  /// The location of [target].
  Uri get uri => target.uri;

  @override
  String toString() => 'RouteState(route: $route, target: $target)';
}
