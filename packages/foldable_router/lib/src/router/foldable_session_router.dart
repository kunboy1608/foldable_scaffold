import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_navigator.dart';
import '../route/branch_route.dart';
import '../route/foldable_route.dart';
import 'foldable_router.dart';
import 'foldable_router_config.dart';
import 'foldable_router_observer.dart';

/// Builds the widget tree of a [FoldableSession] around its page stacks.
///
/// Usually a [FoldableNavigator] inside a scaffold, but it can be anything: a
/// full screen flow with no scaffold at all.
///
/// [navigator] creates the session's navigator, already configured with the
/// session's [FoldableSession.navigator] kind. Pass it the builder that
/// arranges the pages in your scaffold:
///
/// ```dart
/// shell: (context, controller, navigator) => navigator(
///   (context, body, secondaryBody) => FoldableScaffold(
///     bodyBuilder: (_, _) => body,
///     secondaryBodyBuilder: (_, _) => secondaryBody,
///     hasSecondaryBody: secondaryBody != null,
///   ),
/// ),
/// ```
///
/// A [FoldableSessionStack] ignores the builder and fills the
/// screen with its top page. When [FoldableSession.shell] is null the session
/// builds a full screen shell itself, so the simplest sessions only need to
/// pick [FoldableSessionStack] or [FoldableSessionSplit].
typedef FoldableSessionShellBuilder =
    Widget Function(
      BuildContext context,
      FoldableNavigatorController controller,
      FoldableNavigator Function(FoldableNavigatorBuilder builder) navigator,
    );

/// One self-contained part of an app: its own roots (tabs), redirects and
/// the shell that draws them.
///
/// For example a signed out `guest` session with the sign in flow, an
/// `onboarding` session that fills the screen without a navigation rail, and
/// a `main` session with the home tabs.
///
/// This is the base class; use [FoldableSessionSplit] (tabs in panes) or
/// [FoldableSessionStack] (only the top page, full screen).
@immutable
abstract class FoldableSession {
  const FoldableSession({
    required this.id,
    this.shell,
    this.disposeOnLeave = false,
    this.deepLinkable = false,
    this.initialRoute,
    this.closable = true,
    this.canActivate,
    this.canBeBase = true,
    this.parent,
  });

  /// Name used by `openSession`, [FoldableSessionRouter.refresh] and
  /// [FoldableRoute.session].
  final String id;

  /// The bottom page of every branch (tab) of this session.
  List<FoldableRoute> get roots;

  /// The [FoldableNavigator] that shows the pages of this session.
  ///
  /// [builder] arranges the panes of a split session; a stack session ignores
  /// it.
  FoldableNavigator createNavigator(
    FoldableNavigatorController controller,
    FoldableNavigatorBuilder builder,
  );

  /// Draws the pages of this session inside a custom shell, usually a
  /// scaffold. When null the session paints the navigator full screen.
  final FoldableSessionShellBuilder? shell;

  /// Whether the page stacks are thrown away when another session takes over,
  /// for example to forget what the last user opened. They are created again
  /// the next time the session is shown.
  final bool disposeOnLeave;

  /// Whether a URL that the session on screen does not know may switch to this
  /// session, see [FoldableSessionRouter.goUri].
  ///
  /// Leave it false for sessions a URL must never reach by itself, like a
  /// signed in area.
  final bool deepLinkable;

  /// The route shown when the session is opened with
  /// [FoldableSessionRouter.openSession] and its page stacks were just created
  /// (the first time, or after [disposeOnLeave]). A `route` passed to
  /// `openSession` wins. Null shows the first root.
  final FoldableRoute? initialRoute;

  /// Whether [FoldableSessionRouter.closeSession] and the back buttons may
  /// close this session once it is opened over another one. Set it false for
  /// a flow that must be finished or left by its own routes.
  final bool closable;

