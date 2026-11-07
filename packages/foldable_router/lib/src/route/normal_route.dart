import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_page_transition.dart';
import 'foldable_route.dart';

/// A screen declared like go_router's `GoRoute`: a path, a builder and,
/// optionally, nested [routes].
///
/// A [NormalRoute] is a plain route: it can be pushed, popped and opened like a
/// Flutter route, and it is the leaf that a [FoldableShellRoute] branch (tab)
/// or a full-screen flow shows. Declaring nested [routes] is what lets a deep
/// link to a leaf rebuild the ancestors: opening `/home/calendar/event` shows
/// `Home > Calendar > Event`, the go_router style stack.
///
/// ```dart
/// final home = NormalRoute(
///   path: '/home',
///   builder: (context) => const HomeScreen(),
///   routes: [
///     NormalRoute(
///       path: 'calendar',
///       builder: (context) => const CalendarScreen(),
///       routes: [
///         NormalRoute(path: 'event/:id', builder: (context) => const EventScreen()),
///       ],
///     ),
///   ],
/// );
/// ```
///
/// Subclass [FoldableRoute] directly when a route needs a custom `path` or
/// state, like a [BranchRoute] branch root.
class NormalRoute extends FoldableRoute {
  const NormalRoute({
    required this.path,
    required WidgetBuilder this.builder,
    this.routes = const [],
    this.query = const {},
    this.deepLinkable = true,
    this.transition,
    FutureOr<FoldableRoute?> Function(
      BuildContext context,
      FoldableRouteState state,
    )?
    redirect,
  }) : _redirect = redirect;

  /// Path without query parameters. An absolute path starts with `/`; anything
  /// else is resolved against the parent route's path.
  @override
  final String path;

  /// Builds the screen.
  final WidgetBuilder builder;

  /// Routes nested under this one, shown deeper in the same branch stack.
  @override
  final List<FoldableRoute> routes;

  /// Primitive parameters written into the URL.
  @override
  final Map<String, Object?> query;

  /// Whether this route can be opened from a URL.
  @override
  final bool deepLinkable;

  /// How this route animates when it is pushed or popped, or null for the
  /// transition of the navigator.
  @override
  final FoldablePageTransition? transition;

  final FutureOr<FoldableRoute?> Function(
    BuildContext context,
    FoldableRouteState state,
  )?
  _redirect;

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) => _redirect?.call(context, state);

  @override
  Widget build(BuildContext context) => builder(context);
}
