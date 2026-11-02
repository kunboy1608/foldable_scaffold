import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';

import '../route/foldable_route.dart';
import 'foldable_router.dart';
import 'foldable_router_observer.dart';

/// The route for [uri], or null when no route matches.
typedef FoldableRouteMatcher = FoldableRoute? Function(Uri uri);

/// Builds the route shown for a [uri] that matches nothing.
typedef FoldableRouteFactory = FoldableRoute Function(Uri uri);

/// A global redirect, like go_router's top-level `redirect`.
typedef FoldableRedirect =
    FutureOr<FoldableRoute?> Function(
      BuildContext context,
      FoldableRouteState state,
    );

/// The branch a route belongs to, or null when it is not a branch root.
typedef FoldableBranchOf = int? Function(FoldableRoute route);

/// Where back goes when the current branch has no page to pop, or null to
/// leave the app.
typedef FoldableBackTarget = FoldableRoute? Function(FoldableRouter router);

/// Everything a [FoldableRouter] needs to know about an app.
///
/// ```dart
/// final config = FoldableRouterConfig(
///   roots: const [HomeRoute(), InboxRoute(), ProfileRoute()],
///   matcher: matchRoute,
///   notFound: NotFoundRoute.new,
///   branchOf: (route) => route.tabIndex,
///   redirect: (context, state) =>
///       state.isLoggedIn ? null : const SignInRoute(),
///   backTarget: (router) =>
///       router.currentIndex == 0 ? null : const HomeRoute(),
/// );
/// ```
class FoldableRouterConfig {
  const FoldableRouterConfig({
    required this.roots,
    required this.matcher,
    required this.notFound,
    this.redirect,
    this.stateExtra,
    this.branchOf,
    this.backTarget,
    this.observers = const <FoldableRouterObserver>[],
    this.maxRedirects = 5,
    this.throwOnRedirectLoop = kDebugMode,
    this.lazyBranches = true,
  });

  /// The bottom page of every branch: the tabs of the app.
  ///
  /// A root also builds the URL of its branch, for example `/home`, and is
  /// where back goes when the branch has no page to pop and
  /// [FoldableRouterConfig.backTarget] says so.
  ///
  /// Empty is only valid for a stack session (`FoldableNavigatorKind.stack`):
  /// the stack starts blank and its first navigation fills it. A split
  /// navigator needs at least one root.
  final List<FoldableRoute> roots;

  /// The route for a URL, or null when no route matches.
  ///
  /// The platform opens `/` first. When the matcher returns null for `/`, the
  /// router shows the first of [roots] instead of [notFound].
  final FoldableRouteMatcher matcher;

  /// The route shown for a URL that matches nothing.
  final FoldableRouteFactory notFound;

  /// Runs on every navigation, after [FoldableRoute.redirect], like
  /// go_router's top-level `redirect`. Return the route to show instead, or
  /// null to keep the current one.
  ///
  /// This is where a login guard lives.
  final FoldableRedirect? redirect;

  /// App data handed to redirects as [FoldableRouteState.extra], for example
  /// whether the user is logged in.
  final Object? Function()? stateExtra;

  /// The branch a route belongs to, for routes that are branch roots.
  ///
  /// Defaults to comparing [FoldableRoute.location] with the roots.
  final FoldableBranchOf? branchOf;

  /// Where the system back button goes when the current branch has no page to
  /// pop, instead of leaving the app. Null (the default) leaves the app.
  final FoldableBackTarget? backTarget;

  /// Listeners told about every navigation, for logging and dev tools.
  final List<FoldableRouterObserver> observers;

  /// How many redirects a single navigation may chain. Stops a loop of
  /// redirects from hanging the app.
  ///
  /// A navigation whose redirects still want to continue after this many
  /// is a loop; see [throwOnRedirectLoop] for what happens then.
  final int maxRedirects;

  /// What a redirect loop (more than [maxRedirects] redirects in one
  /// navigation) does.
  ///
  /// When true (the default in debug builds) the navigation fails with a
  /// [FlutterError] that lists the chain of routes, so the loop is fixed during
  /// development. When false (the default in release builds) the app shows the
  /// [notFound] route instead, and the error is still reported through
  /// [FlutterError.reportError] so a crash reporter sees it. The route the loop
  /// ended on is never shown: it may be the very route a redirect guards.
  final bool throwOnRedirectLoop;

  /// Whether branches other than the first build their screen on the first
  /// visit instead of at startup.
  final bool lazyBranches;
}
