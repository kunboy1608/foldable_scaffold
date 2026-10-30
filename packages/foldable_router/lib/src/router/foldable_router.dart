// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_navigator.dart';
import '../lazy_branch.dart';
import '../route/foldable_route.dart';
import 'foldable_router_config.dart';
import 'foldable_router_observer.dart';

/// What [FoldableRouterDelegate] needs from a router, so that a router can be
/// swapped (for example between the signed in and signed out stacks) without
/// touching the delegate.
///
/// [FoldableRouter] implements it; apps that own more than one router can mix
/// it into their own coordinator, like a session router.
mixin FoldableRouterBase on Listenable {
  /// Where redirects get a [BuildContext] when a navigation starts without
  /// one.
  ///
  /// [FoldableRouterDelegate] points it at its navigator.
  BuildContext? Function()? get rootContextOf => _rootContextOf;
  set rootContextOf(BuildContext? Function()? value) => _rootContextOf = value;
  // ignore: prefer_final_fields
  BuildContext? Function()? _rootContextOf;

  /// The URL for the address bar: the top page that has one.
  Uri get currentUri;

  /// Applies a URL that came from outside (browser back and forward, a link).
  void goUri(Uri uri);

  /// Whether system back should show something inside the app instead of
  /// leaving it.
  bool get backGoesToRoot;

  /// Shows the route [backGoesToRoot] promised, usually a branch root.
  void goBackToRoot();

  /// Adds an observer of every navigation, for example a dev tools log.
  void addObserver(FoldableRouterObserver observer) {}

  /// Removes [observer].
  void removeObserver(FoldableRouterObserver observer) {}
}

/// Navigation on top of [FoldableNavigator]: one page stack per branch
/// (tab), deep links, redirects and guards.
///
/// ```dart
/// final router = FoldableRouter(config: FoldableRouterConfig(...));
///
/// // From code:
/// router.push(const DetailsRoute());
/// router.go(context, const SettingsRoute());
///
/// // In MaterialApp.router:
/// routerDelegate: FoldableRouterDelegate(
///   router: router,
///   navigatorKey: rootNavigatorKey,
///   builder: (context) => MyScaffold(controller: router.controller),
/// ),
/// routeInformationParser: const FoldableRouteInformationParser(),
/// ```
///
/// Two ways to show a screen:
///
/// * [push] adds it on top of the current branch and leaves everything below
///   untouched.
/// * [go] replaces the children of the page that navigated, so back returns to
///   that page instead of to the branch root.
///
/// Only [go] follows the redirects ([FoldableRoute.redirect] and
/// [FoldableRouterConfig.redirect]), so the URL and the login state stay in
/// charge of what a navigation actually shows.
class FoldableRouter extends ChangeNotifier with FoldableRouterBase {
  FoldableRouter({required this.config})
    : _observers = List.of(config.observers),
      _controller = _createController(config) {
    _controller.addListener(notifyListeners);
  }

  /// The app description of this router.
  final FoldableRouterConfig config;

  final FoldableNavigatorController _controller;
  final List<FoldableRouterObserver> _observers;