  /// The condition for this session to exist, or null for always. May be
  /// async, for example `(context) async => await context.read<Auth>().isSignedIn`.
  ///
  /// [context] is the one of the root navigator, below everything the app
  /// provides above its `MaterialApp.router`. Read what you need from it before
  /// the first `await`: it may not be mounted after.
  ///
  /// It is not a redirect: nothing is shown instead. The router asks it only
  /// in [FoldableSessionRouter.refresh], which the app calls at start up and
  /// whenever the state the condition reads changes. A session that does not
  /// hold is closed, with its page stacks, and cannot be opened by
  /// `openSession`, `replaceSession`, `resetSession(id)`, a route that names it
  /// with [FoldableRoute.session], or a URL; [FoldableSessionRouter
  /// .onActivationDenied] is told.
  final FutureOr<bool> Function(BuildContext context)? canActivate;

  /// Whether this session may be the base of the open sessions: the one chosen
  /// when the app opens, or after `resetSession()`. Set it false for a session
  /// that is only opened over another one, like a checkout.
  final bool canBeBase;

  /// The id of the session this one is opened over, like a checkout over
  /// `main`. When that session stops existing, because its [canActivate] does
  /// not hold or its own parent goes, this one goes with it.
  final String? parent;
}

/// A session with one page stack per branch (tab), shown in two panes: the
/// second-to-top page in the body and the top page in the secondary body. Like
/// `FoldableNavigator(controller: ..., builder: ...)`.
///
/// [branches] are the roots of the tabs, in order. Needs at least one.
class FoldableSessionSplit extends FoldableSession {
  const FoldableSessionSplit({
    required super.id,
    required this.branches,
    super.shell,
    super.disposeOnLeave,
    super.deepLinkable,
    super.initialRoute,
    super.closable,
    super.canActivate,
    super.canBeBase,
    super.parent,
  }) : assert(
         branches.length > 0,
         'A split session needs at least one branch.',
       );

  /// The root route of every branch (tab), see [BranchRoute].
  final List<BranchRoute> branches;

  @override
  List<FoldableRoute> get roots => branches;

  @override
  FoldableNavigator createNavigator(
    FoldableNavigatorController controller,
    FoldableNavigatorBuilder builder,
  ) => FoldableNavigator(controller: controller, builder: builder);
}

/// A session that shows only the top page of the current branch, full screen,
/// like [FoldableNavigator.stack].
///
/// The pages below the top one and the other branches are not mounted. Use it
/// for flows without tabs, like sign in or onboarding. [initRoute] is the
/// first page.
///
/// Without an [initRoute] the session starts with no page, like a `Navigator`
/// with no routes: it draws nothing until a route is shown in it with
/// `openSession(id, route:)`, or a route that names it with
/// [FoldableRoute.session]. The pages below the top one are kept, the last one
/// is not popped by [FoldableSessionRouter.pop], and back at it closes the
/// session when it is [FoldableSession.closable] and open over another one.
class FoldableSessionStack extends FoldableSession {
  const FoldableSessionStack({
    required super.id,
    this.initRoute,
    super.shell,
    super.disposeOnLeave,
    super.deepLinkable,
    super.closable,
    super.canActivate,
    super.canBeBase,
    super.parent,
  });

  /// The first page of the session, or null to start with no page.
  final FoldableRoute? initRoute;

  @override
  List<FoldableRoute> get roots => [?initRoute];

  @override
  FoldableNavigator createNavigator(
    FoldableNavigatorController controller,
    FoldableNavigatorBuilder builder,
  ) => FoldableNavigator.stack(controller: controller);
}

