import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_router.dart';
import 'foldable_router_config.dart';

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
///
/// ## State restoration
///
/// Give the delegate a [restorationId] and the app a `restorationScopeId` to
/// get the page stacks back after the system killed the app:
///
/// ```dart
/// MaterialApp.router(
///   restorationScopeId: 'app',
///   routerDelegate: FoldableRouterDelegate(
///     router: appRouter,
///     navigatorKey: rootNavigatorKey,
///     builder: (context) => MyShell(),
///     restorationId: 'foldable_router',
///   ),
///   ...
/// )
/// ```
///
/// Without it (the default) only the URL on top is restored, through the
/// platform, and the app starts with that single page. See
/// [FoldableRouter.saveState] for what is saved and its limits.
class FoldableRouterDelegate extends RouterDelegate<Uri>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Uri> {
  FoldableRouterDelegate({
    required this.router,
    this.config,
    required this.navigatorKey,
    required this.builder,
    this.observers = const <NavigatorObserver>[],
    this.restorationId,
  }) {
    if (config != null) router.attachConfig(config!);
    router.addListener(_onRouterChanged);
    // Redirects started from code run against the navigator's context.
    router.rootContextOf = () => navigatorKey.currentContext;
  }

  /// The router this delegate drives.
  final FoldableRouterBase router;

  /// What the routers of the app share: the URL matcher, `notFound`,
  /// redirects, back target and observers. Handed to [router], which passes it
  /// on to all its sessions. Null when the router was given one itself.
  final FoldableRouterConfig? config;

  /// Builds the app shell (usually the widget with the [Navigator] pages of
  /// [FoldableRouter.controller]). Called again on every navigation.
  final WidgetBuilder builder;

  /// Observers of the root [Navigator], for dialogs and route events.
  final List<NavigatorObserver> observers;

  /// Saves the page stacks of [router] under this id, and restores them when
  /// the app starts again after the system ended it. Null (the default) turns
  /// it off.
  ///
  /// It needs a restoration scope above the router: set
  /// `MaterialApp.restorationScopeId` (or add a `RootRestorationScope`). The
  /// delegate builds a `RestorationScope` with this id around the navigator,
  /// and it must be unique among its siblings.
  ///
  /// What is saved is [FoldableRouterBase.saveState]. The restored stacks are
  /// put back before the first frame, without redirects and without telling
  /// the router's observers. The route the platform reports at startup (the
  /// URL on top, restored by `MaterialApp.router` itself) is applied after
  /// that, and changes nothing when it is the page already on top.
  ///
  /// Per-page state, such as a scroll position, is not covered here: give the
  /// widgets inside the pages their own `restorationId`.
  final String? restorationId;

  bool _restorationSettled = false;
  bool _restoring = false;
  bool _disposed = false;
  Uri? _pendingRoute;

  void _onRouterChanged() {
    // The restore runs while the framework builds: telling the Router then
    // would ask it to rebuild during that same build.
    if (!_restoring) notifyListeners();
  }

  @override
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Uri get currentConfiguration => router.currentUri;

  @override
  Future<void> setNewRoutePath(Uri configuration) {
    if (restorationId != null && !_restorationSettled) {
      // The platform reports the startup route before the saved stacks are
      // back (the Router handles it first). Navigating now would wipe the
      // stacks that are about to return: wait for them.
      _pendingRoute = configuration;
    } else {
      router.goUri(configuration);
    }
    return SynchronousFuture(null);
  }

  @override
  Widget build(BuildContext context) {
    final id = restorationId;
    if (id == null) return _buildNavigator(context);
    return _RestorationHost(
      delegate: this,
      restorationId: id,
      builder: _buildNavigator,
    );
  }

  Widget _buildNavigator(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      observers: observers,
      pages: [
        MaterialPage<void>(
          child: PopScope(
            canPop: !router.backGoesToRoot,
            onPopInvokedWithResult: (didPop, _) => onPopInvoked(didPop),
            child: FoldableRouterScope(
              router: router,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }

  /// Puts back the saved stacks, then lets the startup route through.
  ///
  /// [silent] keeps the Router from being told, for a restore that happens
  /// while the framework builds, right before the navigator does.
  void _restore(Map<String, Object?> saved, {required bool silent}) {
    _restoring = silent;
    try {
      router.restoreState(saved);
    } finally {
      _restoring = false;
    }
  }

  /// Called once the restoration host knows whether there is anything to
  /// restore: from now on the platform's routes apply right away.
  void _settleRestoration() {
    _restorationSettled = true;
    final route = _pendingRoute;
    _pendingRoute = null;
    if (route == null) return;
    // After the frame the router can run redirects with a live context, and
    // nothing changes when [route] is the page the restore left on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) router.goUri(route);
    });
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
    _disposed = true;
    router.removeListener(_onRouterChanged);
    router.rootContextOf = null;
    super.dispose();
  }
}

/// Keeps the snapshot of the router in the restoration data and puts it back.
class _RestorationHost extends StatefulWidget {
  const _RestorationHost({
    required this.delegate,
    required this.restorationId,
    required this.builder,
  });

  final FoldableRouterDelegate delegate;
  final String restorationId;
  final WidgetBuilder builder;

  @override
  State<_RestorationHost> createState() => _RestorationHostState();
}

class _RestorationHostState extends State<_RestorationHost>
    with RestorationMixin {
  final _snapshot = _RestorableSnapshot();
  String? _saved;
  bool _registered = false;

  @override
  String? get restorationId => widget.restorationId;

  @override
  void initState() {
    super.initState();
    widget.delegate.router.addListener(_save);
  }

  @override
  void didUpdateWidget(_RestorationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delegate.router != widget.delegate.router) {
      oldWidget.delegate.router.removeListener(_save);
      widget.delegate.router.addListener(_save);
    }
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_snapshot, 'router');
    _registered = true;
    final delegate = widget.delegate;
    final saved = _snapshot.value;
    if (saved != null && initialRestore) {
      // Nothing is mounted below yet: the stacks are right for the first frame.
      delegate._restore(saved, silent: true);
    } else if (saved != null) {
      // The data arrived late, with the navigator on screen: restore between
      // frames, not in the middle of the build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        delegate._restore(saved, silent: false);
        _save();
      });
    }
    delegate._settleRestoration();
    if (saved == null || initialRestore) _save();
  }

  void _save() {
    if (!_registered) return;
    final state = widget.delegate.router.saveState();
    // Equal snapshots are not written again.
    final encoded = state == null ? null : jsonEncode(state);
    if (encoded == _saved) return;
    _saved = encoded;
    _snapshot.value = state;
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);

  @override
  void dispose() {
    widget.delegate.router.removeListener(_save);
    _snapshot.dispose();
    super.dispose();
  }
}

/// The router snapshot as a restorable value: a plain map of lists and strings.
class _RestorableSnapshot extends RestorableValue<Map<String, Object?>?> {
  @override
  Map<String, Object?>? createDefaultValue() => null;

  @override
  void didUpdateValue(Map<String, Object?>? oldValue) => notifyListeners();

  @override
  Map<String, Object?>? fromPrimitives(Object? data) {
    if (data is! Map<Object?, Object?>) return null;
    if (data.keys.any((key) => key is! String)) return null;
    return data.cast<String, Object?>();
  }

  @override
  Object? toPrimitives() => value;
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
