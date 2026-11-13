import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'foldable_panes.dart';
import 'foldable_route.dart';
import 'foldable_router.dart';
import 'foldable_shell_route.dart';
import 'redirect_resolver.dart';

/// One page in the stack. Entries have their own identity so the same route
/// can be on the stack more than once.
class _Entry implements PaneEntryRef {
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

  /// The navigator route created for this entry, set by
  /// [_BranchPage.createRoute] and [_EntryPage.createRoute].
  Route<Object?>? navigatorRoute;

  /// The branch of the shell whose stack this page is in, or `-1` when the
  /// page is not in a branch.
  int branchIndex = -1;

  @override
  final ValueNotifier<int> position = ValueNotifier<int>(0);

  @override
  final ValueNotifier<FoldablePane> pane = ValueNotifier<FoldablePane>(
    FoldablePane.single,
  );

  @override
  bool paneFrozen = false;

  @override
  FoldablePane? frozenPane;

  @override
  bool frozenHidden = false;
}

class _EntryPage extends MaterialPage<Object?> {
  _EntryPage(
    this.entry, {
    this.canPopGesture = true,
    ValueListenable<bool>? gestureGate,
  }) : super(
         key: entry.key,
         name: entry.route.uri.toString(),
         child: PaneScope(
           entry: entry,
           notifier: entry.pane,
           child: gestureGate == null
               ? PopScope(
                   canPop: canPopGesture,
                   child: Builder(builder: entry.route.build),
                 )
               : PanePopGate(gate: gestureGate, builder: entry.route.build),
         ),
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
    entry
      ..navigatorRoute = route
      ..popped = route.popped;
    return route;
  }
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

  /// The route currently on top of the navigator, if any.
  Route<Object?>? get topRoute => _top;

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
        (_) => GlobalKey<_BranchNavigatorState>(),
      ),
      heroControllers = List.generate(branches.length, (_) => HeroController()),
      topRoutes = List.generate(branches.length, (_) => _TopRouteTracker()),
      panes = List.generate(branches.length, (i) => PaneMetrics(i)),
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
  final List<GlobalKey<_BranchNavigatorState>> branchNavigators;

  /// The page layout metrics of each branch, index-aligned with [branches].
  final List<PaneMetrics> panes;

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

  /// The entries that were on a branch stack at the last refresh. Entries
  /// that leave a stack keep the pane (and the visibility) they had, so that
  /// they animate out of the pane they were shown in.
  Set<_Entry> knownEntries = <_Entry>{};

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
    for (final metrics in panes) {
      metrics.dispose();
    }
  }

  bool _disposed = false;
}

/// A page of a branch of the shell, drawn by the pane layout.
///
/// Unlike [_EntryPage] (used on the root navigator, always a
/// [MaterialPage]), the route created for this page knows about the panes of
/// its tab: in a one-pane tab it behaves exactly like a [MaterialPage] (the
/// page below stays laid out and paints while the top page animates, the
/// secondary animation runs), in a two-pane tab it is transparent, has no
/// barrier, does not run its outgoing transition and draws its content in
/// the rectangle of its frame.
class _BranchPage extends Page<Object?> {
  _BranchPage({
    required this.entry,
    required this.metrics,
    required this.popGate,
    required this.contentBuilder,
  }) : super(key: entry.key, name: entry.route.uri.toString());

  final _Entry entry;
  final PaneMetrics metrics;
  final ValueListenable<bool>? popGate;
  final WidgetBuilder contentBuilder;

  @override
  Route<Object?> createRoute(BuildContext context) {
    final _BranchPageRoute<Object?> route = _BranchPageRoute<Object?>(this);
    entry
      ..navigatorRoute = route
      ..popped = route.popped;
    return route;
  }
}