/// A router made of several [FoldableSession]s. Sessions can be stacked: one
/// is opened over another, only the top one is on screen, and closing it shows
/// the one below with its page stacks as they were.
///
/// Each session is a [FoldableRouter] of its own, created the first time it is
/// shown. Which sessions may exist is decided by [FoldableSession.canActivate]
/// (and [FoldableSession.parent]); the router never watches the app state, the
/// app calls [refresh] when it changes, for example after sign in or sign out.
/// A session opens another one with [openSession] and closes itself with
/// [closeSession]:
///
/// ```dart
/// final result = await router.openSession<bool>('checkout');
/// // ... in the checkout session:
/// router.closeSession(true);
/// ```
///
/// Put a [FoldableSessionBackButton] in the app bar of a shell to close the
/// session on top.
///
/// ```dart
/// final router = FoldableSessionRouter(
///   sessions: [guestSession, mainSession, checkoutSession],
///   onNoSession: (router) => showLockedScreen(),
/// );
///
/// // Once, and whenever the sign in state changes:
/// auth.addListener(router.refresh);
/// await router.refresh();
///
/// MaterialApp.router(
///   routerDelegate: FoldableRouterDelegate(
///     router: router,
///     navigatorKey: rootNavigatorKey,
///     builder: router.buildShell,
///   ),
///   routeInformationParser: const FoldableRouteInformationParser(),
/// );
/// ```
///
/// Navigation ([go], [push], [back], …) acts on the session on screen, except
/// for a route that names another session with [FoldableRoute.session]: that
/// session is created, or moved to the top if it is open, and shows the route.
///
/// When any session has a [FoldableSession.canActivate], nothing is on screen
/// until the first [refresh] completes: URLs and navigation that arrive first
/// wait for it. While a [refresh] runs, navigation waits for it too.
class FoldableSessionRouter extends ChangeNotifier with FoldableRouterBase {
  FoldableSessionRouter({
    required this.sessions,
    this.onActivationDenied,
    this.onNoSession,
    FoldableRouterConfig? config,
  }) : _config = config,
       assert(sessions.isNotEmpty, 'At least one session is required.'),
       assert(
         sessions.map((session) => session.id).toSet().length ==
             sessions.length,
         'Session ids must be unique.',
       ),
       assert(
         sessions.every(
           (session) =>
               session.parent == null ||
               sessions.any((other) => other.id == session.parent),
         ),
         'FoldableSession.parent must name a session of this router.',
       ) {
    // Without conditions there is nothing to wait for.
    if (sessions.every((session) => session.canActivate == null)) {
      _allowed = {for (final session in sessions) session.id};
      _stack.add(
        _firstBase() ??
            (throw StateError(
              'No FoldableSession can be the base: canBeBase is false for '
              'every session.',
            )),
      );
      _completers.add(Completer<Object?>());
    }
  }

  /// Every session of the app.
  final List<FoldableSession> sessions;

  FoldableRouterConfig? _config;

  /// Gives every session the app's shared [FoldableRouterConfig], also the
  /// ones created later. [FoldableRouterDelegate] calls it.
  @override
  void attachConfig(FoldableRouterConfig config) {
    _config = config;
    for (final router in _routers.values) {
      router.attachConfig(config);
    }
  }

  /// Called when a session could not be activated because it is not one of
  /// the sessions that exist (see [FoldableSession.canActivate]). Use it to
  /// explain, or to ask the app to sign in.
  final ValueChanged<FoldableSession>? onActivationDenied;

  /// Called by [refresh] when no session is left: none holds its condition
  /// (or can be the base). Nothing is on screen until the next [refresh]
  /// finds one. Null throws a [StateError] instead.
  final ValueChanged<FoldableSessionRouter>? onNoSession;

  /// Whether a session is on screen to navigate in: always true unless the
  /// first [refresh] did not complete yet, or it left no session.
  bool get isResolved => _stack.isNotEmpty;

  /// Whether a [refresh] is running.
  bool get isRefreshing => _refreshing != null;

  /// The ids of the sessions that exist after the last [refresh], or null
  /// before the first one.
  Set<String>? _allowed;
  Future<void>? _refreshing;
  bool _rerun = false;

  /// Navigation that arrived while the sessions were being evaluated.
  final _waiting = <VoidCallback>[];
  Uri? _pendingUri;
  Map<String, Object?>? _pendingRestore;
  bool _disposed = false;
  bool _resolving = false;

  @override
  void notifyListeners() {
    if (!_resolving) super.notifyListeners();
  }

