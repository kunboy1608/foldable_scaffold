// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_page.dart';
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
/// Only the routes the router's matcher knows can be opened from a URL (deep
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

  /// Whether this route has a URL: it is matched from links and shown in the
  /// address bar.
  ///
  /// Routes that only make sense with an object argument (a whole record, a
  /// category) set this to false and are pushed from code only.
  bool get deepLinkable => true;

  /// Builds the screen.
  Widget build(BuildContext context);

  /// This route and its query, e.g. `/record?recordId=3`.
  String get location => RouteQuery.build(path, query);

  /// The URL for the address bar, or null when this route has none.
  String? get urlLocation => deepLinkable ? location : null;

  /// The route to show instead of this one, or null to show this one.
  ///
  /// Runs on every `go`, before the router's global redirect, like a
  /// route-level redirect in go_router. [context] is a [BuildContext] of the
  /// app — the page that called `go`, else the router's navigator — so a
  /// redirect can read providers. [state] says what is being opened.
  ///
  /// Return a future to redirect asynchronously: the navigation waits for it.
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    FoldableRouteState state,
  ) => null;

  /// A [FoldablePage] for this route.
  ///
  /// The page is named after [urlLocation], so the address bar keeps showing
  /// the screen on top.
  FoldablePage<T> toPage<T>() {
    return FoldablePage<T>(
      name: urlLocation,
      child: Builder(builder: build),
    );
  }
}
