import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Counts the page transitions in flight, so several overlapping animations do
/// not make the signal flicker to false in between.
///
/// One instance is shared by all branches of one shell. The router calls
/// [begin] when a push or pop transition starts and [end] when it completes.
/// Calls that arrive after the instance is disposed are ignored.
///
/// Provider: `foldable_router` (one instance per shell page).
/// Consumer: `FoldableScaffold`, which switches the visible pane instantly
/// instead of animating the pane resize on top of the slide.
/// When there is no provider: `FoldableScaffold` falls back to
/// `widget.paneTransition` if given, otherwise animates normally — no crash,
/// only a possible "jerk" on push, acceptable when an app only uses the
/// scaffold.
class FoldablePaneTransitions extends ChangeNotifier
    implements ValueListenable<bool> {
  int _count = 0;
  bool _disposed = false;

  /// Whether at least one page transition is running.
  @override
  bool get value => _count > 0;

  /// Marks one transition as started.
  ///
  /// Does nothing once the notifier is disposed: a route can start or finish a
  /// transition after the shell that owns the signal is gone.
  void begin() {
    if (_disposed) return;
    _count++;
    if (_count == 1) notifyListeners();
  }

  /// Marks one transition as finished.
  ///
  /// Does nothing once the notifier is disposed, so a transition that is
  /// cancelled while its shell is retired does not assert and the count never
  /// goes negative.
  void end() {
    if (_disposed) return;
    if (_count > 0) {
      _count--;
      if (_count == 0) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Whether pages are sliding right now, so `FoldableScaffold` switches the
/// visible pane instantly instead of animating the pane resize on top of the
/// slide.
///
/// Provided by `foldable_router` around the page of a shell (the
/// `FoldableShellRoute.buildShell` subtree), read by `FoldableScaffold`.
/// `FoldableScaffold.paneTransition` overrides it.
///
/// Provider: `foldable_router` (one scope per shell page).
/// Consumer: `FoldableScaffold` (`_isTransitioning`).
/// When there is no provider: scaffold animates like before.
class FoldablePaneTransitionScope
    extends InheritedNotifier<ValueListenable<bool>> {
  const FoldablePaneTransitionScope({
    required ValueListenable<bool> transitions,
    super.key,
    required super.child,
  }) : super(notifier: transitions);

  /// The closest transition signal, subscribing [context].
  static ValueListenable<bool>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FoldablePaneTransitionScope>()
      ?.notifier;

  /// The closest transition signal, without subscribing [context]
  /// (safe in `initState`, callbacks).
  static ValueListenable<bool>? read(BuildContext context) => context
      .getInheritedWidgetOfExactType<FoldablePaneTransitionScope>()
      ?.notifier;

  /// Whether a transition is running in the closest scope; `false` when there
  /// is none. Subscribes [context], so the caller rebuilds when transitions
  /// start and finish.
  static bool isTransitioningOf(BuildContext context) =>
      of(context)?.value ?? false;

  @override
  bool updateShouldNotify(FoldablePaneTransitionScope oldWidget) =>
      super.updateShouldNotify(oldWidget) || notifier != oldWidget.notifier;
}
