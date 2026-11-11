import 'dart:async';

import 'package:flutter/widgets.dart';

import 'route_state.dart';

/// A destination in the app.
///
/// Every app route is a subclass; the constructor fields of the subclass are
/// the route's parameters:
///
/// ```dart
/// class UserRoute extends FoldableRoute {
///   const UserRoute({required this.id});
///
///   final String id;
///
///   @override
///   String get path => '/users/detail';
///
///   @override
///   Map<String, String?> get params => {'id': id};
///
///   @override
///   FoldableRoute? get parent => const UsersRoute();
///
///   @override
///   Widget build(BuildContext context) => UserPage(id: id);
/// }
/// ```
///
/// Two routes are equal when they have the same [path] and the same non-null
/// [params].
@immutable
abstract class FoldableRoute {
  /// Const constructor for subclasses.
  const FoldableRoute();

  /// The static path of this route, for example `/users/detail`.
  ///
  /// Paths never contain placeholders such as `:id`; all parameters travel in
  /// the query string (see [params]).
  String get path;

  /// The parameters of this route, written to the URL as the query string.
  ///
  /// Entries with a `null` value are omitted.
  Map<String, String?> get params => const {};

  /// The route shown below this one when it is opened with
  /// `FoldableRouter.open`, or `null` for a root route.
  FoldableRoute? get parent => null;

  /// Decides whether this route may be shown.
  ///
  /// Return `null` to allow the navigation, or another route to go there
  /// instead. Redirects run from the root ancestor down to the target, so this
  /// is also called when a descendant of this route is the target (check
  /// [RouteState.target] to tell the cases apart).
  ///
  /// If this throws, the navigation is cancelled and the error is delivered
  /// through the future returned by `open` / `push`.
  FutureOr<FoldableRoute?> redirect(RouteState state) => null;

  /// Builds the page content for this route.
  Widget build(BuildContext context);

  /// The location of this route: [path] plus a query built from [params].
  Uri get uri {
    final query = _query;
    return Uri(path: path, queryParameters: query.isEmpty ? null : query);
  }

  Map<String, String> get _query => {
    for (final MapEntry(:key, :value) in params.entries) key: ?value,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FoldableRoute || other.path != path) return false;
    final a = _query;
    final b = other._query;
    if (a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      if (b[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    path,
    Object.hashAllUnordered(
      _query.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => '$runtimeType($uri)';
}
