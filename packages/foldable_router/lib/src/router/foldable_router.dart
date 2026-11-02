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
  FoldableRouter({required this.config, this.allowEmptyRoots = false})
    : _observers = List.of(config.observers),
      _controller = _createController(config, allowEmptyRoots) {
    _remember();
    _controller.addListener(_onControllerChanged);
  }

  /// The app description of this router.
  final FoldableRouterConfig config;

  /// Whether [FoldableRouterConfig.roots] may be empty.
  ///
  /// A router without roots starts with an empty stack: the first navigation
  /// fills it. Use it with a [FoldableStackNavigator]; a
  /// [FoldableSplitNavigator] needs a page in every branch.
  ///
  /// [FoldableSessionRouter] sets it for `FoldableNavigatorKind.stack`
  /// sessions, so a stack session does not need a dummy root.
  final bool allowEmptyRoots;

  final FoldableNavigatorController _controller;
  final List<FoldableRouterObserver> _observers;

  /// The branch and the pages of that branch at the last navigation that was
  /// reported to the observers. A change of the controller that differs from
  /// it was not announced by the router itself.
  int _knownIndex = 0;
  List<Page<Object?>> _knownPages = const [];

  /// How many router operations are running that announce their own event.
  /// While it is not zero the controller changes are not reported twice.
  int _announcing = 0;

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
    bool allowEmptyRoots,
  ) {
    if (config.roots.isEmpty) {
      assert(
        allowEmptyRoots,
        'Needs at least one root route in FoldableRouterConfig.roots. Only a '
        'stack session may start with no roots.',
      );
      return FoldableNavigatorController.empty();
    }
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
  FoldableRoute routeOf(String location) {
    final uri = Uri.parse(location);
    return config.matcher(uri) ?? config.notFound(uri);
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
  FutureOr<FoldableRoute?> resolve(
    FoldableRoute route, {
    required BuildContext context,
    Uri? uri,
  }) {
    return _resolve(context, route, 0, uri ?? Uri.parse(route.location));
  }

  FutureOr<FoldableRoute?> _resolve(
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
        // The page that started the navigation may be gone by now: continue
        // with the router's navigator, or abandon the navigation. Returning
        // [current] here would skip the redirect that was just decided.
        final live = context.mounted ? context : rootContextOf?.call();
        if (live == null || !live.mounted) return null;
        return _resolve(live, value, step + 1, uri);
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
    final future = _announce(() => _controller.push<T>(route.toPage<T>()));
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
    final future = _announce(
      () => _controller.pushAndRemoveUntil<T>(route.toPage<T>(), predicate),
    );
    _emit(FoldableNavigationKind.push, route);
    return future;
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
    final skip = config.roots.isEmpty ? 0 : 1;
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
    final root = config.roots.isEmpty || current.isEmpty
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
      return config.matcher(Uri.parse(url))?.toPage<void>();
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
    _go(config.matcher(uri) ?? config.notFound(uri), null, uri: uri);
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
