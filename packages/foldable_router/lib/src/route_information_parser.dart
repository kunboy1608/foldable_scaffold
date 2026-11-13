import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Passes the platform location through as a [Uri]; the delegate maps it to
/// a route with the router's `routes` table.
///
/// It also remembers the [BuildContext] of the `Router` widget, the one Flutter
/// hands to [parseRouteInformationWithDependencies], so that redirects (which
/// run in the delegate) can receive it. That is the same context go_router
/// passes to its `redirect`: the context of the `Router` state, above the
/// navigator, below whatever the app puts above `MaterialApp.router` and
/// below what `MaterialApp` itself provides.
class FoldableRouteInformationParser extends RouteInformationParser<Uri> {
  /// Creates the parser. [onRouterContext] is called with the `Router`
  /// widget's context every time the platform supplies a location.
  const FoldableRouteInformationParser({required this.onRouterContext});

  /// Called with the [BuildContext] of the `Router` widget.
  final void Function(BuildContext context) onRouterContext;

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation.uri);

  @override
  Future<Uri> parseRouteInformationWithDependencies(
    RouteInformation routeInformation,
    BuildContext context,
  ) {
    onRouterContext(context);
    return parseRouteInformation(routeInformation);
  }

  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}
