import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'foldable_route.dart';
import 'foldable_router.dart';
import 'foldable_shell_route.dart';
import 'redirect_resolver.dart';

/// One page in the stack. Entries have their own identity so the same route
/// can be on the stack more than once.
class _Entry {
  _Entry(this.id, this.route);

  final int id;
  final FoldableRoute route;
  final Completer<Object?> _result = Completer<Object?>();

  /// Completes when the Navigator route created for this entry is popped.
  Future<Object?>? popped;

  late final ValueKey<int> key = ValueKey<int>(id);

  Future<Object?> get result => _result.future;

  void complete([FutureOr<Object?> value]) {
    if (!_result.isCompleted) _result.complete(value);
  }
}

class _EntryPage extends MaterialPage<Object?> {
  _EntryPage(
    this.entry, {
    this.canPopGesture = true,
    ValueListenable<bool>? gestureGate,
  }) : super(
         key: entry.key,
         name: entry.route.uri.toString(),
         child: gestureGate == null
             ? PopScope(
                 canPop: canPopGesture,
                 child: Builder(builder: entry.route.build),
               )
             : _GestureGate(gate: gestureGate, builder: entry.route.build),
       );

  final _Entry entry;

  /// Whether a user-initiated pop (the Android predictive back gesture, the
  /// iOS back swipe) may pop this page.
  ///
  /// The framework decides that from the page's own navigator (`isCurrent`)
  /// only, so a page left on top of a *hidden* tab, or of a branch covered
  /// by a full-screen page, would otherwise take the gesture. Routing it
  /// through a [PopScope] makes `popDisposition` `doNotPop` and hides the
  /// page from the gesture without touching its state.
  final bool canPopGesture;

  @override
  Route<Object?> createRoute(BuildContext context) {
    final route = super.createRoute(context);
    entry.popped = route.popped;
    return route;
  }
}

/// A [PopScope] whose `canPop` follows [gate], so the delegate can enable or
/// disable the back gesture of a branch page without rebuilding the router.
class _GestureGate extends StatefulWidget {
  const _GestureGate({required this.gate, required this.builder});

  final ValueListenable<bool> gate;
  final WidgetBuilder builder;

  @override
  State<_GestureGate> createState() => _GestureGateState();
}

class _GestureGateState extends State<_GestureGate> {
  @override
  void initState() {
    super.initState();
    widget.gate.addListener(_onGateChanged);
  }

  @override
  void didUpdateWidget(_GestureGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) {
      oldWidget.gate.removeListener(_onGateChanged);
      widget.gate.addListener(_onGateChanged);
    }
  }

  @override
  void dispose() {
    widget.gate.removeListener(_onGateChanged);
    super.dispose();
  }

  void _onGateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.gate.value,
    child: Builder(builder: widget.builder),
  );
}

/// Tracks the top-most route of one navigator.
///
/// The delegate must distinguish the routes it owns (the pages of its own
/// `pages` lists) from the *pageless* routes pushed imperatively on a
/// navigator: dialogs, bottom sheets, popup menus, ... Those do not appear
/// in `pages` nor in the branch stacks, so counting pages cannot see them.
/// A page-based route keeps its [Page] as its `settings`, so a route whose
/// settings are not a [Page] is pageless.
class _TopRouteTracker extends NavigatorObserver {
  Route<Object?>? _top;

  /// Called whenever the top-most route changes.
  VoidCallback? onChanged;

  /// Whether the top-most route is not one of the pages the router owns.
  bool get topIsPageless => _top != null && _top!.settings is! Page<Object?>;

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    super.didChangeTop(topRoute, previousTopRoute);
    _top = topRoute;
    onChanged?.call();
  }
}

/// The mutable state of the shell currently on screen.
class _Shell {
  _Shell(this.entry, this.branches, {required this.onTopRouteChanged})
    : branchNavigators = List.generate(
        branches.length,
        (_) => GlobalKey<NavigatorState>(),
      ),
      heroControllers = List.generate(branches.length, (_) => HeroController()),
      topRoutes = List.generate(branches.length, (_) => _TopRouteTracker()),
      gestureGates = List.generate(
        branches.length,
        (_) => ValueNotifier<bool>(false),
      ) {
    for (final tracker in topRoutes) {
      tracker.onChanged = onTopRouteChanged;
    }
  }

  /// The page of the shell in the root navigator.
  final _Entry entry;

