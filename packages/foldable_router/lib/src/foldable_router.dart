import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foldable_route.dart';
import 'foldable_shell_route.dart';
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
///
/// The router is a [Listenable]: it notifies its listeners whenever [stack]
/// or [location] changes. [FoldableRouter.of] does not rebuild its dependants
/// on such a change, so a widget that shows the stack listens explicitly:
///
/// ```dart
/// ListenableBuilder(
///   listenable: router,
///   builder: (context, _) => Text('${router.location}'),
/// );
/// ```
class FoldableRouter implements Listenable {
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
  /// With a shell on screen this is `[shell, ...pages of the current
  /// branch, ...full-screen pages above the shell]` (preceded by the
  /// ancestors of the shell, if any).
  ///
  /// Empty before the first navigation completes and while the not-found
  /// page is shown.
  ///
  /// Listen to the router ([addListener]) to be told when this changes.
  List<FoldableRoute> get stack => _delegate.stack;

  /// The location currently reported to the platform (the web address bar).
  ///
  /// This is the [FoldableRoute.uri] of the top of the [stack], or the
  /// unknown URI while the not-found page is shown, or `null` before the
  /// first navigation completes.
  ///
  /// Listen to the router ([addListener]) to be told when this changes.
  Uri? get location => _delegate.currentConfiguration;

  /// Registers [listener] to be called whenever [stack] or [location]
  /// changes: after [open], [push], [pop], a system back, a [refresh] that
  /// redirects, a URL from the platform or [openUri], and when the not-found
  /// page is entered or left.
  ///
  /// It is not called when nothing changes (a [refresh] whose redirects all
  /// return `null`, [pop] on the last page, a discarded or failed
  /// navigation, [open] of the route that is already shown), nor for
  /// [isNavigating], which is a listenable of its own.
  ///
  /// Must not be called after [dispose].
  @override
  void addListener(VoidCallback listener) =>
      _delegate.stackChanges.addListener(listener);

  /// Removes a listener registered with [addListener].
  @override
  void removeListener(VoidCallback listener) =>
      _delegate.stackChanges.removeListener(listener);

  /// The route [uri] stands for, or `null` when there is none.
  ///
  /// This is the lookup used for deep links and the web address bar: the
  /// path of [uri] (a trailing slash is ignored, an empty path means `/`)
  /// selects a factory of [routes], which receives the query parameters. A
  /// URI equal to the one of [initial] resolves to [initial] itself, so
  /// [initial] needs no entry in [routes]; when [initial] is a
  /// [FoldableShellRoute] (which has no path), `/` resolves to it. The
  /// result is `null` when the path is not in [routes] or the factory
  /// throws.
  ///
  /// It only creates the route: no redirect runs and nothing is navigated.
  /// Pass the result to [open] or [push], or use [openUri].
  FoldableRoute? routeFor(Uri uri) {
    var path = uri.path.isEmpty ? '/' : uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final normalized = uri.replace(path: path);
    // A shell has no path of its own, so when it is the initial route `/`
    // resolves to it (opening it opens its first branch).
    final initialPath = initial is FoldableShellRoute ? '/' : initial.path;
    if (path == initialPath &&
        mapEquals(normalized.queryParameters, initial.uri.queryParameters)) {
      return initial;
    }
    final factory = routes[path];
    if (factory == null) return null;
    final FoldableRoute route;
    try {
      route = factory(Map.unmodifiable(normalized.queryParameters));
    } catch (_) {
      // Typically a missing or malformed parameter.
      return null;
    }
    assert(
      route.path == path,
      'The factory registered for "$path" returned $route, whose path is '
      '"${route.path}".',
    );
    return route;
  }

  /// Whether a navigation is currently waiting for its redirects.
  ValueListenable<bool> get isNavigating => _delegate.isNavigating;

  /// Replaces the whole stack with [route] and its [FoldableRoute.parent]
  /// chain, after running redirects.
  ///
  /// When the chain contains a [FoldableShellRoute] only the stack of
  /// [route]'s branch is replaced (other branches keep their stacks);
  /// opening a shell itself opens its first branch. Opening a route outside
  /// the shell removes the shell and the stacks of all its branches.
  ///
  /// The future completes when the navigation is committed or discarded
  /// because a newer one started. It completes with an error when a redirect
  /// throws or when redirects loop or exceed [maxRedirects]
  /// ([FoldableRedirectException]); the stack is then unchanged.
  Future<void> open(FoldableRoute route) => _delegate.open(route);

  /// Opens the location [uri] the way a URL arriving from the platform is
  /// opened: [routeFor] turns it into a route, which is then opened as with
  /// [open] (redirects included).
  ///
  /// When [uri] matches no route the not-found page is shown ([stack]
  /// becomes empty, [location] is [uri]) and the future completes normally.
  ///
  /// Errors are as for [open] and are delivered through the returned future
  /// (for a platform URL they go to [FlutterError.reportError] instead). As
  /// for a platform URL, if such an error happens while nothing is on
  /// screen yet (before the first navigation completed), the not-found page
  /// is shown for [uri].
  Future<void> openUri(Uri uri) => _delegate.openUri(uri);

  /// Puts [route] alone (without its parents) on top of the stack, after
  /// running the redirects of its parent chain. If a redirect answers with
  /// another route, that one is pushed instead.
  ///
  /// Pushing is not supported for a route whose parent chain contains a
  /// [FoldableShellRoute] (or whose redirect lands in one): the returned
  /// future completes with an [UnsupportedError] and the stack is
  /// unchanged; use [open] instead. Pushing a route outside the shell shows
  /// a full-screen page above it.
  ///
  /// The future completes with the value given to [pop], or `null` when the
  /// page is removed any other way (system back, [open]) or the navigation
  /// is discarded because a newer one started. Errors are as for [open].
  Future<T?> push<T extends Object?>(FoldableRoute route) =>
      _delegate.push<T>(route);

  /// Removes the top page and completes its [push] future with [result].
  ///
  /// With a shell on screen this first removes a full-screen page pushed
  /// above it, then goes one page back inside the current branch. Does
  /// nothing at the root of a branch or when only one page is left.
  void pop<T extends Object?>([T? result]) => _delegate.pop<T>(result);

  /// Re-runs [FoldableRoute.redirect] for every route on the stack, bottom
  /// to top. The first non-null answer is opened as with [open]; if all
  /// return `null` nothing changes. With a shell on screen this covers the
  /// shell, the current branch and any full-screen page above; the other
  /// branches are re-checked when they are shown again.
  ///
  /// Call this after the state your redirects depend on has changed (for
  /// example on sign-out). Like any navigation it supersedes pending ones.
  Future<void> refresh() => _delegate.refresh();

  /// Releases the resources of this router. Pending navigations are
  /// discarded.
  void dispose() => _delegate.dispose();

  /// The router that built the subtree containing [context].
  ///
  /// The calling widget is not rebuilt when [stack] or [location] changes.
  /// To rebuild on such a change, listen to the router, for example with a
  /// `ListenableBuilder(listenable: FoldableRouter.of(context), ...)`.
  static FoldableRouter of(BuildContext context) {
    final router = maybeOf(context);
    assert(router != null, 'No FoldableRouter found in context.');
    return router!;
  }

  /// Like [of], but returns `null` when there is no router above [context].
  static FoldableRouter? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FoldableRouterScope>()?.router;
}
