import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foldable_route.dart';
import 'redirect_resolver.dart';
import 'route_information_parser.dart';
import 'router_delegate.dart';

/// Creates a route from the query parameters of a URL.
///
/// Throw (for example with `params['id']!`) when a required parameter is
/// missing; the router then shows its not-found page.
typedef FoldableRouteFactory =
    FoldableRoute Function(Map<String, String> params);

/// Builds the page shown for a location that matches no route.
typedef FoldableNotFoundBuilder =
    Widget Function(BuildContext context, Uri uri);

/// A Navigation 2.0 router whose destinations are [FoldableRoute] instances.
///
/// ```dart
/// final router = FoldableRouter(
///   initial: const HomeRoute(),
///   routes: {
///     '/users': (params) => const UsersRoute(),
///     '/users/detail': (params) => UserRoute(id: params['id']!),
///   },
///   notFoundBuilder: (context, uri) => NotFoundPage(uri: uri),
/// );
///
/// MaterialApp.router(routerConfig: router.routerConfig);
/// ```
///
/// Every navigation first runs [FoldableRoute.redirect] from the root
/// ancestor down to the target. While that is pending the current page stays
/// on screen and [isNavigating] is `true`. If a newer navigation starts in
/// the meantime, the older one is discarded.
class FoldableRouter {
  /// Creates a router.
  FoldableRouter({
    required this.initial,
    required this.routes,
    required this.notFoundBuilder,
    this.pendingBuilder,
    this.maxRedirects = 5,
  }) : assert(maxRedirects >= 0);

  /// The route opened on launch when the platform supplies no deep link.
  final FoldableRoute initial;

  /// Maps a static path to a factory creating the route from URL query
  /// parameters. Used for deep links and the web address bar.
  ///
  /// A path missing here, or a factory that throws, leads to
  /// [notFoundBuilder].
  final Map<String, FoldableRouteFactory> routes;

  /// Builds the page for a location that matches no entry of [routes].
  final FoldableNotFoundBuilder notFoundBuilder;

  /// Builds what is shown on first launch while the first redirect is
  /// pending. Defaults to an empty box.
  final WidgetBuilder? pendingBuilder;

  /// How many consecutive redirects one navigation may take before it fails
  /// with a [RedirectLimitException].
  final int maxRedirects;

  late final FoldableRouterDelegate _delegate = FoldableRouterDelegate(this);

  /// The configuration to pass to `MaterialApp.router`.
  late final RouterConfig<Object> routerConfig = _createConfig();

  RouterConfig<Uri> _createConfig() {
    final launch = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    return RouterConfig<Uri>(
      routeInformationProvider: PlatformRouteInformationProvider(
        initialRouteInformation: RouteInformation(
          uri: launch == Navigator.defaultRouteName
              ? initial.uri
              : Uri.parse(launch),
        ),
      ),
      routeInformationParser: const FoldableRouteInformationParser(),
      routerDelegate: _delegate,
      backButtonDispatcher: RootBackButtonDispatcher(),
    );
  }

  /// The routes currently on the stack, bottom first. Read-only.
  ///
  /// Empty before the first navigation completes and while the not-found
  /// page is shown.
  List<FoldableRoute> get stack => _delegate.stack;

  /// Whether a navigation is currently waiting for its redirects.
  ValueListenable<bool> get isNavigating => _delegate.isNavigating;

  /// Replaces the whole stack with [route] and its [FoldableRoute.parent]
  /// chain, after running redirects.
  ///
  /// The future completes when the navigation is committed or discarded
  /// because a newer one started. It completes with an error when a redirect
  /// throws or when redirects loop or exceed [maxRedirects]
  /// ([FoldableRedirectException]); the stack is then unchanged.
  Future<void> open(FoldableRoute route) => _delegate.open(route);

  /// Puts [route] alone (without its parents) on top of the stack, after
  /// running the redirects of its parent chain. If a redirect answers with
  /// another route, that one is pushed instead.
  ///
  /// The future completes with the value given to [pop], or `null` when the
  /// page is removed any other way (system back, [open]) or the navigation
  /// is discarded because a newer one started. Errors are as for [open].
  Future<T?> push<T extends Object?>(FoldableRoute route) =>
      _delegate.push<T>(route);

  /// Removes the top page and completes its [push] future with [result].
  ///
  /// Does nothing when only one page is left.
  void pop<T extends Object?>([T? result]) => _delegate.pop<T>(result);

  /// Re-runs [FoldableRoute.redirect] for every route on the stack, bottom
  /// to top. The first non-null answer is opened as with [open]; if all
  /// return `null` nothing changes.
  ///
  /// Call this after the state your redirects depend on has changed (for
  /// example on sign-out). Like any navigation it supersedes pending ones.
  Future<void> refresh() => _delegate.refresh();

  /// Releases the resources of this router. Pending navigations are
  /// discarded.
  void dispose() => _delegate.dispose();

  /// The router that built the subtree containing [context].
  static FoldableRouter of(BuildContext context) {
    final router = maybeOf(context);
    assert(router != null, 'No FoldableRouter found in context.');
    return router!;
  }

  /// Like [of], but returns `null` when there is no router above [context].
  static FoldableRouter? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldableRouterScope>()?.router;
}
