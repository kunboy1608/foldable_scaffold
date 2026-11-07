import 'package:material_ui/material_ui.dart';

/// A node of the route tree a `FoldableRouter` shows.
///
/// There are two kinds:
///
/// * [FoldableRoute], a screen, pushed or opened inside a branch.
/// * `FoldableShellRoute`, a shell that groups the roots of several branches
///   (tabs) and draws them with a scaffold, like go_router's `ShellRoute`.
///
/// A router takes a list of these as its top-level routes. The shell route is
/// the tabbed part of the app; plain routes next to it are shown full screen.
@immutable
abstract class FoldableRouteBase {
  const FoldableRouteBase();
}
