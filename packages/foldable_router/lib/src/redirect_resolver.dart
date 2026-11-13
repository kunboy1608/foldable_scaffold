import 'package:flutter/widgets.dart';

import 'foldable_route.dart';
import 'route_state.dart';

/// Base class of the errors raised when redirects cannot be resolved.
sealed class FoldableRedirectException implements Exception {
  const FoldableRedirectException(this.trail);

  /// The targets visited by the navigation, in order, ending with the one
  /// that caused the failure.
  final List<FoldableRoute> trail;
}

/// A navigation was redirected back to a target it had already visited.
final class RedirectLoopException extends FoldableRedirectException {
  /// Creates a loop exception for [trail].
  const RedirectLoopException(super.trail);

  @override
  String toString() => 'RedirectLoopException: ${trail.join(' -> ')}';
}

/// A navigation was redirected more than `maxRedirects` times in a row.
final class RedirectLimitException extends FoldableRedirectException {
  /// Creates a limit exception for [trail].
  const RedirectLimitException(super.trail, this.maxRedirects);

  /// The limit that was exceeded.
  final int maxRedirects;

  @override
  String toString() =>
      'RedirectLimitException: more than $maxRedirects redirects: '
      '${trail.join(' -> ')}';
}

/// Runs the redirect pipeline.
///
/// Every navigation gets a token from [begin]; starting a new one makes all
/// older tokens stale, and stale navigations resolve to `null`. The redirects
/// receive the [BuildContext] of the `Router` widget; if that context is
/// unmounted while a redirect is pending, the navigation is dropped just like
/// a superseded one.
class RedirectResolver {
  /// Creates a resolver allowing at most [maxRedirects] consecutive redirects.
  RedirectResolver({this.maxRedirects = 5}) : assert(maxRedirects >= 0);

  /// Maximum number of consecutive redirects within one navigation.
  final int maxRedirects;

  int _generation = 0;

  /// Starts a new navigation, superseding every pending one.
  int begin() => ++_generation;

  /// Whether [token] still belongs to the latest navigation.
  bool isCurrent(int token) => token == _generation;

  /// The routes from the root ancestor of [route] down to [route] itself.
  static List<FoldableRoute> chainOf(FoldableRoute route) {
    final chain = <FoldableRoute>[];
    for (FoldableRoute? r = route; r != null; r = r.parent) {
      if (chain.contains(r)) {
        throw StateError('Cycle in the parent chain of $route at $r');
      }
      chain.add(r);
    }
    return chain.reversed.toList();
  }

  /// Resolves [target] to the chain (root ancestor first) that should be
  /// shown, following redirects.
  ///
  /// [context] is the [BuildContext] of the `Router` widget, passed to each
  /// redirect. Returns `null` when a newer navigation started in the meantime
  /// or when [context] was unmounted. Throws a [FoldableRedirectException] on
  /// a loop or when [maxRedirects] is exceeded, and rethrows whatever a
  /// `redirect` throws.
  ///
  /// Starts a new navigation unless [token] (from [begin]) is given.
  Future<List<FoldableRoute>?> resolve(
    FoldableRoute target, {
    required BuildContext context,
    int? token,
  }) async {
    final t = token ?? begin();
    final trail = <FoldableRoute>[target];
    var current = target;
    while (true) {
      final chain = chainOf(current);
      final next = await firstRedirect(
        chain,
        context: context,
        target: current,
        token: t,
      );
      if (!isCurrent(t) || !context.mounted) return null;
      if (next == null) return chain;
      trail.add(next);
      if (trail.indexOf(next) != trail.length - 1) {
        throw RedirectLoopException(List.unmodifiable(trail));
      }
      if (trail.length - 1 > maxRedirects) {
        throw RedirectLimitException(List.unmodifiable(trail), maxRedirects);
      }
      current = next;
    }
  }

  /// Runs `redirect` on [routes] in order and returns the first non-null
  /// answer, or `null` when every route allows the navigation, [token] went
  /// stale, or [context] was unmounted (check [isCurrent] and
  /// [BuildContext.mounted] to tell them apart).
  ///
  /// A redirect is never called with an unmounted [context], nor is a
  /// redirect resumed after its `await` with one.
  Future<FoldableRoute?> firstRedirect(
    Iterable<FoldableRoute> routes, {
    required BuildContext context,
    required FoldableRoute target,
    required int token,
  }) async {
    for (final route in routes) {
      if (!context.mounted) return null;
      final FoldableRoute? next;
      try {
        next = await route.redirect(
          context,
          RouteState(route: route, target: target),
        );
      } catch (_) {
        if (!isCurrent(token) || !context.mounted) return null;
        rethrow;
      }
      if (!isCurrent(token) || !context.mounted) return null;
      if (next != null) return next;
    }
    return null;
  }
}