/// The route of a [_BranchPage].
class _BranchPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _BranchPageRoute(this.page) : super(settings: page);

  final _BranchPage page;

  @override
  final bool maintainState = true;

  PaneMetrics get _metrics => page.metrics;

  /// In a one-pane tab this is `true`, like [MaterialPageRoute]: the page
  /// below is not painted once the top page settled, and it is painted (with
  /// its secondary animation running) during a transition or a predictive
  /// back gesture. In a two-pane tab it is `false`: the page below is the
  /// left pane and must stay visible.
  @override
  bool get opaque => !_metrics.twoPane.value;

  /// One pane: the material barrier, as in [MaterialPageRoute]. Two panes: no
  /// barrier at all, so the left pane is reachable (taps, semantics). The
  /// barrier entry stays: only its content changes.
  @override
  Widget buildModalBarrier() => _metrics.twoPane.value
      ? const SizedBox.shrink()
      : super.buildModalBarrier();

  /// The delegated transition (used by the predictive back gesture for the
  /// route below) is only needed in one-pane tabs: in a two-pane tab the left
  /// pane must not move.
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _metrics.twoPane.value ? null : super.delegatedTransition;

  @override
  Widget buildContent(BuildContext context) => PanePageView(
    metrics: page.metrics,
    entry: page.entry,
    popGate: page.popGate,
    contentBuilder: page.contentBuilder,
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The pane frame wraps the transition — not the other way round. The
    // transition widget (scrim, background, snapshot, scale, slide, fade) is
    // laid out in the rectangle of this page's pane and clipped to it, so
    // nothing it paints can reach the other pane. In a one-pane tab the frame
    // is the whole route area at the origin and does not clip, so the
    // transition is built exactly as before.
    //
    // Two-pane tabs never play the outgoing (parallax) transition of the page
    // below: the two panes are both always visible, so a page only changes
    // rectangle. The incoming page still keeps its enter transition. The
    // platform transition widget is always built (with its predictive-back and
    // delegated-transition plumbing); only the secondary animation is forced
    // to its dismissed value.
    //
    // The mode can flip while the route is mounted (the window grows one pane
    // into two). The framework caches this transition widget and does not
    // rebuild it on such a flip, so the below page could keep the one-pane
    // parallax offset and appear shifted the moment it becomes visible.
    // Listening to the mode here makes the widget rebuild itself the moment
    // the mode changes: the below page jumps to the identity transform in the
    // very frame it becomes visible, never drawn shifted.
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        page.entry.position,
        _metrics.twoPane,
      ]),
      child: child,
      builder: (BuildContext context, Widget? child) {
        final bool twoPane = _metrics.twoPane.value;
        final Widget transitioned = Theme.of(context).pageTransitionsTheme
            .buildTransitions<T>(
              this,
              context,
              animation,
              twoPane ? kAlwaysDismissedAnimation : secondaryAnimation,
              child!,
            );
        return PaneSlot(
          metrics: _metrics,
          entry: page.entry,
          clip: twoPane,
          child: transitioned,
        );
      },
    );
  }

  /// Keeps the framework's idea of the opacity of the page in sync with the
  /// current mode (the mode changes without any transition running).
  ///
  /// Mirrors what `TransitionRoute` does when an animation settles: the
  /// barrier entry is the one whose `opaque` flag tells the [Overlay] to stop
  /// painting the pages below.
  void syncPaneMode() {
    changedInternalState();
    final List<OverlayEntry> entries = overlayEntries.toList();
    if (entries.isEmpty) return;
    final bool settled = animation?.status == AnimationStatus.completed;
    entries.first.opaque = opaque && settled;
  }
}

/// The navigator of one branch.
///
/// It is a [Navigator] whose state intercepts [NavigatorState.maybePop] to
/// tell where the back comes from: with two panes, the back arrow of the page
/// drawn on the right pops that page, the arrow of the page drawn on the left
/// pops both visible pages in one router update. The pane is inferred from the
/// last pointer-down (the tap on the arrow) or, without a pointer, from where
/// the primary focus is.
class _BranchNavigator extends Navigator {
  _BranchNavigator({
    required super.key,
    required super.pages,
    required super.onDidRemovePage,
    required this.owner,
    required this.metrics,
    required this.branchIndex,
    required this.tracker,
    required this.onPaneBack,
  }) : super(observers: <NavigatorObserver>[tracker]);

  /// The delegate that owns this navigator.
  final FoldableRouterDelegate owner;

