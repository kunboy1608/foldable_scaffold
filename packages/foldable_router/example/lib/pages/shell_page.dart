import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

/// The bottom bar of [MainShellRoute]: one tab per branch.
///
/// [FoldableShellState.child] shows the pages of the current branch; the
/// other branches keep their stacks (and their page state) offstage.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final FoldableShellState shell;

  // Widths at or above which the Users tab (branch 1) shows list + detail.
  static const double _splitWidth = 840;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Size size = constraints.biggest;
          // The Users tab (branch 1) shows two panes when it is wide enough:
          // the list on the left, the opened user on the right. Other tabs,
          // and narrow windows, keep the classic one-pane stack.
          final bool split =
              shell.currentIndex == 1 && size.width >= _splitWidth;
          final FoldablePaneRects rects = split
              ? FoldablePaneRects.sideBySide(
                  size,
                  secondaryFraction: 0.6,
                  dividerExtent: 1,
                )
              : FoldablePaneRects(
                  primary: Offset.zero & size,
                  secondary: null,
                  axis: Axis.horizontal,
                );
          return FoldablePaneRectsScope(
            rects: rects,
            child: Stack(
              fit: StackFit.expand,
              children: [
                shell.child,
                if (split && !shell.hasSecondary)
                  Positioned.fromRect(
                    rect: rects.secondary!,
                    child: const Center(
                      key: Key('no-user-selected'),
                      child: Text('Chọn một người dùng'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline),
            selectedIcon: Icon(Icons.lock),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