  /// Snapshot of `entry.route.branches` at commit time.
  final List<FoldableRoute> branches;

  /// Keys of the nested navigator of each branch, index-aligned with
  /// [branches]. They survive as long as this shell is on screen.
  final List<GlobalKey<NavigatorState>> branchNavigators;

  /// Ancestors of the shell (its parent chain), bottom first: the pages of
  /// the root navigator that sit below the shell page.
  List<_Entry> ancestors = const [];

  /// Stack of each branch; `null` until the branch is built (lazily).
  late final List<List<_Entry>?> branchStacks = List<List<_Entry>?>.filled(
    branches.length,
    null,
  );

  /// Full-screen pages pushed above the shell.
  List<_Entry> overlays = const [];

  /// One [HeroController] per branch: heroes fly within a branch, through
  /// the nested navigator, without colliding with the other branches or
  /// with the root navigator.
  final List<HeroController> heroControllers;

  /// Observes the top-most route of the navigator of each branch, to see the
  /// pageless routes (sheets, menus) opened on it.
  final List<_TopRouteTracker> topRoutes;

  /// Per branch, whether its top page may take a back gesture: only the page
  /// on top of the visible branch, when nothing covers it.
  final List<ValueNotifier<bool>> gestureGates;

  /// Called when the delegate asked to be told about top route changes.
  final VoidCallback onTopRouteChanged;

  /// Index of the branch currently shown.
  int current = 0;

  FoldableShellRoute get route => entry.route as FoldableShellRoute;

  Iterable<_Entry> get allEntries sync* {
    yield* ancestors;
    for (final stack in branchStacks) {
      if (stack != null) yield* stack;
    }
    yield* overlays;
  }

  /// Releases the hero controllers of the branches and the per-branch state.
  /// Called once the shell is gone (its navigators are, or are about to be,
  /// unmounted).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final controller in heroControllers) {
      controller.dispose();
    }
    for (final tracker in topRoutes) {
      tracker.onChanged = null;
    }
    for (final gate in gestureGates) {
      gate.dispose();
    }
  }

  bool _disposed = false;
}

/// Exposes the [FoldableRouter] to the widgets below the router.
class FoldableRouterScope extends InheritedWidget {
  /// Creates the scope.
  const FoldableRouterScope({
    super.key,
    required this.router,
    required super.child,
  });

  /// The router that built this subtree.
  final FoldableRouter router;

  @override
  bool updateShouldNotify(FoldableRouterScope oldWidget) =>
      router != oldWidget.router;
}

/// A [ChangeNotifier] the delegate can trigger from outside.
class StackNotifier extends ChangeNotifier {
  /// Calls the listeners.
  void notify() => notifyListeners();
}

/// Reports to the system whether the router, with all its navigators,
/// handles back (for the Android predictive back gesture).
///
/// It dispatches one [NavigationNotification] synthesized from the router's
/// own state, so the value sent to the engine does not depend on which
/// nested navigator dispatched last. In shell mode the notifications of the
/// navigators themselves are swallowed below (see [FoldableRouterDelegate],
/// `build`); without a shell they agree with this value anyway.
class _BackNotification extends StatefulWidget {
  const _BackNotification({required this.canHandlePop, required this.child});

  final ValueListenable<bool> canHandlePop;
  final Widget child;

  @override
  State<_BackNotification> createState() => _BackNotificationState();
}

class _BackNotificationState extends State<_BackNotification> {
  @override
  void initState() {
    super.initState();
    widget.canHandlePop.addListener(_scheduleReport);
    _scheduleReport();
  }

  @override
  void didUpdateWidget(_BackNotification oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canHandlePop != widget.canHandlePop) {
      oldWidget.canHandlePop.removeListener(_scheduleReport);
      widget.canHandlePop.addListener(_scheduleReport);
      _scheduleReport();
    }
  }

  @override
  void dispose() {
    widget.canHandlePop.removeListener(_scheduleReport);
    super.dispose();
  }

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Bubbles up to WidgetsApp, which forwards the value to the platform.
      NavigationNotification(
        canHandlePop: widget.canHandlePop.value,
      ).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Owns the page stack and runs navigations for a [FoldableRouter].
