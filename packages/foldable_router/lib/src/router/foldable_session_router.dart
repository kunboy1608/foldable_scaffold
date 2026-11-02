import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../foldable_navigator.dart';
import '../route/foldable_route.dart';
import 'foldable_router.dart';
import 'foldable_router_config.dart';
import 'foldable_router_observer.dart';

/// The navigator a [FoldableSession] shows its pages with.
enum FoldableNavigatorKind {
  /// One page stack per branch in two panes, like
  /// `FoldableNavigator(controller: ..., builder: ...)`.
  split,

  /// Only the top page of the current branch, full screen, like
  /// [FoldableNavigator.stack].
  ///
  /// The pages below the top one and the other branches are not mounted. Use
  /// it for flows without tabs, like sign in or onboarding.
  ///
  /// The session's [FoldableRouterConfig.roots] may be empty: the stack then
  /// starts blank, and the first navigation (the initial URL, a redirect, or
  /// `go`/`push`) fills it. With one root, that root is the first page.
  stack,
}

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
/// A [FoldableNavigatorKind.stack] navigator ignores the builder and fills the
/// screen with its top page. When [FoldableSession.shell] is null the session
/// builds a full screen shell itself, so the simplest sessions only need to
/// pick a [FoldableNavigatorKind].
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
@immutable
class FoldableSession {
  const FoldableSession({
    required this.id,
    required this.config,
    this.navigator = FoldableNavigatorKind.split,
    this.shell,
    this.disposeOnLeave = false,
    this.deepLinkable = false,
  });

  /// Name used by [FoldableSessionRouter.sessionOf].
  final String id;

  /// Roots, matcher and redirects of this session.
  final FoldableRouterConfig config;

  /// Which [FoldableNavigator] shows the pages of this session.
  ///
  /// The default, [FoldableNavigatorKind.split], keeps one page stack per
  /// branch and shows two panes. [FoldableNavigatorKind.stack] shows only the
  /// top page of the current branch, full screen, and does not keep branches.
  final FoldableNavigatorKind navigator;

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
}

/// A router made of several [FoldableSession]s, one on screen at a time.
///
/// Each session is a [FoldableRouter] of its own, created the first time it is
/// shown. The one on screen is whichever [sessionOf] names; call [refresh]
/// when the state it reads changes.
///
/// ```dart
/// final router = FoldableSessionRouter(
///   sessions: [guestSession, onboardingSession, mainSession],
///   sessionOf: () {
///     if (!auth.isLoggedIn) return 'guest';
///     return profile.isOnboarded ? 'main' : 'onboarding';
///   },
/// );
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
/// Navigation ([go], [push], [back], …) acts on the session on screen.
class FoldableSessionRouter extends ChangeNotifier with FoldableRouterBase {
  FoldableSessionRouter({required this.sessions, required this.sessionOf})
    : assert(sessions.isNotEmpty, 'At least one session is required.'),
      assert(
        sessions.map((session) => session.id).toSet().length == sessions.length,
        'Session ids must be unique.',
      ),
      assert(
        sessions.every(
          (session) =>
              session.navigator == FoldableNavigatorKind.stack ||
              session.config.roots.isNotEmpty,
        ),
        'A split session needs at least one root route in its config. Only a '
        'stack session may start with no roots.',
      ) {
    _derivedId = _resolveActiveId();
    _activeId = _derivedId;
  }

  /// Every session of the app.
  final List<FoldableSession> sessions;

  /// The id of the session that should be on screen right now. Read again on
  /// every [refresh].
  final String Function() sessionOf;

  final _routers = <String, FoldableRouter>{};
  final _observers = <FoldableRouterObserver>[];
  late String _activeId;

  /// What [sessionOf] named at the last [refresh]. A session picked by
  /// [replaceSession] stays until this changes.
  late String _derivedId;

  String _resolveActiveId() {
    final id = sessionOf();
    if (!sessions.any((session) => session.id == id)) {
      throw StateError('No FoldableSession with id "$id".');
    }
    return id;
  }

  FoldableSession _sessionById(String id) {
    return sessions.firstWhere((session) => session.id == id);
  }

  /// The session on screen.
  FoldableSession get activeSession => _sessionById(_activeId);

