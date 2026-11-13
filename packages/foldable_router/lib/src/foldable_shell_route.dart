import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'foldable_panes.dart';
import 'foldable_route.dart';

/// Everything a shell needs to draw its frame around the current branch.
///
/// A [FoldableShellRoute.buildShell] typically puts [child] in the body of a
/// `Scaffold` and drives a `NavigationBar` (or a rail) from [currentIndex]
/// and [goBranch].
@immutable
class FoldableShellState {
  /// Creates a shell state. Only the router builds instances of this class.
  const FoldableShellState({
    required this.child,
    required this.currentIndex,
    required this.goBranch,
  });

  /// The area where the pages of the current branch are shown.
  ///
  /// Only the current branch is visible; the other branches stay in the
  /// tree (and keep their state and their navigator) but are offstage.
  final Widget child;

  /// Index, in [FoldableShellRoute.branches], of the branch currently shown.
  final int currentIndex;

  /// Switches to the branch at [index], keeping its stack.
  ///
  /// A branch is built lazily: the first visit runs its redirects (and the
  /// redirects of the ancestors of the branch root) and opens the branch
  /// root. Later visits keep the stack of the branch but still re-check its
  /// redirects. Like any navigation, a switch that is still pending can be
  /// superseded by a newer one, and [FoldableRouter.isNavigating] is `true`
  /// while its redirects run.
  final Future<void> Function(int index) goBranch;
}

/// A route that shows a persistent frame (bottom navigation, side rail, ...)
/// around the routes of its [branches], each with its own stack.
///
/// A shell sits in the middle of a parent chain: a route whose
/// [FoldableRoute.parent] chain contains the shell is shown *inside* it. The
/// shell is one page of the root navigator, and every branch gets a nested
/// navigator, so each branch keeps its own stack (and the state of its
/// pages) while the user switches between branches:
///
/// ```dart
/// class MainShellRoute extends FoldableShellRoute {
///   const MainShellRoute();
///
///   @override
///   List<FoldableRoute> get branches => const [HomeRoute(), UsersRoute()];
///
///   @override
///   Widget buildShell(BuildContext context, FoldableShellState shell) =>
///       Scaffold(
///         body: shell.child,
///         bottomNavigationBar: NavigationBar(
///           selectedIndex: shell.currentIndex,
///           onDestinationSelected: shell.goBranch,
///           destinations: const [
///             NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
///             NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
///           ],
///         ),
///       );
/// }
///
/// class UsersRoute extends FoldableRoute {
///   const UsersRoute();
///
///   @override
///   String get path => '/users';
///
///   // The element right below the shell decides the branch.
///   @override
///   FoldableRoute? get parent => const MainShellRoute();
///
///   @override
///   Widget build(BuildContext context) => const UsersPage();
/// }
/// ```
///
/// Rules:
///
/// * A route belongs to the branch whose root, in [branches], is equal to
///   the element right below the shell in its parent chain. A chain that
///   reaches the shell without passing through one of [branches] is an
///   error.
/// * The shell has no path and never appears in the URL: the location is
///   the one of the top page of the current branch (or of the topmost
///   full-screen page above the shell). [path] is the empty string and the
///   shell needs no entry in the router's `routes` table.
/// * [buildShell] draws the frame; [build] is never called by the router.
/// * [redirect] runs before the redirects of the branch routes, as for any
///   ancestor. Like every redirect it receives the [BuildContext] of the
///   `Router` widget (not of a page); the same context is used for the
///   re-check when the user switches tabs with
///   [FoldableShellState.goBranch].
/// * Opening a route whose parent chain contains the shell replaces the
///   stack of *its* branch (keeping the unchanged bottom, as usual) and
///   switches to it; other branches keep their stacks. Opening the shell
///   itself opens its first branch.
/// * Pushing such a route is not supported and throws an
///   [UnsupportedError]: use `FoldableRouter.open`. Pushing a route
///   *outside* the shell shows a full-screen page above it, as usual.
/// * Back (and `FoldableRouter.pop`) leaves a full-screen page above the
///   shell first, then goes one page back inside the current branch, and
///   does nothing at the branch root (the system then leaves the app).
/// * Only one shell may appear in a parent chain.
///
/// Two shells are equal when they have the same runtime type and equal
/// [branches]. As long as the router navigates within a shell, its branches
/// (and so the state of their pages) survive.
abstract class FoldableShellRoute extends FoldableRoute {
  /// Const constructor for subclasses.
  const FoldableShellRoute();

  /// The root route of each branch, in the order shown by the shell.
  List<FoldableRoute> get branches;

  /// Builds the frame around the current branch.
  ///
  /// Put [FoldableShellState.child] somewhere in the returned widget tree;
  /// it shows the pages of the current branch.
  Widget buildShell(BuildContext context, FoldableShellState shell);

  /// The shell has no path: it never appears in a URL.
  @override
  String get path => '';

  /// Never called: a shell is drawn through [buildShell].
  @override
  Widget build(BuildContext context) => throw UnsupportedError(
    '$runtimeType is a FoldableShellRoute: it is shown through buildShell, '
    'not build.',
  );

  /// Builds how the pages of one tab are shown when the app wants two panes.
  ///
  /// Return `null` (the default) to keep the classic one-pane behavior: only
  /// the top page of the tab is visible, filling the whole area of the tab.
  ///
  /// Return a widget to show two panes. The widget is placed *below* the
  /// navigators of the branches and receives a [FoldablePanes] whose
  /// [primary] frame (and [secondary] frame, when the stack of the tab has
  /// at least two pages) the app must place inside its layout. The frames
  /// take room and mark the rectangles the pages are drawn in; the pages
  /// themselves keep their own navigator and only change place. If the app
  /// never places [primary], or never places [secondary] while
  /// [hasSecondary] is `true`, the router reports a [FlutterError] in debug
  /// builds.
  ///
  /// Called once per tab, inside the area of that tab, and re-run when the
  /// tab area rebuilds (a [MediaQuery] or size change, or a different layout
  /// returned by this method). The returned layout may not rely on page
  /// state: pages stay mounted while they only change pane.
  Widget? buildPanes(BuildContext context, FoldablePanes panes) => null;

  @override
  bool operator ==(Object other) =>
      other is FoldableShellRoute &&
      other.runtimeType == runtimeType &&
      listEquals(other.branches, branches);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(branches));
}
