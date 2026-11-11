import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Passes the platform location through as a [Uri]; the delegate maps it to
/// a route with the router's `routes` table.
class FoldableRouteInformationParser extends RouteInformationParser<Uri> {
  /// Creates the parser.
  const FoldableRouteInformationParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(routeInformation.uri);

  @override
  RouteInformation restoreRouteInformation(Uri configuration) =>
      RouteInformation(uri: configuration);
}
