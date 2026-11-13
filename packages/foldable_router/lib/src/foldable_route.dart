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
///   Map<String, Object?> get params => {'id': id};
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
/// [params] *after encoding them to strings*. So `{'id': 1}` and
/// `{'id': '1'}` compare equal, as do two [DateTime]s for the same instant
/// written with different time zones.
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
  /// Values may be a [String], an [int], a [double], a [bool] or a
  /// [DateTime]; any other type, or a non-finite `double` (NaN, infinity),
  /// throws an [ArgumentError] naming the key and the type when the URL is
  /// built. Entries with a `null` value are omitted.
  ///
  /// A [String] is written as is, [int] and [double] through `toString()`, a
  /// [bool] as `true` / `false`, and a [DateTime] converted to UTC first and
  /// written with `toIso8601String()`, so the URL does not depend on the
  /// machine's time zone.
  ///
  /// Equality and [hashCode] compare the *encoded* values, so `{'id': 1}` and
  /// `{'id': '1'}` are the same route, and two [DateTime]s for the same
  /// instant written with different time zones are equal too.
  Map<String, Object?> get params => const {};

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
  /// [context] is the [BuildContext] of the `Router` widget (`WidgetsApp` /
  /// `MaterialApp.router`), the same context go_router hands to its
  /// redirects. It sits *above* the [Navigator], so it is not the context of
  /// any page: an `InheritedWidget` placed above `MaterialApp.router` and
  /// what `MaterialApp` provides ([Theme], [MediaQuery], [Localizations])
  /// can be read from it, but a `Provider` or a `Theme` local to a page
  /// cannot. Because it is not a page's context it never rebuilds a page.
  ///
  /// Read what you need *before* an `await`: the widget tree may change while
  /// the redirect is pending. If you use [context] after an `await`, check
  /// [BuildContext.mounted] first; a redirect resumed after the router was
  /// removed is dropped, like a superseded navigation.
  ///
  /// Careful with reads that *register a dependency* on this context
  /// (`MediaQuery.of` / `MediaQuery.sizeOf`, `Theme.of`,
  /// `Localizations.of`, `context.dependOnInheritedWidgetOfExactType`): when
  /// that inherited widget changes (a resize, a theme switch, a login
  /// `InheritedWidget` flipping), the `Router` re-parses the location it is
  /// showing, and the router runs a *silent re-check*: the redirects of the
  /// stack run again, bottom to top, and a redirect that now returns a route
  /// navigates there.
  ///
  /// A silent re-check never replaces a navigation already in flight
  /// (`open`, `openUri`, `push`, an explicit [FoldableRouter.refresh], a
  /// shell tab switch, or a different platform URL): it waits for that
  /// navigation to finish and then runs once on the stack it left, so the
  /// navigation always completes as if the dependency had not changed.
  /// Changes that land while one navigation is in flight are coalesced into
  /// that single pass. Unlike [FoldableRouter.refresh], a silent re-check
  /// never reports [FoldableRouter.isNavigating]. If every redirect returns
  /// `null` nothing changes (stack, shell branch stacks, pending `push`
  /// futures and listeners); if the stack is empty (the not-found page) it
  /// does nothing. If you want to read a value once without that coupling,
  /// use the non-registering reads, such as
  /// [BuildContext.getInheritedWidgetOfExactType] with the same widget type.
  ///
  /// If this throws, the navigation is cancelled and the error is delivered
  /// through the future returned by `open` / `push`.
  FutureOr<FoldableRoute?> redirect(BuildContext context, RouteState state) =>
      null;

  /// Builds the page content for this route.
  Widget build(BuildContext context);

  /// The location of this route: [path] plus a query built from [params].
  ///
  /// Throws an [ArgumentError] (also in release builds) when a parameter has
  /// an unsupported type or is a non-finite `double`.
  Uri get uri {
    final query = _query;
    return Uri(path: path, queryParameters: query.isEmpty ? null : query);
  }

  /// [params] encoded to strings, with the `null` entries left out.
  Map<String, String> get _query => {
    for (final MapEntry(:key, :value) in params.entries)
      if (value != null) key: _encode(key, value),
  };

  static String _encode(String key, Object value) {
    if (value is String) return value;
    if (value is int) return value.toString();
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(
          value,
          key,
          'is not a finite double; params accept only String, int, double, '
              'bool and DateTime',
        );
      }
      return value.toString();
    }
    if (value is bool) return value ? 'true' : 'false';
    if (value is DateTime) return value.toUtc().toIso8601String();
    throw ArgumentError.value(
      value,
      key,
      'has the unsupported type ${value.runtimeType}; params accept only '
          'String, int, double, bool and DateTime',
    );
  }

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
