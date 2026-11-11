import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'foldable_route.dart';
import 'foldable_router.dart';
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
  _EntryPage(this.entry)
    : super(
        key: entry.key,
        name: entry.route.uri.toString(),
        child: Builder(builder: entry.route.build),
      );

  final _Entry entry;

  @override
  Route<Object?> createRoute(BuildContext context) {
    final route = super.createRoute(context);
    entry.popped = route.popped;
    return route;
  }
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

/// Owns the page stack and runs navigations for a [FoldableRouter].
class FoldableRouterDelegate extends RouterDelegate<Uri> with ChangeNotifier {
  /// Creates the delegate for [router].
  FoldableRouterDelegate(this.router)
    : _resolver = RedirectResolver(maxRedirects: router.maxRedirects);

  /// The router this delegate works for.
  final FoldableRouter router;

  /// Key of the Navigator showing the stack.
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether a navigation is resolving its redirects.
  final ValueNotifier<bool> isNavigating = ValueNotifier<bool>(false);

  /// Notifies when [stack] or [currentConfiguration] changed. Unlike the
  /// delegate's own listeners (the Router widget), these are not called for
  /// rebuild requests that leave both unchanged.
  final StackNotifier stackChanges = StackNotifier();

  final RedirectResolver _resolver;
  List<_Entry> _stack = const [];
  Uri? _notFound;
  int _nextId = 0;
  bool _disposed = false;

  /// The routes currently on the stack, bottom first.
  List<FoldableRoute> get stack =>
      List.unmodifiable(_stack.map((e) => e.route));

  @override
  Uri? get currentConfiguration =>
      _notFound ?? (_stack.isEmpty ? null : _stack.last.route.uri);

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

  /// Removes the top page unless it is the only one.
  void pop<T extends Object?>([T? result]) {
    if (_stack.length <= 1) return;
    final entry = _stack.last;
    _stack = _stack.sublist(0, _stack.length - 1);
    entry.complete(result);
    _notify();
  }

  /// Tells the Router widget to rebuild and, when [stackChanged], the
  /// listeners of the [FoldableRouter].
  void _notify({bool stackChanged = true}) {
    notifyListeners();
    if (stackChanged) stackChanges.notify();
  }

  /// Re-runs the redirects of the routes on the stack, bottom to top.
  Future<void> refresh() async {
    if (_stack.isEmpty) return;
    final token = _begin();
    try {
      final routes = stack;
      final redirected = await _resolver.firstRedirect(
        routes,
        target: routes.last,
        token: token,
      );
      if (redirected == null) return;
      final chain = await _resolver.resolve(redirected, token: token);
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

  /// Returns the committed top entry, or null when superseded.
  Future<_Entry?> _navigate(FoldableRoute target, {required bool push}) async {
    if (_disposed) return null;
    final token = _begin();
    try {
      final chain = await _resolver.resolve(target, token: token);
      if (chain == null) return null;
      return push ? _commitPush(chain.last) : _commitOpen(chain);
    } finally {
      _end(token);
    }
  }

  _Entry _commitOpen(List<FoldableRoute> chain) {
    // Keep the entries (and so the page state) of the unchanged bottom part.
    var keep = 0;
    while (keep < chain.length &&
        keep < _stack.length &&
        _stack[keep].route == chain[keep]) {
      keep++;
    }
    final removed = _stack.sublist(keep);
    final changed =
        removed.isNotEmpty || keep < chain.length || _notFound != null;
    _stack = [
      ..._stack.take(keep),
      for (final route in chain.skip(keep)) _Entry(_nextId++, route),
    ];
    _notFound = null;
    for (final entry in removed) {
      entry.complete();
    }
    _notify(stackChanged: changed);
    return _stack.last;
  }

  _Entry _commitPush(FoldableRoute route) {
    final entry = _Entry(_nextId++, route);
    _stack = [..._stack, entry];
    _notFound = null;
    _notify();
    return entry;
  }

  void _showNotFound(Uri uri) {
    final removed = _stack;
    final changed = removed.isNotEmpty || _notFound != uri;
    _stack = const [];
    _notFound = uri;
    for (final entry in removed) {
      entry.complete();
    }
    _notify(stackChanged: changed);
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
      if (_stack.isEmpty && _notFound == null && !_disposed) {
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
    final navigator = navigatorKey.currentState;
    if (navigator == null) return SynchronousFuture<bool>(false);
    return navigator.maybePop();
  }

  void _onDidRemovePage(Page<Object?> page) {
    final index = _stack.indexWhere((e) => e.key == page.key);
    if (index < 0) return; // Already removed by us (pop / open).
    final removable = _stack.length > 1;
    if (removable) {
      final entry = _stack[index];
      _stack = [..._stack]..removeAt(index);
      entry.complete(entry.popped);
    }
    // The last page stays; the Navigator still has to be rebuilt with it.
    _notify(stackChanged: removable);
  }

  @override
  Widget build(BuildContext context) {
    final notFound = _notFound;
    final Widget child;
    if (notFound == null && _stack.isEmpty) {
      child = router.pendingBuilder?.call(context) ?? const SizedBox.shrink();
    } else {
      child = Navigator(
        key: navigatorKey,
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
        onDidRemovePage: _onDidRemovePage,
      );
    }
    return FoldableRouterScope(router: router, child: child);
  }

  @override
  void dispose() {
    _disposed = true;
    _resolver.begin();
    for (final entry in _stack) {
      entry.complete();
    }
    isNavigating.dispose();
    stackChanges.dispose();
    super.dispose();
  }
}