  @override
  void addObserver(FoldableRouterObserver observer) {
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  @override
  void removeObserver(FoldableRouterObserver observer) {
    _observers.remove(observer);
  }

  static FoldableNavigatorController _createController(
    FoldableRouterConfig config,
  ) {
    return FoldableNavigatorController(
      branches: [
        for (var index = 0; index < config.roots.length; index++)
          [_rootPage(config, index)],
      ],
    );
  }

  static Page<void> _rootPage(FoldableRouterConfig config, int index) {
    final route = config.roots[index];
    final child = Builder(builder: route.build);
    return FoldablePage<void>(
      name: route.urlLocation,
      child: config.lazyBranches && index > 0
          ? LazyBranch(branch: index, child: child)
          : child,
    );
  }

  /// The page stacks this router drives.
  FoldableNavigatorController get controller => _controller;

  /// Number of branches (tabs).
  int get branchCount => _controller.branchCount;

  /// The branch on screen.
  int get currentIndex => _controller.currentIndex;

  /// Whether the current branch has a page to pop.
  bool get canPop => _controller.canPop;

  /// Pages of the current branch, bottom first.
  List<Page<Object?>> get pages => _controller.pages;

  /// Number of the latest [go]. Used to drop the result of a redirect that
  /// finished after the user navigated again.
  int _navigations = 0;

  /// Where back goes when the current branch has no page to pop, or null to
  /// leave the app.
  FoldableRoute? get backTarget => config.backTarget?.call(this);

  @override
  bool get backGoesToRoot => !_controller.canPop && backTarget != null;

  @override
  void goBackToRoot() {
    final target = backTarget;
    if (target != null) go(null, target);
  }

  /// The route for [location] (`/record?recordId=1`), or a not-found route.
  FoldableRoute routeOf(String location) {
    final uri = Uri.parse(location);
    return config.matcher(uri) ?? config.notFound(uri);
  }

  /// Follows [FoldableRoute.redirect] and then the router's redirect until a
  /// route stays, like go_router's redirect chain.
  ///
  /// Returns the final route right away while every redirect is synchronous,
  /// and a [Future] as soon as one of them returns one.
  FutureOr<FoldableRoute> resolve(
    FoldableRoute route, {
    required BuildContext context,
    Uri? uri,
  }) {
    return _resolve(context, route, 0, uri ?? Uri.parse(route.location));
  }

  FutureOr<FoldableRoute> _resolve(
    BuildContext context,
    FoldableRoute current,
    int step,
    Uri uri,
  ) {
    if (step >= config.maxRedirects) return current;
    final state = FoldableRouteState(
      route: current,
      uri: uri,
      extra: config.stateExtra?.call(),
    );
    final next = _orElse(
      current.redirect(context, state),
      () => config.redirect?.call(context, state),
    );
    if (next is Future<FoldableRoute?>) {
      return next.then((value) {
        if (value == null) return current;
        // The page that started the navigation may be gone by now.
        if (!context.mounted) return current;
        return _resolve(context, value, step + 1, uri);
      });
    }
    return next == null ? current : _resolve(context, next, step + 1, uri);
  }

  /// [second] only when [first] is null, without waiting for a value that is
  /// already there.
  static FutureOr<FoldableRoute?> _orElse(
    FutureOr<FoldableRoute?> first,
    FutureOr<FoldableRoute?> Function() second,
  ) {
    if (first is Future<FoldableRoute?>) {
      return first.then((value) => value ?? second());
    }
    return first ?? second();
  }

  /// Shows [route] in place of the children of the page that owns [context].
  ///
  /// That page stays, every page above it is dropped, and back from [route]
  /// returns to it. Without a [context] — or with one outside the navigator,
  /// as in [goUri] — the branch root is the parent instead.
  void go(BuildContext? context, FoldableRoute route) {
    _go(
      route,
      context == null ? null : FoldableNavigator.pageOf(context),
      context: context,
    );
  }

  /// [go] with the parent page already known: the page whose children are
  /// replaced.
  @visibleForTesting
  void goFromPage(Page<Object?>? parent, FoldableRoute route) =>
      _go(route, parent);

  void _go(
    FoldableRoute route,
    Page<Object?>? parent, {
    BuildContext? context,
    Uri? uri,
  }) {
    _resolveAndApply(++_navigations, route, parent, context, uri);
  }

  /// Follows the redirects and applies the result, unless a newer navigation
  /// started in the meantime.
  void _resolveAndApply(
    int navigation,
    FoldableRoute route,
    Page<Object?>? parent,
    BuildContext? callerContext,
    Uri? uri,
  ) {
    // The redirects get the page that navigated, else the router's navigator.
    final context = callerContext ?? rootContextOf?.call();
    if (context == null) {
      // No BuildContext yet, as when a link is handled before the first build:
      // try again on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (navigation == _navigations) {
          _resolveAndApply(navigation, route, parent, callerContext, uri);
        }
      });
      return;
    }
    final target = resolve(route, context: context, uri: uri);
    if (target is Future<FoldableRoute>) {
      target.then((resolved) {
        if (navigation == _navigations) apply(resolved, parent: parent);
      });
      return;
    }
    apply(target, parent: parent);
  }

  /// Shows [target] at the position of [parent] (default: the branch root),
  /// switching branch when [target] is a branch root.
  ///
  /// The result of a redirect, and what [go] ends up calling.
  void apply(FoldableRoute target, {Page<Object?>? parent}) {
    final branch = config.branchOf?.call(target) ?? _defaultBranchOf(target);
    if (branch != null) {
      // Switch and pop in one update, so the branch is rendered once, already
      // at its root.
      _controller.batch(() {
        _controller.popToRoot(branch: branch);
        _controller.goBranch(branch);
      });
    } else {
      _replaceChildren(parent, target);
    }
    _emit(FoldableNavigationKind.go, target);
  }

  int? _defaultBranchOf(FoldableRoute route) {
    for (var index = 0; index < config.roots.length; index++) {
      if (config.roots[index].urlLocation == route.urlLocation) return index;
    }
    return null;
  }

  /// Cuts the current stack down to [parent] and adds [target] on top of it.
  /// Without a parent in the stack, the branch root is the parent.
  void _replaceChildren(Page<Object?>? parent, FoldableRoute target) {
    final pages = _controller.pages;
    final index = parent == null ? -1 : pages.indexOf(parent);
    final kept = pages.take(index + 1 > 0 ? index + 1 : 1).toList();
    // Going to the page that navigated only removes what is above it.
    if (parent != null && parent.name == target.urlLocation) {
      _controller.setPages(kept);
      return;
    }
    _controller.setPages([...kept, target.toPage<void>()]);
  }

  /// Shows the route for [location].
  void goLocation(String location) {
    _go(routeOf(location), null, uri: Uri.parse(location));
  }

  /// Adds [route] on top of the current branch. Completes with the result of
  /// the page, like `Navigator.push`.
  ///
  /// Unlike [go] this never redirects and never switches branch: the page is
  /// added exactly where the user is.
  Future<T?> push<T extends Object?>(FoldableRoute route) {
    final future = _controller.push<T>(route.toPage<T>());
    _emit(FoldableNavigationKind.push, route);
    return future;
  }

  /// Adds the route for [location] on top of the current branch.
  Future<void> pushLocation(String location) {
    return push<void>(routeOf(location));
  }

  /// Removes the top page of the current branch.
  ///
  /// Returns whether a page was removed. See
  /// [FoldableNavigatorController.pop].
  bool pop([Object? result]) => _controller.pop(result);

  /// Removes [page] and the pages above it from the branch that holds it, so
  /// a page in the body pane of a split view can pop itself.
  ///
  /// See [FoldableNavigatorController.popPage].
  bool popPage(Page<Object?> page, [Object? result]) =>
      _controller.popPage(page, result);

  /// Removes pages from the top of the current branch until [predicate] is
  /// true for the top page. The first page is never removed.
  void popUntil(bool Function(Page<Object?> page) predicate) {
    _controller.popUntil(predicate);
  }

  /// Removes every page of the current branch except the first one.
  void popToRoot() => _controller.popToRoot();

  /// Replaces all pages of the current branch at once.
  void setPages(List<Page<Object?>> pages) => _controller.setPages(pages);

  /// Runs [mutations] and notifies listeners once, after all of them are
  /// applied.
  void batch(void Function() mutations) => _controller.batch(mutations);

  /// Adds [route] on top of the current branch after removing pages, like
  /// [Navigator.pushAndRemoveUntil].
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    FoldableRoute route,
    bool Function(Page<Object?> page) predicate,
  ) {
    final future = _controller.pushAndRemoveUntil<T>(
      route.toPage<T>(),
      predicate,
    );
    _emit(FoldableNavigationKind.push, route);
    return future;
  }

  /// Removes the top page. When there is none to remove, shows [fallback] or
  /// the [backTarget].
  void back([FoldableRoute? fallback]) {
    if (_controller.pop()) {
      _emit(FoldableNavigationKind.pop, null);
      return;
    }
    final target = fallback ?? backTarget;
    if (target != null) _go(target, null);
  }

  /// The URL for the address bar: the top page that has one.
  @override
  Uri get currentUri {
    for (final page in _controller.pages.reversed) {
      final name = page.name;
      if (name != null) return Uri.parse(name);
    }
    return Uri.parse('/');
  }

  @override
  void goUri(Uri uri) {
    if (uri.toString() == currentUri.toString()) return;

    final pages = _controller.pages;
    final below = pages.length > 1 ? pages[pages.length - 2].name : null;
    if (below != null && below == uri.toString()) {
      _controller.pop();
      _emit(FoldableNavigationKind.pop, null);
      return;
    }
    _go(config.matcher(uri) ?? config.notFound(uri), null, uri: uri);
  }

  void _emit(FoldableNavigationKind kind, FoldableRoute? route) {
    if (_observers.isEmpty) return;
    final event = FoldableNavigationEvent(
      kind: kind,
      route: route,
      uri: currentUri,
      branch: currentIndex,
      depth: _controller.pages.length,
    );
    for (final observer in List.of(_observers)) {
      observer.onNavigation(event);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(notifyListeners);
    _controller.dispose();
    super.dispose();
  }
}