  final PaneMetrics metrics;
  final int branchIndex;
  final _TopRouteTracker tracker;
  final void Function(Object? result) onPaneBack;

  @override
  _BranchNavigatorState createState() => _BranchNavigatorState();
}

class _BranchNavigatorState extends NavigatorState {
  _BranchNavigator get _branch => widget as _BranchNavigator;

  /// Pops one page, for the back the delegate initiates (system back).
  ///
  /// It bypasses the pane inference: the system back always pops the top
  /// page only.
  Future<bool> popFromDelegate<T extends Object?>([T? result]) =>
      super.maybePop<T>(result);

  @override
  Future<bool> maybePop<T extends Object?>([T? result]) {
    final PaneMetrics metrics = _branch.metrics;
    if (metrics.twoPane.value) {
      final Route<Object?>? top = _branch.tracker.topRoute;
      // A pageless route on top (sheet, menu) is not ours: let it pop.
      if (top != null && top.settings is Page<Object?>) {
        final FoldablePane? pane = metrics.pointerPane ?? _paneFromFocus();
        if (pane == FoldablePane.primary) {
          metrics.pointerPane = null;
          _branch.onPaneBack(result);
          return SynchronousFuture<bool>(true);
        }
      }
    }
    return super.maybePop<T>(result);
  }

  /// The pane of the page that holds the primary focus, if any.
  FoldablePane? _paneFromFocus() {
    final BuildContext? context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    PaneEntryRef? found;
    context.visitAncestorElements((Element element) {
      final Widget widget = element.widget;
      if (widget is PaneScope) {
        found = widget.entry;
        return false;
      }
      return true;
    });
    final PaneEntryRef? entry = found;
    if (entry is! _Entry || entry.paneFrozen) return null;
    final _Shell? shell = _owner?._shell;
    final List<_Entry>? stack = shell?.branchStacks[_branch.branchIndex];
    if (stack == null || !stack.any((_Entry e) => identical(e, entry))) {
      return null;
    }
    return entry.pane.value;
  }

  FoldableRouterDelegate? get _owner => _branch.owner;
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
///
/// Whatever reaches it from below is forwarded once per burst, with the last
/// value only. A [Navigator] that receives a new `pages` list empties and
/// refills its history, and reports "cannot pop" then "can pop" in the same
/// frame even when nothing changed. Sent as is, that pair makes Android
/// unregister and register the back callback of the app again, which puts it
/// above the callback of the on-screen keyboard: the key that hides the
/// keyboard then pops a page instead.
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

