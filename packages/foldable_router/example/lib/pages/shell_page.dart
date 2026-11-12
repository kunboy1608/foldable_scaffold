import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

/// The bottom bar of [MainShellRoute]: one tab per branch.
///
/// [FoldableShellState.child] shows the pages of the current branch; the
/// other branches keep their stacks (and their page state) offstage.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final FoldableShellState shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell.child,
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
