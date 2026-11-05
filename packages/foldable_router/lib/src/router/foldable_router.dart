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

  /// A snapshot of the page stacks for state restoration, or null when this
  /// router has nothing to save.
  ///
  /// It must be made of what the standard message codec carries (maps with
  /// string keys, lists, strings, numbers, booleans). The default saves
  /// nothing, so a router written against an earlier version keeps working
  /// with [FoldableRouterDelegate.restorationId].
  Map<String, Object?>? saveState() => null;

  /// Rebuilds the page stacks from a snapshot made by [saveState].
  ///
  /// It must ignore a snapshot that does not fit the router (it may come from
  /// an older version of the app), and it must neither redirect nor tell
  /// observers: it brings back what the user saw. The default does nothing.
  void restoreState(Map<String, Object?> state) {}

  /// Adds an observer of every navigation, for example a dev tools log.
  void addObserver(FoldableRouterObserver observer) {}

  /// Removes [observer].
  void removeObserver(FoldableRouterObserver observer) {}

  /// Gives the router the app's shared [FoldableRouterConfig].
  /// [FoldableRouterDelegate] calls it with its `config`. The default does
  /// nothing.
  void attachConfig(FoldableRouterConfig config) {}

  /// Whether [closeSession] would close a session. False unless the router
  /// stacks sessions, see [FoldableSessionRouter].
  bool get canCloseSession => false;

  /// Closes the session on screen and shows the one below, with [result] for
  /// the future of [openSession]. Returns whether one was closed.
  bool closeSession([Object? result]) => false;

  /// Opens session [id] over the one on screen. See
  /// [FoldableSessionRouter.openSession]; the default throws.
  Future<T?> openSession<T extends Object?>(
    String id, {
    FoldableRoute? route,
  }) => throw UnsupportedError('$runtimeType does not support sessions.');

  /// See [FoldableRouter.go]. Needed by [FoldableRoute.go]; the default
  /// throws.
  void go(BuildContext? context, FoldableRoute route) =>
      throw UnsupportedError('$runtimeType does not support go.');

  /// See [FoldableRouter.push]. Needed by [FoldableRoute.push]; the default
  /// throws.
  Future<T?> push<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) => throw UnsupportedError('$runtimeType does not support push.');

  /// See [FoldableRouter.pushAndReplace]. Needed by
  /// [FoldableRoute.pushAndReplace]; the default throws.
  Future<T?> pushAndReplace<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) => throw UnsupportedError('$runtimeType does not support pushAndReplace.');

  /// See [FoldableRouter.pushAndRemoveUntil]. Needed by
  /// [FoldableRoute.pushAndRemoveUntil]; the default throws.
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    FoldableRoute route,
    bool Function(Page<Object?> page) predicate, {
    BuildContext? context,
  }) => throw UnsupportedError(
    '$runtimeType does not support pushAndRemoveUntil.',
  );
}

/// Gives the pages below a [FoldableRouterDelegate] their router, so a route
/// can navigate itself: `const DetailsRoute().push(context)`.
class FoldableRouterScope extends InheritedWidget {
  const FoldableRouterScope({
    required this.router,
    required super.child,
    super.key,
  });

  final FoldableRouterBase router;

  /// The router of the closest [FoldableRouterDelegate], if any.
  static FoldableRouterBase? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<FoldableRouterScope>()?.router;
  }

  /// Like [maybeOf], but asserts that there is one.
  static FoldableRouterBase of(BuildContext context) {
    final router = maybeOf(context);
    assert(router != null, 'No FoldableRouterDelegate found in context.');
    return router!;
  }

  @override
  bool updateShouldNotify(FoldableRouterScope oldWidget) =>
      router != oldWidget.router;
}

