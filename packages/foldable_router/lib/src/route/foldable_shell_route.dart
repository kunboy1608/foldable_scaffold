import 'package:material_ui/material_ui.dart';

import '../foldable_navigator_controller.dart';
import 'foldable_route.dart';
import 'foldable_route_base.dart';

/// Builds the shell around the two panes of a [FoldableShellRoute].
///
/// [controller] drives the page stacks of the branches; [body] and
/// [secondaryBody] are the two panes, the same ones a `FoldableNavigator`
/// builder gets.
///
/// ```dart
/// builder: (context, controller, body, secondaryBody) => FoldableScaffold(
///   bodyBuilder: (_, _) => body,
///   secondaryBodyBuilder: (_, _) => secondaryBody,
///   hasSecondaryBody: secondaryBody != null,
/// ),
/// ```
typedef FoldableShellBuilder =
    Widget Function(
      BuildContext context,
      FoldableNavigatorController controller,
      Widget body,
      Widget? secondaryBody,
    );

/// A route-tree node that groups the root of every branch (tab) and draws them
/// inside a shell, like go_router's `ShellRoute`, while keeping the split
/// two-pane behavior of `FoldableSplitNavigator`.
///
/// [branches] are the roots of the tabs, in order, and [builder] wraps the two
/// panes in a scaffold. The second-to-top page of the current branch is shown
/// in the body and the top page in the secondary body, exactly like a
/// `FoldableNavigator`.
///
/// ```dart
/// FoldableRouter(
///   routes: [
///     FoldableShellRoute(
///       branches: const [HomeRoute(), InboxRoute(), SettingsRoute()],
///       builder: (context, controller, body, secondaryBody) => FoldableScaffold(
///         bodyBuilder: (_, _) => body,
///         secondaryBodyBuilder: (_, _) => secondaryBody,
///         hasSecondaryBody: secondaryBody != null,
///       ),
///     ),
///   ],
/// );
/// ```
///
/// Use a [BranchRoute] for the roots, so their pages never show a back
/// button.
///
/// A router may hold several shells (e.g. a main and a statistics one) as
/// top-level routes: exactly one is shown at a time and their branch stacks are
/// kept independently, see `FoldableRouter.showShell`. A branch root may
/// declare nested [FoldableRoute.routes], so a deep link to a nested page
/// rebuilds the whole stack of that branch.
class FoldableShellRoute extends FoldableRouteBase {
  const FoldableShellRoute({required this.branches, required this.builder})
    : assert(branches.length > 0, 'A shell route needs at least one branch.');

  /// The root route of every branch (tab), in order.
  ///
  /// The position in [branches] is the branch index, and the URL of a root is
  /// the URL of its branch.
  final List<FoldableRoute> branches;

  /// Builds the shell around the two panes.
  final FoldableShellBuilder builder;
}