  /// Asks every [FoldableSession.canActivate] again and brings the open
  /// sessions in line with the answers.
  ///
  /// * A session that does not hold, and every session that has it as its
  ///   [FoldableSession.parent], is closed and its page stacks are discarded.
  /// * When the session on screen goes, the one below it is shown. When none
  ///   is left, the first one that can be the base (see
  ///   [FoldableSession.canBeBase]) and holds becomes the base; when there is
  ///   none, [onNoSession] is called.
  /// * Sessions run in parallel. Navigation that arrives meanwhile waits and
  ///   runs after, in order.
  /// * A URL that waited for the first [refresh] and names a session that does
  ///   not exist yet is kept, and opened by the first [refresh] after that
  ///   session exists.
  ///
  /// The conditions get the [BuildContext] of the root navigator. When it does
  /// not exist yet, as when this is called before the first frame, the
  /// [refresh] waits for it.
  ///
  /// Call it once at start up and whenever the state the conditions read
  /// changes. A call during a [refresh] runs another one after it; both
  /// futures complete together.
  Future<void> refresh() {
    final running = _refreshing;
    if (running != null) {
      _rerun = true;
      return running;
    }
    return _refreshing = _refreshLoop();
  }

  Future<void> _refreshLoop() async {
    try {
      do {
        _rerun = false;
        final allowed = await _evaluate();
        if (_disposed || allowed == null) return;
        _apply(allowed);
      } while (_rerun);
    } finally {
      _refreshing = null;
      if (!_disposed && _allowed != null) _flush();
    }
  }

  /// The ids of the sessions whose condition holds, and whose parents do, or
  /// null when the router was disposed while waiting for a context.
  Future<Set<String>?> _evaluate() async {
    BuildContext? context;
    if (sessions.any((session) => session.canActivate != null)) {
      context = rootContextOf?.call();
      while (context == null) {
        // No BuildContext yet, as when the app calls refresh before the first
        // build.
        await WidgetsBinding.instance.endOfFrame;
        if (_disposed) return null;
        context = rootContextOf?.call();
      }
    }
    final passed = <String>{};
    await Future.wait([
      for (final session in sessions)
        Future<bool>.sync(
          () => session.canActivate?.call(context!) ?? true,
        ).then((holds) => holds ? passed.add(session.id) : false),
    ]);
    bool exists(FoldableSession session, int depth) {
      if (!passed.contains(session.id)) return false;
      final parent = session.parent;
      if (parent == null) return true;
      // A parent loop never holds.
      return depth < sessions.length && exists(_sessionById(parent), depth + 1);
    }

    return {
      for (final session in sessions)
        if (exists(session, 0)) session.id,
    };
  }

  void _apply(Set<String> allowed) {
    _allowed = allowed;
    // Nothing here may notify while the stack is half changed.
    _resolving = true;
    try {
      for (var i = _stack.length - 1; i >= 0; i--) {
        if (allowed.contains(_stack[i])) continue;
        _stack.removeAt(i);
        final completer = _completers.removeAt(i);
        if (!completer.isCompleted) completer.complete(null);
      }
      for (final id in _routers.keys.toList()) {
        if (!allowed.contains(id)) _discard(id);
      }
      if (_stack.isEmpty) {
        final base = _firstBase();
        if (base != null) {
          _stack.add(base);
          _completers.add(Completer<Object?>());
        }
      }
      final restore = _pendingRestore;
      if (restore != null && _stack.isNotEmpty) {
        _pendingRestore = null;
        restoreState(restore);
      }
    } finally {
      _resolving = false;
    }
    notifyListeners();
    if (_stack.isEmpty) {
      final handler = onNoSession;
      if (handler == null) {
        throw StateError(
          'No FoldableSession holds its condition and onNoSession is not set.',
        );
      }
      handler(this);
      return;
    }
    final uri = _pendingUri;
    if (uri != null) {
      // A URL of a session that does not exist yet waits for it.
      final owner = _config?.match(uri)?.session;
      if (owner == null || allowed.contains(owner)) {
        _pendingUri = null;
        _goUriNow(uri);
      }
    }
  }