/// Navigation on top of [FoldableNavigator]: one page stack per branch
/// (tab), deep links, redirects and guards.
///
/// ```dart
/// final router = FoldableRouter(roots: const [HomeRoute(), SettingsRoute()]);
///
/// // From code:
/// router.push(const DetailsRoute());
/// router.go(context, const SettingsRoute());
///
/// // In MaterialApp.router:
/// routerDelegate: FoldableRouterDelegate(
///   router: router,
///   config: FoldableRouterConfig(matcher: matchRoute, notFound: NotFoundRoute.new),
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
  FoldableRouter({
    required this.roots,
    FoldableRouterConfig? config,
    this.allowEmptyRoots = false,
  }) : _config = config,
       _observers = List.of(config?.observers ?? const []) {
    _remember();
    _controller.addListener(_onControllerChanged);
  }

  /// The bottom page of every branch: the tabs of this router.
  ///
  /// A root also builds the URL of its branch, for example `/home`, and is
  /// where back goes when the branch has no page to pop and
  /// [FoldableRouterConfig.backTarget] says so.
  final List<FoldableRoute> roots;

  FoldableRouterConfig? _config;

  /// The app description of this router, given by the constructor or by
  /// [attachConfig] (the [FoldableRouterDelegate] does that).
  FoldableRouterConfig get config {
    final config = _config;
    if (config == null) {
      throw StateError(
        'FoldableRouter has no FoldableRouterConfig. Pass config to '
        'FoldableRouterDelegate, or to the router.',
      );
    }
    return config;
  }

  @override
  void attachConfig(FoldableRouterConfig config) {
    _config = config;
    for (final observer in config.observers) {
      if (!_observers.contains(observer)) _observers.add(observer);
    }
  }

  /// Whether [roots] may be empty.
  ///
  /// A router without roots starts with an empty stack: the first navigation
  /// fills it. Use it with a [FoldableStackNavigator]; a
  /// [FoldableSplitNavigator] needs a page in every branch.
  ///
  /// [FoldableSessionRouter] sets it for a `FoldableSessionStack` without an
  /// `initRoute`.
  final bool allowEmptyRoots;

  late final FoldableNavigatorController _controller = _createController(
    roots,
    allowEmptyRoots,
  );
  final List<FoldableRouterObserver> _observers;

  /// The branch and the pages of that branch at the last navigation that was
  /// reported to the observers. A change of the controller that differs from
  /// it was not announced by the router itself.
  int _knownIndex = 0;
  List<Page<Object?>> _knownPages = const [];

  /// How many router operations are running that announce their own event.
  /// While it is not zero the controller changes are not reported twice.
  int _announcing = 0;

  /// Pushes that wait for a redirect or for earlier pushes, and the moment the
  /// last of them has been applied. See [_pushResolved].
  int _pushesWaiting = 0;
  Future<void> _lastPushTurn = Future.value();

  @override
  void addObserver(FoldableRouterObserver observer) {
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  @override
  void removeObserver(FoldableRouterObserver observer) {
    _observers.remove(observer);
  }

  FoldableNavigatorController _createController(
    List<FoldableRoute> roots,
    bool allowEmptyRoots,
  ) {
    if (roots.isEmpty) {
      assert(
        allowEmptyRoots,
        'Needs at least one root route. Only a stack session may start with '
        'no roots.',
      );
      return FoldableNavigatorController.empty();
    }
    return FoldableNavigatorController(
      branches: [
        for (var index = 0; index < roots.length; index++)
          [_rootPage(roots, index)],
      ],
    );
  }

  Page<void> _rootPage(List<FoldableRoute> roots, int index) {
    final route = roots[index];
    final child = Builder(builder: route.buildPage);
    return FoldablePage<void>(
      name: route.urlLocation,
      // The config may arrive after the router, so it is read when the page
      // is built.
      child: index == 0
          ? child
          : Builder(
              builder: (context) => (_config?.lazyBranches ?? true)
                  ? LazyBranch(branch: index, child: child)
                  : child,
            ),
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

  /// Whether [dispose] ran. Stops a navigation that waits for a
  /// [rootContextOf] that will never come from scheduling frames forever.
  bool _disposed = false;

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
  FoldableRoute routeOf(String location) => _routeOfUri(Uri.parse(location));

  /// The route the matcher gives for [uri]. The platform opens `/` first, and
  /// a matcher that does not know it would show the not-found page at startup:
  /// show the first root instead.
  FoldableRoute _routeOfUri(Uri uri) {
    final matched = config.match(uri);
    if (matched != null) return matched;
    if (roots.isNotEmpty && (uri.path.isEmpty || uri.path == '/')) {
      return roots.first;
    }
    return config.notFound(uri);
  }

  /// Follows [FoldableRoute.redirect] and then the router's redirect until a
  /// route stays, like go_router's redirect chain.
  ///
  /// Returns the final route right away while every redirect is synchronous,
  /// and a [Future] as soon as one of them returns one.
  ///
  /// An exception thrown by a redirect reaches the caller, as an error of the
  /// [Future] once a redirect is asynchronous. [go] and the other navigations
  /// of the router report it with [FlutterError.reportError] and abandon the
  /// navigation instead.
  ///
  /// The result is null when the navigation is abandoned: an asynchronous
  /// redirect finished after [context] and the router's navigator were gone,
  /// so the redirect chain cannot continue. The caller must not show the
  /// original route then, it may be the very route a redirect guards.
  ///
  /// More than [FoldableRouterConfig.maxRedirects] redirects in one navigation
  /// is a loop: see [FoldableRouterConfig.throwOnRedirectLoop].
  FutureOr<FoldableRoute?> resolve(
    FoldableRoute route, {
    required BuildContext context,
    Uri? uri,
  }) {
    return _resolve(context, route, 0, uri ?? Uri.parse(route.location), [
      route.location,
    ]);
  }

  FutureOr<FoldableRoute?> _resolve(
    BuildContext context,
    FoldableRoute current,
    int step,
    Uri uri,
    List<String> trail,
  ) {
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
        if (step >= config.maxRedirects) {
          return _redirectLoop(uri, [...trail, value.location]);
        }
        // The page that started the navigation may be gone by now: continue
        // with the router's navigator, or abandon the navigation. Returning
        // [current] here would skip the redirect that was just decided.
        final live = context.mounted ? context : rootContextOf?.call();
        if (live == null || !live.mounted) return null;
        return _resolve(live, value, step + 1, uri, [...trail, value.location]);
      });
    }
    if (next == null) return current;
    if (step >= config.maxRedirects) {
      return _redirectLoop(uri, [...trail, next.location]);
    }
    return _resolve(context, next, step + 1, uri, [...trail, next.location]);
  }

  /// A navigation kept redirecting past [FoldableRouterConfig.maxRedirects].
  ///
  /// Throws in development, so the loop gets fixed; otherwise reports the
  /// error and shows the not-found route. Neither shows the route the loop
  /// stopped on, which may be the one a redirect guards.
  FoldableRoute _redirectLoop(Uri uri, List<String> trail) {
    final error = FlutterError.fromParts([
      ErrorSummary(
        'Too many redirects (more than ${config.maxRedirects}) while opening '
        '$uri.',
      ),
      ErrorDescription('The redirects led through: ${trail.join(' -> ')}'),
      ErrorHint(
        'A redirect probably sends the user back to a route that redirects '
        'again. Make it return null once the user is where it wants them, or '
        'raise FoldableRouterConfig.maxRedirects for a longer chain.',
      ),
    ]);
    if (config.throwOnRedirectLoop) throw error;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        library: 'foldable_router',
        context: ErrorDescription('while resolving a redirect'),
      ),
    );
    return config.notFound(uri);
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
  @override
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
    if (_disposed) return;
    // The redirects get the page that navigated, else the router's navigator.
    final context = callerContext ?? rootContextOf?.call();
    if (context == null) {
      // No BuildContext yet, as when a link is handled before the first build:
      // try again on the next frame. Post-frame callbacks do not schedule a
      // frame, so ask for one or the retry could wait forever.
      WidgetsBinding.instance
        ..addPostFrameCallback((_) {
          if (!_disposed && navigation == _navigations) {
            _resolveAndApply(navigation, route, parent, callerContext, uri);
          }
        })
        ..scheduleFrame();
      return;
    }
    final FutureOr<FoldableRoute?> target;
    try {
      target = resolve(route, context: context, uri: uri);
    } catch (error, stack) {
      _reportRedirectError(error, stack);
      return;
    }
    if (target is Future<FoldableRoute?>) {
      target.then<void>((resolved) {
        if (resolved != null && navigation == _navigations) {
          apply(resolved, parent: parent);
        }
      }, onError: _reportRedirectError);
      return;
    }
    if (target != null) apply(target, parent: parent);
  }

  /// A redirect threw: tell Flutter and abandon the navigation. Showing the
  /// route that was asked for would skip the redirect, and that route may be
  /// the very one the redirect guards.
  void _reportRedirectError(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'foldable_router',
        context: ErrorDescription('while resolving a redirect'),
      ),
    );
  }

  /// Shows [target] at the position of [parent] (default: the branch root),
  /// switching branch when [target] is a branch root.
  ///
  /// The result of a redirect, and what [go] ends up calling.
  void apply(FoldableRoute target, {Page<Object?>? parent}) {
    // An empty stack has no branch root to switch to yet: show the target as
    // its first page, even when it is a tab root.
    final branch = _controller.pages.isEmpty
        ? null
        : config.branchOf?.call(target) ?? _defaultBranchOf(target);
    _announce(() {
      if (branch != null) {
        // Switch and pop in one update, so the branch is rendered once,
        // already at its root.
        _controller.batch(() {
          _controller.popToRoot(branch: branch);
          _controller.goBranch(branch);
        });
      } else {
        _replaceChildren(parent, target);
      }
    });
    _emit(FoldableNavigationKind.go, target);
  }

  int? _defaultBranchOf(FoldableRoute route) {
    for (var index = 0; index < roots.length; index++) {
      if (roots[index].urlLocation == route.urlLocation) return index;
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
  /// The redirects run first, like for [go], so a guard cannot be skipped by
  /// pushing. When one sends the user elsewhere, that route is pushed instead
  /// and the future completes with its result, or null when it is not a [T].
  /// Unlike [go] this never switches branch: the page is added exactly where
  /// the user is, even when it is the root of another branch. A push that has
  /// to wait for a redirect still lands on the branch that was on screen when
  /// it was made, and pushes are applied in the order they were made.
  ///
  /// [context] is handed to the redirects, like in [go]; without it they get
  /// the router's navigator. While neither exists (before the first frame) the
  /// push waits for the next frame. It completes with null when a redirect
  /// abandons it, when [go] ran meanwhile, or when the router is disposed.
  ///
  /// Redirects that are all synchronous add the page before this returns.
  /// Pushing a page straight onto [controller] skips the redirects, on
  /// purpose.
  @override
  Future<T?> push<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) {
    final branch = _controller.currentIndex;
    return _pushResolved<T>(route, context, null, (target) {
      final Future<T?> future;
      if (identical(target, route)) {
        future = _announce(
          () => _controller.push<T>(route.toPage<T>(), branch: branch),
        );
      } else {
        // A redirect changed the page, and with it the type of its result.
        future = _announce(
          () => _controller.push<Object?>(
            target.toPage<Object?>(),
            branch: branch,
          ),
        ).then((value) => value is T ? value : null);
      }
      _emit(FoldableNavigationKind.push, target);
      return future;
    });
  }

  /// Adds the route for [location] on top of the current branch, after the
  /// redirects. See [push].
  Future<void> pushLocation(String location, {BuildContext? context}) {
    final uri = Uri.parse(location);
    final branch = _controller.currentIndex;
    return _pushResolved<void>(_routeOfUri(uri), context, uri, (target) {
      final future = _announce(
        () =>
            _controller.push<Object?>(target.toPage<Object?>(), branch: branch),
      );
      _emit(FoldableNavigationKind.push, target);
      return future.then((_) {});
    });
  }

  /// Follows the redirects of [route] and then calls [add] with the route that
  /// stays, unless a [go] started in the meantime. The push counterpart of
  /// [_resolveAndApply].
  ///
  /// When every redirect is synchronous and no earlier push is waiting, [add]
  /// runs before this returns. Otherwise the push joins the queue: pushes are
  /// applied in the order they were made, so a slow redirect never lets a later
  /// push overtake an earlier one.
  Future<T?> _pushResolved<T extends Object?>(
    FoldableRoute route,
    BuildContext? callerContext,
    Uri? uri,
    Future<T?> Function(FoldableRoute target) add,
  ) {
    if (_disposed) return Future.value();
    // A later push does not cancel this one, a later go does.
    final navigation = _navigations;
    FutureOr<FoldableRoute?>? resolving;
    final context = callerContext ?? rootContextOf?.call();
    if (_pushesWaiting == 0 && context != null) {
      try {
        resolving = resolve(route, context: context, uri: uri);
      } catch (error, stack) {
        _reportRedirectError(error, stack);
        return Future.value();
      }
      if (resolving is! Future<FoldableRoute?>) {
        return resolving == null ? Future.value() : add(resolving);
      }
    }

    final previous = _lastPushTurn;
    final turn = Completer<void>();
    _lastPushTurn = turn.future;
    _pushesWaiting++;
    final result = Completer<T?>();
    unawaited(() async {
      FoldableRoute? target;
      try {
        await previous;
        target =
            await (resolving ??
                _resolveWhenReady(route, callerContext, uri, navigation));
      } catch (error, stack) {
        _reportRedirectError(error, stack);
      }
      try {
        if (target == null || _disposed || navigation != _navigations) {
          result.complete();
        } else {
          result.complete(add(target));
        }
      } catch (error, stack) {
        result.completeError(error, stack);
      } finally {
        _pushesWaiting--;
        turn.complete();
      }
    }());
    return result.future;
  }

  /// [resolve] with the context of the caller, else the router's navigator;
  /// waits for frames until one exists, and gives up with null when the router
  /// is disposed or a [go] (newer than [navigation]) started meanwhile.
  Future<FoldableRoute?> _resolveWhenReady(
    FoldableRoute route,
    BuildContext? callerContext,
    Uri? uri,
    int navigation,
  ) async {
    var context = callerContext ?? rootContextOf?.call();
    while (context == null) {
      // No BuildContext yet, as when a push is made before the first build.
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || navigation != _navigations) return null;
      context = callerContext ?? rootContextOf?.call();
    }
    return resolve(route, context: context, uri: uri);
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
  /// [Navigator.pushAndRemoveUntil]. The redirects run first, see [push].
  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    FoldableRoute route,
    bool Function(Page<Object?> page) predicate, {
    BuildContext? context,
  }) {
    final branch = _controller.currentIndex;
    return _pushResolved<T>(route, context, null, (target) {
      final Future<T?> future;
      if (identical(target, route)) {
        future = _announce(
          () => _controller.pushAndRemoveUntil<T>(
            route.toPage<T>(),
            predicate,
            branch: branch,
          ),
        );
      } else {
        future = _announce(
          () => _controller.pushAndRemoveUntil<Object?>(
            target.toPage<Object?>(),
            predicate,
            branch: branch,
          ),
        ).then((value) => value is T ? value : null);
      }
      _emit(FoldableNavigationKind.push, target);
      return future;
    });
  }

  /// Replaces the top page of the current branch with [route], like
  /// [Navigator.pushReplacement]. The redirects run first, see [push].
  ///
  /// The replaced page completes with null. A branch root created from
  /// [FoldableRouterConfig.roots] is never replaced: when the top page is the
  /// root, [route] is pushed on top of it instead.
  @override
  Future<T?> pushAndReplace<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) {
    final branch = _controller.currentIndex;
    return _pushResolved<T>(route, context, null, (target) {
      final replace = roots.isEmpty || _controller.pagesOf(branch).length > 1;
      Future<R?> add<R extends Object?>(Page<R> page) => replace
          ? _controller.pushAndReplace<R>(page, branch: branch)
          : _controller.push<R>(page, branch: branch);
      final Future<T?> future;
      if (identical(target, route)) {
        future = _announce(() => add<T>(route.toPage<T>()));
      } else {
        future = _announce(
          () => add<Object?>(target.toPage<Object?>()),
        ).then((value) => value is T ? value : null);
      }
      _emit(FoldableNavigationKind.push, target);
      return future;
    });
  }

  /// Replaces the top page of the current branch with the route for
  /// [location], after the redirects. See [pushAndReplace].
  Future<void> pushReplacementLocation(
    String location, {
    BuildContext? context,
  }) {
    final uri = Uri.parse(location);
    final branch = _controller.currentIndex;
    return _pushResolved<void>(_routeOfUri(uri), context, uri, (target) {
      final replace = roots.isEmpty || _controller.pagesOf(branch).length > 1;
      final page = target.toPage<Object?>();
      final future = _announce(
        () => replace
            ? _controller.pushAndReplace<Object?>(page, branch: branch)
            : _controller.push<Object?>(page, branch: branch),
      );
      _emit(FoldableNavigationKind.push, target);
      return future.then((_) {});
    });
  }

  /// Removes the top page. When there is none to remove, shows [fallback] or
  /// the [backTarget].
  void back([FoldableRoute? fallback]) {
    if (_announce(() => _controller.pop())) {
      _emit(FoldableNavigationKind.pop, null);
      return;
    }
    final target = fallback ?? backTarget;
    if (target != null) _go(target, null);
  }

  /// A snapshot of the page stacks, for state restoration.
  ///
  /// Holds the current branch and, for every branch, the URLs of its pages
  /// from bottom to top, without the branch root (the router creates the roots
  /// itself; a router without roots saves every page). A page whose route is
  /// not [FoldableRoute.deepLinkable] has no URL and is left out.
  ///
  /// Only maps, lists, strings and integers, so it survives the platform's
  /// restoration data.
  @override
  Map<String, Object?> saveState() {
    final skip = roots.isEmpty ? 0 : 1;
    return {
      _indexKey: currentIndex,
      _branchesKey: [
        for (var branch = 0; branch < branchCount; branch++)
          <String>[
            for (final page in _controller.pagesOf(branch).skip(skip))
              if (page.name case final name?) name,
          ],
      ],
    };
  }

  /// Puts back the page stacks of a [saveState] snapshot.
  ///
  /// Every saved URL goes through [FoldableRouterConfig.matcher]; one it does
  /// not know is dropped, the other pages stay. The branch roots stay what the
  /// router created. Nothing runs through the redirects and the observers hear
  /// nothing: it re-creates what the user saw, it does not navigate.
  ///
  /// A snapshot that does not fit this router (another number of branches, a
  /// branch index out of range, anything not made by [saveState]) is ignored
  /// as a whole.
  @override
  void restoreState(Map<String, Object?> state) {
    if (_disposed) return;
    final index = state[_indexKey];
    final saved = state[_branchesKey];
    if (index is! int || saved is! List<Object?>) return;
    if (saved.length != branchCount || index < 0 || index >= branchCount) {
      return;
    }
    final stacks = <List<String>>[];
    for (final urls in saved) {
      if (urls is! List<Object?> || urls.any((url) => url is! String)) return;
      stacks.add(urls.cast<String>());
    }

    _announce(() {
      _controller.batch(() {
        for (var branch = 0; branch < stacks.length; branch++) {
          final pages = _restoredPages(branch, stacks[branch]);
          if (pages.isNotEmpty) _controller.setPages(pages, branch: branch);
        }
        _controller.goBranch(index);
      });
    });
  }

  List<Page<Object?>> _restoredPages(int branch, List<String> urls) {
    final current = _controller.pagesOf(branch);
    final root = roots.isEmpty || current.isEmpty
        ? const <Page<Object?>>[]
        : [current.first];
    return [
      ...root,
      for (final url in urls)
        if (_pageOfUrl(url) case final page?) page,
    ];
  }

  /// The page for a saved URL, or null when no route matches it.
  Page<Object?>? _pageOfUrl(String url) {
    try {
      return config.match(Uri.parse(url))?.toPage<void>();
    } on FormatException {
      return null;
    }
  }

  static const _indexKey = 'index';
  static const _branchesKey = 'branches';

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
    // A stack that started empty has no URL yet: let its first navigation
    // fill it, even when the URL is `/`.
    if (_controller.pages.isNotEmpty &&
        uri.toString() == currentUri.toString()) {
      return;
    }

    final pages = _controller.pages;
    final below = pages.length > 1 ? pages[pages.length - 2].name : null;
    if (below != null && below == uri.toString()) {
      if (_announce(() => _controller.pop())) {
        _emit(FoldableNavigationKind.pop, null);
      }
      return;
    }
    _go(_routeOfUri(uri), null, uri: uri);
  }

  /// Runs a change of the controller that the caller announces itself with
  /// [_emit], so the controller listener does not report it a second time.
  T _announce<T>(T Function() mutate) {
    // Changes made directly on the controller earlier in the same batch are
    // reported before this one, so that neither gets lost.
    if (_announcing == 0) _reportControllerChange();
    _announcing++;
    try {
      return mutate();
    } finally {
      _announcing--;
      if (_announcing == 0) _remember();
    }
  }

  void _remember() {
    _knownIndex = _controller.currentIndex;
    _knownPages = List.of(_controller.pages);
  }

  void _onControllerChanged() {
    notifyListeners();
    if (_announcing == 0) _reportControllerChange();
  }

  /// Reports what changed on the controller without the router announcing
  /// it: a pop from a back button, system back or swipe, `goBranch` from a
  /// navigation rail, or any other direct use of the controller.
  ///
  /// One event for the whole change, so the controller's `batch` stays one
  /// event. Changes to a branch that is not on screen are not navigations.
  void _reportControllerChange() {
    final index = _controller.currentIndex;
    final pages = _controller.pages;
    final previousIndex = _knownIndex;
    final previousPages = _knownPages;
    if (index == previousIndex && _samePages(pages, previousPages)) return;
    _remember();
    final kind = index != previousIndex
        ? FoldableNavigationKind.branch
        : pages.length < previousPages.length
        ? FoldableNavigationKind.pop
        : pages.length > previousPages.length
        ? FoldableNavigationKind.push
        : FoldableNavigationKind.go;
    _emit(kind, null);
  }

  static bool _samePages(List<Page<Object?>> a, List<Page<Object?>> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!identical(a[index], b[index])) return false;
    }
    return true;
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
    _disposed = true;
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }
}
