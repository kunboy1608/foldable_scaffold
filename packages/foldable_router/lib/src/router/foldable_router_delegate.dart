// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_router.dart';

/// Connects a [FoldableRouter] to the platform: browser address bar and
/// history, deep links and the system back button.
///
/// ```dart
/// MaterialApp.router(
///   routerDelegate: _delegate, // created once, top level
///   routeInformationParser: const FoldableRouteInformationParser(),
///   ...
/// )
///
/// final _delegate = FoldableRouterDelegate(
///   router: appRouter,
///   navigatorKey: rootNavigatorKey,
///   builder: (context) => MyShell(),
/// );
/// ```
class FoldableRouterDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  FoldableRouterDelegate({
    required this.router,
    required this.navigatorKey,
    required this.builder,
    this.observers = const <NavigatorObserver>[],
  }) {
    router.addListener(notifyListeners);
    // Redirects started from code run against the navigator's context.
    router.rootContextOf = () => navigatorKey.currentContext;
  }

  /// The router this delegate drives.
  final FoldableRouterBase router;

  /// Builds the app shell (usually the widget with the [Navigator] pages of
  /// [FoldableRouter.controller]). Called again on every navigation.
  final WidgetBuilder builder;

  /// Observers of the root [Navigator], for dialogs and route events.
  final List<NavigatorObserver> observers;

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Uri get currentConfiguration => router.currentUri;

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    router.goUri(configuration);
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: observers,
      pages: [
        MaterialPage<void>(
          child: PopScope(
            canPop: !router.backGoesToRoot,
            onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
            child: Builder(builder: builder),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }

  /// Handles a back press that did not pop the route.
  ///
  /// Every [PopScope] of the route reports `didPop: false` when any of them
  /// refuses the pop, so a page inside the navigator refusing one also
  /// reaches this callback. Only go to the root when this scope is the one
  /// refusing, or a back that pops a single page would also empty the whole
  /// stack.
  @visibleForTesting
  void onPopInvoked(bool didPop) {
    if (didPop || !router.backGoesToRoot) return;
    router.goBackToRoot();
  }

  @override
  void dispose() {
    router.removeListener(notifyListeners);
    router.rootContextOf = null;
    super.dispose();
  }
}

/// Reads the URL back and forth between the platform and the router.
class FoldableRouteInformationParser extends RouteInformationParser<Uri> {
  const FoldableRouteInformationParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) {
    return SynchronousFuture(routeInformation.uri);
  }

  @override
  RouteInformation? restoreRouteInformation(Uri configuration) {
    return RouteInformation(uri: configuration);
  }
}
