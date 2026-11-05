import 'package:material_ui/material_ui.dart';

import 'foldable_route.dart';

/// The root route of a branch (tab) of a `FoldableSessionSplit`.
///
/// ```dart
/// class HomeRoute extends BranchRoute {
///   const HomeRoute();
///
///   @override
///   String get path => '/home';
///
///   @override
///   Widget build(BuildContext context) => const HomeScreen();
/// }
///
/// FoldableSessionSplit(id: 'main', branches: const [HomeRoute(), InboxRoute()]);
/// ```
///
/// The position in `branches` is the index of the branch. A branch root is the
/// bottom page of its branch, so there is nothing to go back to from it: its
/// page never shows a back button. [FoldableBackButton] hides itself in it,
/// and a [FoldableAppBar] in it leaves out its automatic back button, with no
/// empty room where it would be. Set [hideBackButton] to false to keep them.
///
/// A plain `AppBar` cannot tell a branch root from a pushed page (they share
/// one route), so its automatic back icon is only drawn empty and still takes
/// room: use [FoldableAppBar] instead.
abstract class BranchRoute extends FoldableRoute {
  const BranchRoute();

  /// Whether the page of this route never shows a back button.
  bool get hideBackButton => true;

  @override
  Widget buildPage(BuildContext context) {
    final child = build(context);
    return hideBackButton ? FoldableBranchRoot(child: child) : child;
  }
}

/// Marks the subtree of the page of a [BranchRoute] that hides its back button.
class FoldableBranchRoot extends StatelessWidget {
  const FoldableBranchRoot({required this.child, super.key});

  final Widget child;

  /// Whether [context] is inside the page of a [BranchRoute] that hides the
  /// back button. Rebuilds [context] when that changes.
  static bool hidesBackButton(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_BranchRootScope>() !=
        null;
  }

  @override
  Widget build(BuildContext context) {
    return _BranchRootScope(
      child: ActionIconTheme(
        data: ActionIconThemeData(
          // The automatic leading button of an AppBar: no icon.
          backButtonIconBuilder: (_) => const SizedBox.shrink(),
        ),
        child: child,
      ),
    );
  }
}

class _BranchRootScope extends InheritedWidget {
  const _BranchRootScope({required super.child});

  @override
  bool updateShouldNotify(_BranchRootScope oldWidget) => false;
}