  /// The id of the session on screen.
  String get activeSessionId => _activeId;

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
              config: session.config,
              allowEmptyRoots: session.navigator == FoldableNavigatorKind.stack,
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
    final router = active;
    final session = activeSession;
    return KeyedSubtree(
      key: ObjectKey(router),
      child: Builder(
        builder: (context) {
          FoldableNavigator navigator(FoldableNavigatorBuilder builder) {
            return switch (session.navigator) {
              FoldableNavigatorKind.split => FoldableNavigator(
                controller: router.controller,
                builder: builder,
              ),
              FoldableNavigatorKind.stack => FoldableNavigator.stack(
                controller: router.controller,
              ),
            };
          }

          final shell = session.shell;
          return shell?.call(context, router.controller, navigator) ??
              navigator(
                (context, body, secondaryBody) => secondaryBody ?? body,
              );
        },
      ),
    );
  }

  /// Call when the state read by [sessionOf] changed. Switches to the session
  /// it names, if that is not the one on screen.
  ///
  /// A session chosen with [replaceSession] stays on screen until [sessionOf]
  /// names a different one than it did at the previous refresh.
  void refresh() {
    final id = _resolveActiveId();
    if (id == _derivedId) return;
    _derivedId = id;
    _switchTo(id);
  }

  /// Puts session [id] on screen in place of the current one, whatever
  /// [sessionOf] says, and optionally shows [route] in it.
  ///
  /// Use it for a hand-off the app state does not describe (yet), like the
  /// last step of an onboarding. The choice holds until the state [sessionOf]
  /// reads leads to another session than the one it names now.
  ///
  /// [route] is shown with [FoldableRouter.go], so its redirects run and
  /// they apply to the new session.
  void replaceSession(String id, {FoldableRoute? route}) {
    _sessionById(id);
    _derivedId = _resolveActiveId();
    _switchTo(id);
    if (route != null) active.go(null, route);
  }

  void _switchTo(String id) {
    if (id == _activeId) return;
    final left = _activeId;
    _activeId = id;
    if (_sessionById(left).disposeOnLeave) _discard(left);
    notifyListeners();
  }

  /// The id of a session that claims [uri] when the one on screen does not,
  /// else null.
  String? _sessionClaiming(Uri uri) {
    if (active.config.matcher(uri) != null) return null;
    for (final session in sessions) {
      if (session.id == _activeId || !session.deepLinkable) continue;
      if (session.config.matcher(uri) != null) return session.id;
    }
    return null;
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
  void go(BuildContext? context, FoldableRoute route) =>
      active.go(context, route);

  /// See [FoldableRouter.goLocation].
  ///
  /// A location only another [FoldableSession.deepLinkable] session knows
  /// switches to that session first.
  void goLocation(String location) {
    _switchToClaiming(Uri.parse(location));
    active.goLocation(location);
  }

  /// See [FoldableRouter.push].
  Future<T?> push<T extends Object?>(FoldableRoute route) =>
      active.push<T>(route);

  /// See [FoldableRouter.pushLocation].
  Future<void> pushLocation(String location) {
    _switchToClaiming(Uri.parse(location));
    return active.pushLocation(location);
  }

  /// See [FoldableRouter.pop].
  bool pop([Object? result]) => active.pop(result);

  /// See [FoldableRouter.back].
  void back([FoldableRoute? fallback]) => active.back(fallback);

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
  Uri get currentUri => active.currentUri;

  ///
  /// A URL only another [FoldableSession.deepLinkable] session knows switches
  /// to that session first.
  @override
  void goUri(Uri uri) {
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
  Map<String, Object?> saveState() => {
    _sessionKey: _activeId,
    _routerKey: active.saveState(),
  };

  /// Restores the stacks of the session on screen, if the snapshot is of that
  /// session.
  ///
  /// [sessionOf] decides which session is on screen, restored or not: when the
  /// snapshot was saved for another session (the user signed out in the
  /// meantime, for example), it is ignored. See [FoldableRouter.restoreState]
  /// for the rest.
  @override
  void restoreState(Map<String, Object?> state) {
    final id = state[_sessionKey];
    final saved = state[_routerKey];
    if (id != _activeId || saved is! Map<Object?, Object?>) return;
    if (saved.keys.any((key) => key is! String)) return;
    active.restoreState(saved.cast<String, Object?>());
  }

  static const _sessionKey = 'session';
  static const _routerKey = 'router';

  @override
  bool get backGoesToRoot => active.backGoesToRoot;

  @override
  void goBackToRoot() => active.goBackToRoot();

  @override
  void dispose() {
    for (final router in _routers.values) {
      router
        ..removeListener(notifyListeners)
        ..dispose();
    }
    _routers.clear();
    super.dispose();
  }
}