  /// The last value received in the current burst, not forwarded yet.
  bool? _pending;

  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _forwardLater(widget.canHandlePop.value);
    });
  }

  /// Forwards [canHandlePop] once the notifications dispatched together with
  /// it (the post-frame callbacks of one frame) are all in: the last one
  /// wins, as it did when each of them went up on its own.
  void _forwardLater(bool canHandlePop) {
    final bool scheduled = _pending != null;
    _pending = canHandlePop;
    if (scheduled) return;
    scheduleMicrotask(() {
      final bool? value = _pending;
      _pending = null;
      if (!mounted || value == null) return;
      // Bubbles up to WidgetsApp, which forwards the value to the platform.
      NavigationNotification(canHandlePop: value).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<NavigationNotification>(
        onNotification: (NavigationNotification notification) {
          _forwardLater(notification.canHandlePop);
          return true;
        },
        child: widget.child,
      );
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

  /// The context of the `Router` widget, set by [setRouterContext] the first
  /// time Flutter parses a location. It is the context go_router passes to
  /// redirects: above the navigators, below whatever wraps
  /// `MaterialApp.router`.
  BuildContext? _routerContext;

  /// Records the context of the `Router` widget, handed over by the route
  /// information parser.
  void setRouterContext(BuildContext context) => _routerContext = context;

  /// The context redirects receive, or a [StateError] when the router has not
  /// been mounted yet (or has been unmounted).
  BuildContext _requireRouterContext() {
    final context = _routerContext;
    if (context == null || !context.mounted) {
      throw StateError(
        'This FoldableRouter is not attached to the widget tree: open, '
        'openUri, push and refresh need the BuildContext of the Router '
        'widget, which exists only after routerConfig has been given to '
        'MaterialApp.router (or Router) and that widget has been mounted.',
      );
    }
    return context;
  }

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

  /// Whether the latest navigation (from the app or the platform) is still
  /// resolving. A silent re-check never starts while this is true.
  bool _navigationRunning = false;

  /// Whether a silent re-check is running.
  bool _silentRunning = false;

  /// Identifies the latest silent re-check; older replaced ones stop quietly.
  int _silentGeneration = 0;

  /// The resolver token of the running silent re-check.
  int _silentToken = 0;

  /// Whether a silent re-check is already scheduled on the microtask queue.
  bool _silentScheduled = false;

  /// Whether a dependency changed while a navigation or a silent re-check was
  /// running, so one more silent re-check is owed once they finish.
  bool _recheckPending = false;

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
    final shell = _shell;
    if (shell != null) _refreshPaneAssignments(shell);
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
  ///
  /// This is an explicit navigation: it reports [isNavigating] while it runs
  /// and supersedes (and is superseded like) any other navigation.
  Future<void> refresh() async {
    final context = _requireRouterContext();
    final routes = stack;
    if (routes.isEmpty) return;
    final token = _begin();
    try {
      final redirected = await _resolver.firstRedirect(
        routes,
        context: context,
        target: routes.last,
        token: token,
      );
      if (redirected == null) return;
      if (!context.mounted) return;
      final chain = await _resolve(redirected, token, context);
      if (chain != null) _commitOpen(chain);
    } finally {
      _end(token);
    }
  }

  int _begin() {
    final token = _resolver.begin();
    _navigationRunning = true;
    isNavigating.value = true;
    return token;
  }

  void _end(int token) {
    if (_disposed || !_resolver.isCurrent(token)) return;
    isNavigating.value = false;
    _navigationRunning = false;
    // The navigation may have been started before the context changed; the
    // re-check it owed must run on the stack it left behind.
    _scheduleSilentRecheck();
  }

  /// Records that the location the `Router` sent is the one already shown, so
  /// the redirects of the stack must run again — a silent re-check.
  ///
  /// A silent re-check never supersedes a running navigation: changes that
  /// land while one runs are coalesced into a single pass started once it
  /// finishes. A silent re-check that is itself running is replaced by the
  /// newer one, so the last change always gets a pass.
  void _requestSilentRecheck() {
    if (_navigationRunning) {
      _recheckPending = true;
      return;
    }
    _recheckPending = false;
    _startSilentRecheck();
  }

  void _scheduleSilentRecheck() {
    if (!_recheckPending || _silentScheduled) return;
    _silentScheduled = true;
    scheduleMicrotask(() {
      _silentScheduled = false;
      _maybeStartSilentRecheck();
    });
  }

  void _maybeStartSilentRecheck() {
    if (_disposed || !_recheckPending) return;
    if (_navigationRunning) return;
    // A silent check made stale by a navigation must not hold up the pass
    // owed for that navigation.
    if (_silentRunning && _resolver.isCurrent(_silentToken)) return;
    _recheckPending = false;
    _startSilentRecheck();
  }

  void _startSilentRecheck() {
    if (_disposed || stack.isEmpty) return;
    final generation = ++_silentGeneration;
    final token = _resolver.begin();
    _silentToken = token;
    _silentRunning = true;
    unawaited(_runSilentRecheck(token, generation));
  }

  /// Re-runs the redirects of the stack like [refresh], but without reporting
  /// [isNavigating]: it is a consequence of a dependency change, not a
  /// navigation the app asked for. A navigation started meanwhile wins.
  Future<void> _runSilentRecheck(int token, int generation) async {
    try {
      final context = _routerContext;
      if (context == null || !context.mounted) return;
      final routes = stack;
      if (routes.isEmpty) return;
      final redirected = await _resolver.firstRedirect(
        routes,
        context: context,
        target: routes.last,
        token: token,
      );
      if (redirected == null ||
          !_resolver.isCurrent(token) ||
          !context.mounted) {
        return;
      }
      final chain = await _resolve(redirected, token, context);
      if (chain != null) _commitOpen(chain);
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'foldable_router',
          context: ErrorDescription(
            'while re-running redirects after a dependency change',
          ),
        ),
      );
    } finally {
      if (generation == _silentGeneration) {
        _silentRunning = false;
        // A navigation that ended while the check ran, or a change that
        // landed since, owes one more pass.
        _maybeStartSilentRecheck();
      }
    }
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
  Future<List<FoldableRoute>?> _resolve(
    FoldableRoute target,
    int token,
    BuildContext context,
  ) async {
    var current = target;
    for (var restarts = 0; ; restarts++) {
      final chain = await _resolver.resolve(
        current,
        context: context,
        token: token,
      );
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
    final context = _requireRouterContext();
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
      final chain = await _resolve(target, token, context);
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
    final context = _requireRouterContext();
    final token = _begin();
    try {
      final target = built == null ? shell.branches[index] : built.last.route;
      final chain = await _resolve(target, token, context);
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
    _requireRouterContext();
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
    if (_disposed) return;
    // Flutter re-parses the location currently shown when something the
    // `Router` depends on changes (a `MediaQuery.sizeOf` / `Theme.of` read
    // from a redirect, a resize, ...). A location equal to the one on screen
    // is not opened again: that would rebuild the parent chain of the top
    // route and drop pushed pages. It runs a silent re-check instead, which
    // waits for any navigation in flight rather than replacing it.
    if (configuration == currentConfiguration) {
      _requestSilentRecheck();
      return;
    }
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
      // The system back always pops exactly one page: it does not go through
      // the pane inference of the back buttons.
      return branchNavigator.popFromDelegate();
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

  /// Builds the frame of [shell] around the nested navigators of the
  /// branches: each branch stays at a fixed place in the tree (offstage when
  /// it is not the current one), and the current branch is wrapped in the
  /// pane area, which asks the shell for its `buildPanes` layout.
  Widget _buildShellBody(BuildContext context, _Shell shell) {
    // Only the top page of the *visible* branch may take a back gesture: a
    // page on top of a hidden tab, of a branch covered by a full-screen
    // page, or of the whole shell covered by a dialog must not. The
    // framework only looks at the page's own navigator, hence the
    // [PanePopGate] in _EntryPage; its value follows the delegate's state.
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
              child: _BranchNavigator(
                key: shell.branchNavigators[i],
                owner: this,
                metrics: shell.panes[i],
                branchIndex: i,
                tracker: shell.topRoutes[i],
                onPaneBack: (Object? result) => _onPaneBack(i, result),
                pages: <Page<Object?>>[
                  for (final entry in entries)
                    _BranchPage(
                      entry: entry,
                      metrics: shell.panes[i],
                      popGate: shell.gestureGates[i],
                      contentBuilder: entry.route.build,
                    ),
                ],
                onDidRemovePage: (Page<Object?> page) =>
                    _onDidRemoveBranchPage(i, page),
              ),
            ),
          ),
        ),
      );
    }
    return shell.route.buildShell(
      context,
      FoldableShellState(
        child: BranchArea(
          route: shell.route,
          metrics: shell.panes[shell.current],
          stackLength: shell.branchStacks[shell.current]?.length ?? 0,
          onBuilt: (FoldablePanes panes, bool twoPane) =>
              _onAreaBuilt(shell, panes, twoPane),
          child: Stack(fit: StackFit.expand, children: children),
        ),
        currentIndex: shell.current,
        goBranch: goBranch,
      ),
    );
  }

  /// Called while the tab area builds, before the pages of the branch do.
  ///
  /// The mode of the tab (one or two panes) is only known here; it is
  /// published before the pages build, so they can pick it up in the same
  /// frame: the notifiers are listened to by widgets that are descendants of
  /// the tab area (marking them dirty is allowed while it builds). The routes
  /// of the branch also sync their opacity/barrier, which live in the
  /// navigator of the branch, a descendant as well.
  void _onAreaBuilt(_Shell shell, FoldablePanes panes, bool twoPane) {
    final PaneMetrics metrics = shell.panes[panes.branchIndex];
    metrics
      ..hasSecondary = panes.hasSecondary
      ..stackLength = shell.branchStacks[panes.branchIndex]?.length ?? 0;
    if (metrics.twoPane.value != twoPane) {
      metrics.twoPane.value = twoPane;
      _syncBranchRoutes(shell, panes.branchIndex);
    }
    _refreshPaneAssignments(shell);
    _scheduleFrameChecks(metrics);
  }

  /// Schedules, after the frame that built the tab area, the report of frames
  /// the app forgot to place.
  void _scheduleFrameChecks(PaneMetrics metrics) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (!metrics.twoPane.value) return;
      if (metrics.primaryFrames == 0 && !metrics.reportedMissing) {
        metrics.reportedMissing = true;
        _reportMissingFrame(
          metrics,
          'primary',
          'FoldablePanes.primary must be placed in the widget tree returned '
              'by FoldableShellRoute.buildPanes, once for each two-pane tab.',
        );
      } else if (metrics.hasSecondary &&
          metrics.secondaryFrames == 0 &&
          !metrics.reportedMissing) {
        metrics.reportedMissing = true;
        _reportMissingFrame(
          metrics,
          'secondary',
          'The stack of the tab has at least two pages, so the layout of '
              'FoldableShellRoute.buildPanes must place FoldablePanes.secondary: '
              'without it there is nowhere to draw the top page.',
        );
      }
    });
  }

  void _reportMissingFrame(PaneMetrics metrics, String pane, String detail) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('A two-pane tab does not place its $pane pane.'),
          ErrorDescription(detail),
          ErrorHint(
            'Return null from FoldableShellRoute.buildPanes to use one pane, '
            'or place FoldablePanes.$pane in the returned layout.',
          ),
          DiagnosticsProperty<String>('Branch', '${metrics.branchIndex}'),
        ]),
        library: 'foldable_router',
        context: ErrorDescription('while laying out the panes of a tab'),
      ),
    );
  }

  /// Recomputes the pane and the position of every page of every branch.
  ///
  /// Entries that leave their stack keep the pane (and the visibility) they
  /// had, so a page that animates out keeps coming from the pane it was
  /// drawn in even if the stack around it changed.
  void _refreshPaneAssignments(_Shell shell) {
    final Set<_Entry> live = <_Entry>{};
    for (var i = 0; i < shell.branchStacks.length; i++) {
      final List<_Entry>? stack = shell.branchStacks[i];
      if (stack == null) continue;
      final bool twoPane = shell.panes[i].twoPane.value;
      final int length = stack.length;
      for (var j = 0; j < length; j++) {
        final _Entry entry = stack[j];
        live.add(entry);
        entry.branchIndex = i;
        final int position = length - 1 - j;
        if (entry.position.value != position) entry.position.value = position;
        final FoldablePane pane = _paneFor(position, length, twoPane);
        if (entry.pane.value != pane) entry.pane.value = pane;
        entry.paneFrozen = false;
        entry.frozenPane = null;
        entry.frozenHidden = false;
      }
    }
    for (final _Entry entry in shell.knownEntries) {
      if (live.contains(entry) || entry.paneFrozen) continue;
      final int branchIndex = entry.branchIndex;
      final bool twoPane = branchIndex >= 0 && branchIndex < shell.panes.length
          ? shell.panes[branchIndex].twoPane.value
          : false;
      entry.paneFrozen = true;
      entry.frozenPane = entry.pane.value;
      entry.frozenHidden = twoPane && entry.position.value > 1;
    }
    shell.knownEntries = live;
  }

  /// The pane a page at [position] from the top of a stack of [length] pages
  /// is shown in, or [FoldablePane.single] in a one-pane tab.
  static FoldablePane _paneFor(int position, int length, bool twoPane) {
    if (!twoPane) return FoldablePane.single;
    if (position == 0) {
      return length >= 2 ? FoldablePane.secondary : FoldablePane.primary;
    }
    return FoldablePane.primary;
  }

  /// Brings the routes of one branch in line with its current mode (their
  /// opacity and their barrier are read by the overlay of the branch).
  void _syncBranchRoutes(_Shell shell, int branchIndex) {
    final List<_Entry>? stack = shell.branchStacks[branchIndex];
    if (stack == null) return;
    for (final _Entry entry in stack) {
      final Route<Object?>? route = entry.navigatorRoute;
      if (route is _BranchPageRoute<Object?>) route.syncPaneMode();
    }
  }

  /// The back arrow of the *left* pane in a two-pane tab: pops the page drawn
  /// on the left and every page above it (the page on the right included) in
  /// one update of the stack.
  void _onPaneBack(int branchIndex, Object? result) {
    final _Shell? shell = _shell;
    if (shell == null) return;
    final List<_Entry>? branch = shell.branchStacks[branchIndex];
    if (branch == null || branch.length < 2) return;
    // The page drawn on the left is the root of the tab: it has no back arrow
    // and cannot be removed.
    if (branch.length == 2) return;
    if (_vetoesBack(shell.topRoutes[branchIndex].topRoute)) return;
    final before = _snapshot();
    final List<_Entry> removed = branch.sublist(branch.length - 2);
    shell.branchStacks[branchIndex] = branch.sublist(0, branch.length - 2);
    for (final _Entry entry in removed) {
      entry.complete();
    }
    _notifyAfter(before);
  }

  /// Whether the route on top of the navigator refuses to be popped (a user
  /// `PopScope(canPop: false)`); its callback is invoked, as `maybePop` does.
  bool _vetoesBack(Route<Object?>? top) {
    if (top == null || top.popDisposition != RoutePopDisposition.doNotPop) {
      return false;
    }
    top.onPopInvokedWithResult(false, null);
    return true;
  }

  /// Removes [entryRef] and every page above it, in one update of the stack.
  ///
  /// The root of a tab (and the root of the whole router) cannot be removed:
  /// closing it does nothing. A page that refuses to be popped (`PopScope`)
  /// and is at the top of its stack cancels the whole close.
  void closeEntry(PaneEntryRef entryRef) {
    final _Entry entry = entryRef as _Entry;
    final before = _snapshot();
    final _Shell? shell = _shell;
    List<_Entry>? stack;
    int start = 0;
    int branchIndex = -1;
    bool inOverlays = false;
    Route<Object?>? veto;

    if (shell == null) {
      final int index = _stack.indexWhere((_Entry e) => identical(e, entry));
      if (index <= 0) return;
      stack = List<_Entry>.of(_stack);
      start = index;
      veto = _rootTop.topRoute;
    } else {
      final int overlayIndex = shell.overlays.indexWhere(
        (_Entry e) => identical(e, entry),
      );
      if (overlayIndex >= 0) {
        stack = List<_Entry>.of(shell.overlays);
        start = overlayIndex;
        inOverlays = true;
        veto = _rootTop.topRoute;
      } else {
        for (var i = 0; i < shell.branchStacks.length; i++) {
          final List<_Entry>? branch = shell.branchStacks[i];
          if (branch == null) continue;
          final int index = branch.indexWhere(
            (_Entry e) => identical(e, entry),
          );
          if (index < 0) continue;
          if (index == 0) return; // The root of the tab cannot be closed.
          stack = List<_Entry>.of(branch);
          start = index;
          branchIndex = i;
          veto = shell.topRoutes[i].topRoute;
          break;
        }
      }
    }
    if (stack == null) return;
    if (_vetoesBack(veto)) return;

    final List<_Entry> removed = stack.sublist(start);
    if (shell == null) {
      _stack = _stack.sublist(0, start);
    } else if (inOverlays) {
      shell.overlays = shell.overlays.sublist(0, start);
    } else {
      shell.branchStacks[branchIndex] = shell.branchStacks[branchIndex]!
          .sublist(0, start);
    }
    for (final _Entry entry in removed) {
      entry.complete();
    }
    _notifyAfter(before);
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
    _routerContext = null;
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