  void _flush() {
    if (_stack.isEmpty || _waiting.isEmpty) return;
    final actions = List.of(_waiting);
    _waiting.clear();
    actions.forEach((action) => action());
  }

  /// Whether navigation has to wait: sessions are being evaluated, or were
  /// never evaluated.
  bool get _busy => _refreshing != null || _allowed == null;

  void _later(VoidCallback action) {
    if (_busy) {
      _waiting.add(action);
    } else {
      action();
    }
  }

  Future<T?> _laterFuture<T>(Future<T?> Function() run) {
    if (!_busy) return run();
    final completer = Completer<T?>();
    _waiting.add(() {
      try {
        completer.complete(run());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  /// The first session in [sessions] that can be the base and exists, or null.
  String? _firstBase() {
    for (final session in sessions) {
      if (session.canBeBase && _isAllowed(session.id)) return session.id;
    }
    return null;
  }

  /// Whether session [id] exists as of the last [refresh].
  bool _isAllowed(String id) => _allowed?.contains(id) ?? false;

  /// Whether session [id] may be activated now. Tells [onActivationDenied]
  /// when it may not. The session on screen always may.
  bool _allows(String id) {
    if (_stack.isNotEmpty && id == _activeId) return true;
    if (_isAllowed(id)) return true;
    onActivationDenied?.call(_sessionById(id));
    return false;
  }

  final _routers = <String, FoldableRouter>{};
  final _observers = <FoldableRouterObserver>[];

  /// The ids of the sessions that are open, base first. The last one is on
  /// screen.
  final _stack = <String>[];

  /// Completes when the session at the same index of [_stack] is closed.
  final _completers = <Completer<Object?>>[];

  String get _activeId {
    if (_stack.isEmpty) {
      throw StateError(
        'No session is on screen yet: call refresh() and wait for it, see '
        'isResolved.',
      );
    }
    return _stack.last;
  }

  FoldableSession _sessionById(String id) {
    return sessions.firstWhere((session) => session.id == id);
  }

  /// The session on screen.
  FoldableSession get activeSession => _sessionById(_activeId);

  /// The id of the session on screen.
  String get activeSessionId => _activeId;

  /// The ids of the open sessions, the base session first and the one on
  /// screen last.
  List<String> get openSessionIds => List.unmodifiable(_stack);

  /// Whether more than one session is open.
  bool get hasStackedSessions => _stack.length > 1;

  /// Whether [closeSession] would close the session on screen: another session
  /// is open below it and it is [FoldableSession.closable].
  @override
  bool get canCloseSession => hasStackedSessions && activeSession.closable;

  /// The router of the session on screen.
  FoldableRouter get active => routerOf(_activeId);

  /// The page stacks of the session on screen.
  FoldableNavigatorController get controller => active.controller;

  /// The router of session [id], created if it was not shown yet.
  FoldableRouter routerOf(String id) {
    return _routers.putIfAbsent(id, () {
      final session = _sessionById(id);
      final router =
          FoldableRouter(
              roots: session.roots,
              allowEmptyRoots: session.roots.isEmpty,
              config: _config,
            )
            ..rootContextOf = (() => rootContextOf?.call())
            ..addListener(notifyListeners);
      _observers.forEach(router.addObserver);
      return router;
    });
  }

  /// Draws the session on screen. Pass it as the `builder` of
  /// [FoldableRouterDelegate].
  ///
  /// Uses the [FoldableSession.navigator] kind of the session and, when
  /// [FoldableSession.shell] is set, lets the shell arrange the navigator.
  /// The shell is rebuilt from scratch when the session or its page stacks
  /// are replaced.
  Widget buildShell(BuildContext context) {
    if (!isResolved) return const SizedBox.shrink();
    final router = active;
    final session = activeSession;
    return KeyedSubtree(
      key: ObjectKey(router),
      child: Builder(
        builder: (context) {
          FoldableNavigator navigator(FoldableNavigatorBuilder builder) =>
              session.createNavigator(router.controller, builder);

          final shell = session.shell;
          return shell?.call(context, router.controller, navigator) ??
              navigator(
                (context, body, secondaryBody) => secondaryBody ?? body,
              );
        },
      ),
    );
  }

  /// Puts session [id] on screen in place of the current one, and optionally
  /// shows [route] in it.
  ///
  /// Use it for a hand-off, like the last step of an onboarding. [route] is
  /// shown with [FoldableRouter.go], so its redirects run and they apply to the
  /// new session. Only the session on screen is replaced; the ones below it
  /// stay. See [resetSession] to drop all of them.
  ///
  /// Returns false, and does nothing, when session [id] does not exist (see
  /// [FoldableSession.canActivate]).
  bool replaceSession(String id, {FoldableRoute? route}) {
    _sessionById(id);
    if (!_allows(id)) return false;
    _switchTo(id);
    if (route != null) active.go(null, route);
    return true;
  }

  /// Closes every open session and makes [id] the only one, with [route] shown
  /// in it if given.
  ///
  /// Use it when the app state changes under all of them, like signing in or
  /// out. The futures of [openSession] complete with null, and sessions with
  /// [FoldableSession.disposeOnLeave] are discarded.
  ///
  /// Returns false and does nothing when session [id] does not exist (see
  /// [FoldableSession.canActivate]). It uses the answers of the last [refresh]
  /// and does not wait for one that runs; call [refresh] to let the conditions
  /// choose the base.
  bool resetSession(String id, {FoldableRoute? route}) {
    _sessionById(id);
    if (!_allows(id)) return false;
    _removeFrom(0, keep: id);
    notifyListeners();
    if (route != null) active.go(null, route);
    return true;
  }

  /// Opens session [id] over the one on screen. The lower session keeps its
  /// page stacks; they are shown again when this one is closed.
  ///
  /// A session that is open already is moved to the top instead of created
  /// again. Shows [route] in it, else [FoldableSession.initialRoute] when its
  /// page stacks were just created. The future completes with the value given
  /// to [closeSession], or null when the session is replaced or dropped.
  ///
  /// Routes do this by themselves when [FoldableRoute.session] names another
  /// session, so call it directly only to open a session without a route.
  @override
  Future<T?> openSession<T extends Object?>(String id, {FoldableRoute? route}) {
    final session = _sessionById(id);
    return _laterFuture<T>(() {
      if (!_allows(id)) return Future<T?>.value();
      final fresh = !_routers.containsKey(id);
      final completer = _bringToTop(id);
      final target = route ?? (fresh ? session.initialRoute : null);
      if (target != null) active.go(null, target);
      return completer.future.then((value) => value is T ? value : null);
    });
  }

  /// Puts session [id] on top of the open sessions: creates it, or moves it
  /// from where it is. Does nothing when it is on top already.
  Completer<Object?> _bringToTop(String id) {
    _sessionById(id);
    final index = _stack.indexOf(id);
    if (index == _stack.length - 1) return _completers.last;
    final Completer<Object?> completer;
    if (index >= 0) {
      _stack.removeAt(index);
      completer = _completers.removeAt(index);
    } else {
      completer = Completer<Object?>();
    }
    _stack.add(id);
    _completers.add(completer);
    notifyListeners();
    return completer;
  }

  /// The router that shows [route]: the one of the session it names with
  /// [FoldableRoute.session], moved to the top or created, else the one on
  /// screen.
  ///
  /// Null when the session cannot be activated (see
  /// [FoldableSession.canActivate]): the navigation is dropped.
  FoldableRouter? _routerFor(FoldableRoute route) {
    final id = route.session;
    if (id != null && id != _activeId) {
      _sessionById(id);
      if (!_allows(id)) return null;
      _bringToTop(id);
    }
    return active;
  }

  /// Whether showing [route] first changes the session on screen.
  bool _switchesSession(FoldableRoute route) {
    final id = route.session;
    return id != null && id != _activeId;
  }

  /// Closes the session on screen and shows the one below, when
  /// [canCloseSession]. [result] completes the future of [openSession].
  ///
  /// Returns whether a session was closed.
  @override
  bool closeSession([Object? result]) {
    if (!canCloseSession) return false;
    _removeFrom(_stack.length - 1, result: result);
    notifyListeners();
    return true;
  }

  /// Puts [id] on screen in place of the top session, or, when it is open
  /// already, closes the sessions above it.
  void _switchTo(String id) {
    if (id == _activeId) return;
    final index = _stack.indexOf(id);
    if (index >= 0) {
      _removeFrom(index + 1);
    } else {
      final top = _stack.length - 1;
      _removeFrom(top, keep: id);
    }
    notifyListeners();
  }

  /// Removes the open sessions from [index] up. Each one's future completes
  /// with [result] (the top) or null, and a session with
  /// [FoldableSession.disposeOnLeave] is discarded. With [keep] the session
  /// takes the place of the removed ones.
  void _removeFrom(int index, {Object? result, String? keep}) {
    final removed = _stack.sublist(index);
    final completers = _completers.sublist(index);
    _stack.removeRange(index, _stack.length);
    _completers.removeRange(index, _completers.length);
    if (keep != null) {
      _stack.add(keep);
      _completers.add(Completer<Object?>());
    }
    for (var i = 0; i < removed.length; i++) {
      final isTop = i == removed.length - 1;
      final completer = completers[i];
      if (!completer.isCompleted) completer.complete(isTop ? result : null);
      final id = removed[i];
      if (id != keep && _sessionById(id).disposeOnLeave) _discard(id);
    }
  }

  /// The id of a session that claims [uri] when the one on screen does not,
  /// else null.
  String? _sessionClaiming(Uri uri) {
    final id = _config?.match(uri)?.session;
    if (id == null || id == _activeId) return null;
    final session = sessions.where((session) => session.id == id);
    return session.isNotEmpty && session.first.deepLinkable && _isAllowed(id)
        ? id
        : null;
  }

  /// Drops the router of [id] once the frame that still draws it is done.
  void _discard(String id) {
    final router = _routers.remove(id);
    if (router == null) return;
    router.removeListener(notifyListeners);
    WidgetsBinding.instance.addPostFrameCallback((_) => router.dispose());
  }

  /// See [FoldableRouter.routeOf].
  FoldableRoute routeOf(String location) => active.routeOf(location);

  /// See [FoldableRouter.resolve].
  FutureOr<FoldableRoute?> resolve(
    FoldableRoute route, {
    required BuildContext context,
    Uri? uri,
  }) => active.resolve(route, context: context, uri: uri);

  /// See [FoldableRouter.go].
  @override
  void go(BuildContext? context, FoldableRoute route) {
    // The context belongs to the session that was on screen: its page cannot
    // be the parent in another one.
    _later(() {
      final switches = _switchesSession(route);
      _routerFor(route)?.go(switches ? null : context, route);
    });
  }

  /// See [FoldableRouter.goLocation].
  ///
  /// A location only another [FoldableSession.deepLinkable] session knows
  /// switches to that session first.
  void goLocation(String location) {
    _later(() {
      _switchToClaiming(Uri.parse(location));
      active.goLocation(location);
    });
  }

  /// See [FoldableRouter.push].
  @override
  Future<T?> push<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) => _laterFuture<T>(
    () =>
        _routerFor(route)?.push<T>(route, context: context) ??
        Future<T?>.value(),
  );

  /// See [FoldableRouter.pushLocation].
  Future<void> pushLocation(String location, {BuildContext? context}) {
    return _laterFuture<void>(() {
      _switchToClaiming(Uri.parse(location));
      return active.pushLocation(location, context: context);
    });
  }

  /// See [FoldableRouter.pushAndReplace].
  @override
  Future<T?> pushAndReplace<T extends Object?>(
    FoldableRoute route, {
    BuildContext? context,
  }) => _laterFuture<T>(
    () =>
        _routerFor(route)?.pushAndReplace<T>(route, context: context) ??
        Future<T?>.value(),
  );

  /// See [FoldableRouter.pushAndRemoveUntil].
  @override
  Future<T?> pushAndRemoveUntil<T extends Object?>(
    FoldableRoute route,
    bool Function(Page<Object?> page) predicate, {
    BuildContext? context,
  }) => _laterFuture<T>(
    () =>
        _routerFor(
          route,
        )?.pushAndRemoveUntil<T>(route, predicate, context: context) ??
        Future<T?>.value(),
  );

  /// See [FoldableRouter.pushReplacementLocation].
  Future<void> pushReplacementLocation(
    String location, {
    BuildContext? context,
  }) {
    return _laterFuture<void>(() {
      _switchToClaiming(Uri.parse(location));
      return active.pushReplacementLocation(location, context: context);
    });
  }

  /// See [FoldableRouter.pop].
  bool pop([Object? result]) => active.pop(result);

  /// See [FoldableRouter.back].
  ///
  /// When the session on screen has nothing to go back to and another session
  /// is open below it, closes the session instead.
  void back([FoldableRoute? fallback]) {
    final router = active;
    if (!router.canPop &&
        !router.backGoesToRoot &&
        fallback == null &&
        closeSession()) {
      return;
    }
    router.back(fallback);
  }

  @override
  void addObserver(FoldableRouterObserver observer) {
    if (_observers.contains(observer)) return;
    _observers.add(observer);
    _routers.values.forEach((router) => router.addObserver(observer));
  }

  @override
  void removeObserver(FoldableRouterObserver observer) {
    _observers.remove(observer);
    _routers.values.forEach((router) => router.removeObserver(observer));
  }

  @override
  Uri get currentUri =>
      isResolved ? active.currentUri : (_pendingUri ?? Uri.parse('/'));

  ///
  /// A URL only another [FoldableSession.deepLinkable] session knows switches
  /// to that session first.
  @override
  void goUri(Uri uri) {
    // Before a session is on screen the latest URL wins.
    if (_allowed == null || !isResolved) {
      _pendingUri = uri;
      return;
    }
    _later(() => _goUriNow(uri));
  }

  void _goUriNow(Uri uri) {
    _switchToClaiming(uri);
    active.goUri(uri);
  }

  void _switchToClaiming(Uri uri) {
    final id = _sessionClaiming(uri);
    if (id != null) _switchTo(id);
  }

  /// The id of the session on screen and the page stacks of that session.
  /// The other sessions are not saved.
  @override
  Map<String, Object?> saveState() => isResolved
      ? {_sessionKey: _activeId, _routerKey: active.saveState()}
      : const {};

  /// Restores the stacks of the session on screen, if the snapshot is of that
  /// session.
  ///
  /// A snapshot saved for another session puts that session on screen, alone.
  /// A snapshot of a session this router does not have is ignored. See
  /// [FoldableRouter.restoreState] for the rest.
  @override
  void restoreState(Map<String, Object?> state) {
    if (!isResolved) {
      _pendingRestore = state;
      return;
    }
    final id = state[_sessionKey];
    final saved = state[_routerKey];
    if (id is! String || !sessions.any((session) => session.id == id)) return;
    if (saved is! Map<Object?, Object?>) return;
    if (saved.keys.any((key) => key is! String)) return;
    if (!_isAllowed(id)) return;
    if (id != _activeId) _removeFrom(0, keep: id);
    active.restoreState(saved.cast<String, Object?>());
  }

  static const _sessionKey = 'session';
  static const _routerKey = 'router';

  @override
  bool get backGoesToRoot =>
      isResolved &&
      (active.backGoesToRoot || (canCloseSession && !active.canPop));

  @override
  void goBackToRoot() {
    if (!isResolved) return;
    if (active.backGoesToRoot) {
      active.goBackToRoot();
    } else {
      closeSession();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final router in _routers.values) {
      router
        ..removeListener(notifyListeners)
        ..dispose();
    }
    _routers.clear();
    for (final completer in _completers) {
      if (!completer.isCompleted) completer.complete(null);
    }
    super.dispose();
  }
}
