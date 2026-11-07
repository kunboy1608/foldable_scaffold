import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_page.dart';
import '../foldable_page_transition.dart';
import '../router/foldable_router.dart';
import 'route_query.dart';

/// What a redirect can look at, like go_router's `GoRouterState`.
@immutable
class FoldableRouteState {
  const FoldableRouteState({
    required this.route,
    required this.uri,
    this.extra,
  });

  /// The route that is about to be shown.
  final FoldableRoute route;

  /// The location the navigation started with, e.g. `/record?recordId=3`.
  ///
  /// It stays the same while redirecting; read [route] for the current step.
  final Uri uri;

  /// App data handed to [FoldableRoute.redirect], from
  /// [FoldableRouterConfig.stateExtra]. For example, whether the user is
  /// logged in.
  final Object? extra;
}

/// A screen that a `FoldableRouter` can show.
///
/// Only deep-linkable routes the router's matcher knows can be opened from a URL (deep
/// link or the browser address bar), and their parameters are written into the
/// URL as primitives only. Every route can still be pushed from code, with any
/// object passed to its constructor.
@immutable
abstract class FoldableRoute {
  const FoldableRoute();

  /// Path without query parameters, e.g. `/record`.
  String get path;

  /// Primitive parameters written into the URL.
  Map<String, Object?> get query => const {};

  /// Whether this route can be opened from a URL.
  ///
  /// * true: the route can be opened from the browser address bar and from a
  ///   deep link, and its URL ([urlLocation]) is shown in the address bar.
  /// * false: a URL never opens it (the router treats it as not matched, so
  ///   [FoldableRouterConfig.notFound] is shown) and it has no URL in the
  ///   address bar. It can only be pushed or opened from code, with any
  ///   object passed to its constructor.
  ///
  /// Use false for routes that need an object argument or must not be reachable
  /// from outside, such as a confirmation step.
  bool get deepLinkable => true;

  /// The id of the `FoldableSession` that shows this route, or null for the
  /// session on screen.
  ///
  /// With a `FoldableSessionRouter`, `open`/`push` of a route that names another
  /// session first puts that session on top: it is created when it is not
  /// open, or moved to the top when it is. Redirects and the route then run in
  /// that session. URLs ignore it: a location is matched in the session on
  /// screen (see `FoldableSession.deepLinkable`).
  String? get session => null;

  /// Builds the screen.
  Widget build(BuildContext context);

  /// What a page shows for this route. Calls [build]; a [BranchRoute] wraps
  /// it. Override [build], not this.
  Widget buildPage(BuildContext context) => build(context);

  /// This route and its query, e.g. `/record?recordId=3`.
  String get location => RouteQuery.build(path, query);

  /// The URL for the address bar, or null when this route has none.
  String? get urlLocation => deepLinkable ? location : null;

  /// The route to show instead of this one, or null to show this one.
  ///
  /// Runs on every `open`, before the router's global redirect, like a
  /// route-level redirect in go_router. [context] is a [BuildContext] of the
  /// app — the page that called `open`, else the router's navigator — so a
  /// redirect can read providers. [state] says what is being opened.
  ///
  /// Return a future to redirect asynchronously: the navigation waits for it.
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) => null;

  /// How this route animates when it is pushed or popped, or null for the
  /// transition of the navigator.
  FoldablePageTransition? get transition => null;

  /// A [FoldablePage] for this route.
  ///
  /// The page is named after [urlLocation], so the address bar keeps showing
  /// the screen on top.
  FoldablePage<T> toPage<T>() {
    return FoldablePage<T>(
      name: urlLocation,
      transition: transition,
      child: Builder(builder: buildPage),
    );
  }

  /// Shows this route in place of the children of the page that owns
  /// [context]. Shorthand for [FoldableRouter.open].
  void open(BuildContext context) =>
      FoldableRouterScope.of(context).open(context, this);

  /// Adds this route on top of the current branch. See [FoldableRouter.push].
  Future<T?> push<T extends Object?>(BuildContext context) =>
      FoldableRouterScope.of(context).push<T>(this, context: context);

  /// Replaces the top page with this route. See
  /// [FoldableRouter.pushAndReplace].
  Future<T?> pushAndReplace<T extends Object?>(BuildContext context) =>
      FoldableRouterScope.of(context).pushAndReplace<T>(this, context: context);

  /// Adds this route after removing pages until [predicate] is true. See
  /// [FoldableRouter.pushAndRemoveUntil].
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    BuildContext context,
    bool Function(Page<Object?> page) predicate,
  ) => FoldableRouterScope.of(
    context,
  ).pushAndRemoveUntil<T>(this, predicate, context: context);
}