///
/// Without a shell the whole stack lives in the root navigator. With a shell
/// on screen the root navigator holds the ancestors of the shell, the shell
/// itself and the full-screen pages pushed above it, while each branch has
/// its own nested navigator.
class FoldableRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  /// Creates the delegate for [router].
  FoldableRouterDelegate(this.router)
    : _resolver = RedirectResolver(maxRedirects: router.maxRedirects) {
    _rootTop.onChanged = _scheduleBackStateRefresh;
  }

  /// The router this delegate works for.
  final FoldableRouter router;

  /// Key of the root Navigator.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether a navigation is resolving its redirects.
  final ValueNotifier<bool> isNavigating = ValueNotifier<bool>(false);

  /// Notifies when [stack] or [currentConfiguration] changed. Unlike the
  /// delegate's own listeners (the Router widget), these are not called for
  /// rebuild requests that leave both unchanged.
  final StackNotifier stackChanges = StackNotifier();

  static const ValueKey<String> _shellPageKey = ValueKey<String>(
    'foldable-shell',
  );

  final RedirectResolver _resolver;

  /// Tracks the top-most route of the root navigator, to see the pageless
  /// routes opened on it (dialogs, ...).
  final _TopRouteTracker _rootTop = _TopRouteTracker();

  /// The value [build] reports to the platform, kept up to date when a
  /// pageless route opens or closes even though the router's stack does not
  /// change.
  final ValueNotifier<bool> _canHandlePopSignal = ValueNotifier<bool>(false);

  /// The stack of the root navigator when no shell is on screen.
  List<_Entry> _stack = const [];

  /// The shell state when a shell is on screen.
  _Shell? _shell;
  Uri? _notFound;
  int _nextId = 0;
  bool _disposed = false;

  /// The routes currently on the stack, bottom first.
  List<FoldableRoute> get stack {
    final shell = _shell;
    if (shell == null) return List.unmodifiable(_stack.map((e) => e.route));
    return List.unmodifiable([
      ...shell.ancestors.map((e) => e.route),
      shell.entry.route,
      ...?shell.branchStacks[shell.current]?.map((e) => e.route),
      ...shell.overlays.map((e) => e.route),
    ]);
  }

  @override
  Uri? get currentConfiguration {
    if (_notFound != null) return _notFound;
    final routes = stack;
    return routes.isEmpty ? null : routes.last.uri;
  }

  /// Whether [popRoute] would pop something: a pageless route on top of the
  /// root navigator or of the visible branch, a full-screen page above the
  /// shell, or a page to go back to inside the visible branch.
  bool get _canHandlePop {
    final shell = _shell;
    if (shell != null) {
      return _rootTop.topIsPageless ||
          shell.overlays.isNotEmpty ||
          shell.topRoutes[shell.current].topIsPageless ||
          (shell.branchStacks[shell.current]?.length ?? 0) > 1;
    }
    return _notFound == null && _stack.length > 1;
  }

  /// Recomputes the signal reported to the platform and the branches that
  /// may take a back gesture. Called when the stacks change and when a
  /// pageless route opens or closes on any navigator.
  void _refreshBackState() {
    if (_disposed) return;
    _canHandlePopSignal.value = _canHandlePop;
    final shell = _shell;
    if (shell == null) return;
    final canPopGesture = shell.overlays.isEmpty && !_rootTop.topIsPageless;
    for (var i = 0; i < shell.gestureGates.length; i++) {
      shell.gestureGates[i].value = canPopGesture && i == shell.current;
    }
  }

  /// Calls [_refreshBackState] after the current microtask: the top route
  /// trackers fire while a Navigator flushes its history, which may happen
  /// during a build.
  void _scheduleBackStateRefresh() => scheduleMicrotask(_refreshBackState);

  ({List<FoldableRoute> routes, Uri? location}) _snapshot() =>
      (routes: stack, location: currentConfiguration);

  /// Tells the Router widget to rebuild and, when the stack or the location
  /// changed since [before], the listeners of the [FoldableRouter].
  void _notifyAfter(({List<FoldableRoute> routes, Uri? location}) before) {
    final changed =
        before.location != currentConfiguration ||
        !listEquals(before.routes, stack);
    _refreshBackState();
    notifyListeners();
    if (changed) stackChanges.notify();
  }

  /// Replaces the stack with the parent chain of [route].
  Future<void> open(FoldableRoute route) async {
    await _navigate(route, push: false);
  }

  /// Appends [route] and completes with the value it is popped with.
  Future<T?> push<T extends Object?>(FoldableRoute route) async {
    final entry = await _navigate(route, push: true);
    if (entry == null) return null;
    return await entry.result as T?;
  }

  /// Removes the top page of the current navigator unless it is its last.
  void pop<T extends Object?>([T? result]) {
    final before = _snapshot();
    final shell = _shell;
    if (shell != null) {
      if (shell.overlays.isNotEmpty) {
        final entry = shell.overlays.last;
        shell.overlays = shell.overlays.sublist(0, shell.overlays.length - 1);
        entry.complete(result);
        _notifyAfter(before);
        return;
      }
      final branch = shell.branchStacks[shell.current];
      if (branch == null || branch.length <= 1) return;
      final entry = branch.last;
      shell.branchStacks[shell.current] = branch.sublist(0, branch.length - 1);
      entry.complete();
      _notifyAfter(before);
      return;
    }
    if (_stack.length <= 1) return;
    final entry = _stack.last;
    _stack = _stack.sublist(0, _stack.length - 1);
    entry.complete(result);
    _notifyAfter(before);
  }

  /// Re-runs the redirects of the routes on the stack, bottom to top.
  Future<void> refresh() async {
    final routes = stack;
    if (routes.isEmpty) return;
    final token = _begin();
    try {
      final redirected = await _resolver.firstRedirect(
        routes,
        target: routes.last,
        token: token,
      );
      if (redirected == null) return;
      final chain = await _resolve(redirected, token);
      if (chain != null) _commitOpen(chain);
    } finally {
      _end(token);
    }
  }

  int _begin() {
    final token = _resolver.begin();
    isNavigating.value = true;
    return token;
  }

  void _end(int token) {
    if (!_disposed && _resolver.isCurrent(token)) isNavigating.value = false;
  }

  FoldableRoute _firstBranch(FoldableShellRoute shell) {
    final branches = shell.branches;
    if (branches.isEmpty) {
      throw StateError('$shell has no branches: it cannot be opened.');
    }
    return branches.first;
  }

  /// Resolves [target] to its final chain, following redirects and turning a
  /// redirect to a shell into the opening of its first branch.
  Future<List<FoldableRoute>?> _resolve(FoldableRoute target, int token) async {
    var current = target;
    for (var restarts = 0; ; restarts++) {
      final chain = await _resolver.resolve(current, token: token);
      if (chain == null) return null;
      final last = chain.last;
      if (last is! FoldableShellRoute) return chain;
      if (restarts >= _resolver.maxRedirects) {
        throw RedirectLimitException(
          List.unmodifiable([target, last]),
          _resolver.maxRedirects,
        );
      }
      current = _firstBranch(last);
    }
  }

  /// Validates a resolved chain: one shell at most, and the route below a
  /// shell belongs to one of its branches.
  void _checkChain(List<FoldableRoute> chain) {
    final shells = chain.whereType<FoldableShellRoute>().toList();
    if (shells.length > 1) {
      throw StateError(
        'More than one FoldableShellRoute in one parent chain is not '
        'supported: ${chain.join(' <- ')}.',
      );
    }
  }

  /// Returns the committed top entry, or null when superseded.
  Future<_Entry?> _navigate(FoldableRoute target, {required bool push}) async {
    if (_disposed) return null;
    if (target is FoldableShellRoute) {
      if (push) {
        throw UnsupportedError(
          'push($target) targets a FoldableShellRoute: use open instead.',
        );
      }
      target = _firstBranch(target);
    }
    final token = _begin();
    try {
      final chain = await _resolve(target, token);
      if (chain == null) return null;
      _checkChain(chain);
      if (push && chain.any((r) => r is FoldableShellRoute)) {
        throw UnsupportedError(
          'push($target) targets a route inside a FoldableShellRoute '
          '(${chain.firstWhere((r) => r is FoldableShellRoute)}): '
          'use open instead.',
        );
      }
      return push ? _commitPush(chain.last) : _commitOpen(chain);
    } finally {
      _end(token);
    }
  }

  _Entry _commitOpen(List<FoldableRoute> chain) {
    final before = _snapshot();
    final shellIndex = chain.indexWhere((r) => r is FoldableShellRoute);
    final entry = shellIndex < 0
        ? _commitFlatOpen(chain)
        : _commitShellOpen(chain, shellIndex);
    _notifyAfter(before);
    return entry;
  }

  _Entry _commitFlatOpen(List<FoldableRoute> chain) {
    final shell = _shell;
    if (shell != null) {
      for (final entry in shell.allEntries) {
        entry.complete();
      }
      _retireShell(shell);
      _shell = null;
    }
    // Keep the entries (and so the page state) of the unchanged bottom part.
    var keep = 0;
    while (keep < chain.length &&
        keep < _stack.length &&
        _stack[keep].route == chain[keep]) {
      keep++;
    }
    final removed = _stack.sublist(keep);
    _stack = [
      ..._stack.take(keep),
      for (final route in chain.skip(keep)) _Entry(_nextId++, route),
    ];
    _notFound = null;
    for (final entry in removed) {
      entry.complete();
    }
    return _stack.last;
  }

  _Entry _commitShellOpen(List<FoldableRoute> chain, int shellIndex) {
    final shellRoute = chain[shellIndex] as FoldableShellRoute;
    final branchRoutes = chain.sublist(shellIndex + 1);
    final branches = shellRoute.branches;
    var branchIndex = 0;
    if (branchRoutes.isNotEmpty) {
      branchIndex = branches.indexWhere((r) => r == branchRoutes.first);
      if (branchIndex < 0) {
        throw StateError(
          'The route ${branchRoutes.first} is below $shellRoute in its parent '
          'chain but is not one of its branches '
          '(${branches.join(', ')}).',
        );
      }
    }
    // The flat stack (if any) is gone.
    final droppedStack = _stack;
    _stack = const [];
    _notFound = null;
    for (final entry in droppedStack) {
      entry.complete();
    }

    var shell = _shell;
    if (shell == null || shell.entry.route != shellRoute) {
      if (shell != null) {
        for (final entry in shell.allEntries) {
          entry.complete();
        }
        _retireShell(shell);
      }
      shell = _shell = _Shell(
        _Entry(_nextId++, shellRoute),
        branches,
        onTopRouteChanged: _scheduleBackStateRefresh,
      );
    }
    // Ancestors above the shell: keep the unchanged bottom.
    final ancestors = chain.sublist(0, shellIndex);
    var keepAncestors = 0;
    while (keepAncestors < ancestors.length &&
        keepAncestors < shell.ancestors.length &&
        shell.ancestors[keepAncestors].route == ancestors[keepAncestors]) {
      keepAncestors++;
    }
    final removedAncestors = shell.ancestors.sublist(keepAncestors);
    shell.ancestors = [
      ...shell.ancestors.take(keepAncestors),
      for (final route in ancestors.skip(keepAncestors))
        _Entry(_nextId++, route),
    ];
    for (final entry in removedAncestors) {
      entry.complete();
    }
    // Full-screen pages above the shell are replaced by the new stack.
    final droppedOverlays = shell.overlays;
    shell.overlays = const [];
    for (final entry in droppedOverlays) {
      entry.complete();
    }
    // Replace the stack of the target branch, keeping its bottom.
    final oldBranch = shell.branchStacks[branchIndex];
    var keep = 0;
    if (oldBranch != null) {
      while (keep < branchRoutes.length &&
          keep < oldBranch.length &&
          oldBranch[keep].route == branchRoutes[keep]) {
        keep++;
      }
    }
    final removedBranch = oldBranch == null
        ? const <_Entry>[]
        : oldBranch.sublist(keep);
    shell.branchStacks[branchIndex] = [
      if (oldBranch != null) ...oldBranch.take(keep),
      for (final route in branchRoutes.skip(keep)) _Entry(_nextId++, route),
    ];
    for (final entry in removedBranch) {
      entry.complete();
    }
    shell.current = branchIndex;
    return shell.branchStacks[branchIndex]!.last;
  }

  _Entry _commitPush(FoldableRoute route) {
    final before = _snapshot();
    final entry = _Entry(_nextId++, route);
    final shell = _shell;
    if (shell != null) {
      shell.overlays = [...shell.overlays, entry];
    } else {
      _stack = [..._stack, entry];
    }
    _notFound = null;
    _notifyAfter(before);
    return entry;
  }

  void _showNotFound(Uri uri) {
    final before = _snapshot();
    final removed = _stack;
    final shell = _shell;
    _stack = const [];
    _shell = null;
    _notFound = uri;
    for (final entry in removed) {
      entry.complete();
    }
    if (shell != null) {
      for (final entry in shell.allEntries) {
        entry.complete();
      }
      _retireShell(shell);
    }
    _notifyAfter(before);
  }

  /// Releases the resources of a shell that is being removed, once the frame
  /// that unmounts its navigators has run.
  void _retireShell(_Shell shell) {
    WidgetsBinding.instance.addPostFrameCallback((_) => shell.dispose());
  }

  /// Switches to the branch at [index], keeping its stack.
  ///
  /// The first visit builds the branch: it runs the redirects of the whole
  /// chain (shell included) and opens the branch root. Later visits keep the
  /// stack but re-check the redirects, as [refresh] does for the current
  /// stack; a redirect that fires opens its target, which may leave the
  /// shell.
  Future<void> goBranch(int index) async {
    final shell = _shell;
    if (_disposed || shell == null) return;
    RangeError.checkValueInInterval(index, 0, shell.branches.length - 1);
    final built = shell.branchStacks[index];
    if (index == shell.current && built != null) return;
    final token = _begin();
    try {
      final target = built == null ? shell.branches[index] : built.last.route;
      final chain = await _resolve(target, token);
      if (chain == null) return;
      _checkChain(chain);
      _commitOpen(chain);
      // A redirect may have moved the navigation elsewhere; otherwise the
      // shell (if it is still the same) is now showing [index].
      final now = _shell;
      if (now != null && identical(now, shell) && now.current != index) {
        now.current = index;
        _refreshBackState();
      }
    } finally {
      _end(token);
    }
  }

  /// Opens the route [uri] stands for, or shows the not-found page when
  /// there is none. Errors of the navigation are thrown.
  Future<void> openUri(Uri uri) async {
    if (_disposed) return;
    final route = router.routeFor(uri);
    if (route == null) {
      _end(_begin()); // Supersede whatever is pending.
      _showNotFound(uri);
      return;
    }
    try {
      await _navigate(route, push: false);
    } catch (_) {
      // Nothing is on screen yet (first navigation): show something.
      if (stack.isEmpty && _notFound == null && !_disposed) {
        _showNotFound(uri);
      }
      rethrow;
    }
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    try {
      await openUri(configuration);
    } catch (error, stackTrace) {
      // Nobody awaits a platform-initiated navigation, so report it here.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'foldable_router',
          context: ErrorDescription('while opening $configuration'),
        ),
      );
    }
  }

  @override
  Future<bool> popRoute() {
    if (_disposed) return SynchronousFuture<bool>(false);
    final navigator = navigatorKey.currentState;
    if (navigator == null) return SynchronousFuture<bool>(false);
    final shell = _shell;
    if (shell == null) return navigator.maybePop();
    // 1. A pageless route on top of the root navigator (dialog, ...).
    if (_rootTop.topIsPageless) return navigator.maybePop();
    // 2. A full-screen page pushed above the shell.
    if (shell.overlays.isNotEmpty) return navigator.maybePop();
    // 3./4. Inside the visible branch: a pageless route on top (bottom
    // sheet, menu, ...) goes first, then one page back. The branch navigator
    // tells whether there is anything to pop; the hidden branches are never
    // asked.
    final branch = shell.branchStacks[shell.current];
    if (shell.topRoutes[shell.current].topIsPageless ||
        (branch?.length ?? 0) > 1) {
      final branchNavigator =
          shell.branchNavigators[shell.current].currentState;
      if (branchNavigator == null) return SynchronousFuture<bool>(false);
      return branchNavigator.maybePop();
    }
    return SynchronousFuture<bool>(false);
  }

  void _onDidRemoveRootPage(Page<Object?> page) {
    final before = _snapshot();
    final shell = _shell;
    if (shell != null) {
      if (page.key == _shellPageKey) {
        // The shell cannot be popped: rebuild to put it back.
        notifyListeners();
        return;
      }
      final index = shell.overlays.indexWhere((e) => e.key == page.key);
      if (index >= 0) {
        final entry = shell.overlays[index];
        shell.overlays = [...shell.overlays]..removeAt(index);
        entry.complete(entry.popped);
        _notifyAfter(before);
        return;
      }
      // Pages below the shell stay; rebuild so the Navigator has them again.
      notifyListeners();
      return;
    }
    final index = _stack.indexWhere((e) => e.key == page.key);
    if (index < 0) return; // Already removed by us (pop / open).
    final removable = _stack.length > 1;
    if (removable) {
      final entry = _stack[index];
      _stack = [..._stack]..removeAt(index);
      entry.complete(entry.popped);
    }
    _notifyAfter(before);
  }

  void _onDidRemoveBranchPage(int branchIndex, Page<Object?> page) {
    final shell = _shell;
    if (shell == null) return;
    final branch = shell.branchStacks[branchIndex];
    if (branch == null) return;
    final index = branch.indexWhere((e) => e.key == page.key);
    if (index < 0) return; // Already removed by pop / open.
    final before = _snapshot();
    if (branch.length > 1) {
      final entry = branch[index];
      shell.branchStacks[branchIndex] = [...branch]..removeAt(index);
      entry.complete(entry.popped);
    }
    // The root of a branch stays; the Navigator still has to rebuild with it.
    _notifyAfter(before);
  }

  /// Builds the frame of [shell] around the nested navigator of the current
  /// branch (the other built branches stay alive, offstage).
  Widget _buildShellBody(BuildContext context, _Shell shell) {
    // Only the top page of the *visible* branch may take a back gesture: a
    // page on top of a hidden tab, of a branch covered by a full-screen
    // page, or of the whole shell covered by a dialog must not. The
    // framework only looks at the page's own navigator, hence the
    // [_GestureGate] in _EntryPage; its value follows the delegate's state.
    final children = <Widget>[];
    for (var i = 0; i < shell.branches.length; i++) {
      final entries = shell.branchStacks[i];
      if (entries == null) continue;
      children.add(
        Offstage(
          offstage: i != shell.current,
          child: TickerMode(
            enabled: i == shell.current,
            child: HeroControllerScope(
              controller: shell.heroControllers[i],
              child: Navigator(
                key: shell.branchNavigators[i],
                observers: [shell.topRoutes[i]],
                pages: [
                  for (final entry in entries)
                    _EntryPage(entry, gestureGate: shell.gestureGates[i]),
                ],
                onDidRemovePage: (page) => _onDidRemoveBranchPage(i, page),
              ),
            ),
          ),
        ),
      );
    }
    return shell.route.buildShell(
      context,
      FoldableShellState(
        child: Stack(fit: StackFit.expand, children: children),
        currentIndex: shell.current,
        goBranch: goBranch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notFound = _notFound;
    final shell = _shell;
    final Widget child;
    if (shell != null) {
      // The nested navigators each report whether *they* can pop, unaware of
      // the branches that are hidden or covered, and their notifications
      // race with each other. Swallow them all: _BackNotification reports a
      // single, synthesized value for the whole router instead.
      child = NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) => true,
        child: Navigator(
          key: navigatorKey,
          observers: [_rootTop],
          pages: [
            for (final entry in shell.ancestors)
              _EntryPage(entry, canPopGesture: false),
            MaterialPage<void>(
              key: _shellPageKey,
              name: shell.route.uri.toString(),
              // The shell page never pops with a gesture: back goes through
              // _BackNotification's synthesized state and popRoute.
              child: PopScope(
                canPop: false,
                child: Builder(
                  builder: (context) => _buildShellBody(context, shell),
                ),
              ),
            ),
            for (final entry in shell.overlays) _EntryPage(entry),
          ],
          onDidRemovePage: _onDidRemoveRootPage,
        ),
      );
    } else if (notFound == null && _stack.isEmpty) {
      child = router.pendingBuilder?.call(context) ?? const SizedBox.shrink();
    } else {
      child = Navigator(
        key: navigatorKey,
        observers: [_rootTop],
        pages: [
          if (notFound != null)
            MaterialPage<void>(
              key: ValueKey<String>('not-found:$notFound'),
              name: notFound.toString(),
              child: Builder(
                builder: (context) => router.notFoundBuilder(context, notFound),
              ),
            )
          else
            for (final entry in _stack) _EntryPage(entry),
        ],
        onDidRemovePage: _onDidRemoveRootPage,
      );
    }
    return FoldableRouterScope(
      router: router,
      child: _BackNotification(canHandlePop: _canHandlePopSignal, child: child),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _rootTop.onChanged = null;
    _canHandlePopSignal.dispose();
    _resolver.begin();
    for (final entry in _stack) {
      entry.complete();
    }
    final shell = _shell;
    if (shell != null) {
      for (final entry in shell.allEntries) {
        entry.complete();
      }
      shell.dispose();
    }
    isNavigating.dispose();
    stackChanges.dispose();
    super.dispose();
  }
}
