import 'dart:math' as math;

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

// The routes and their pages are shared with `main.dart`; only the shell is
// this app's own (see `appShell`).
import 'routes.dart';

export 'routes.dart' hide createRouter, MainShellRoute;

final _tabLabels = <String>['Home', 'Users', 'Profile'];

/// From this width the Users tab shows the list and the detail side by side.
const double _split = 840;

void main() {
  usePathUrlStrategy();
  runApp(WithScaffoldApp(router: createRouter()));
}

class WithScaffoldApp extends StatelessWidget {
  const WithScaffoldApp({super.key, required this.router});

  final FoldableRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_router + foldable_scaffold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData.dark(useMaterial3: true),
      routerConfig: router.routerConfig,
      // On iOS: the fold and the side where the device wants its vertical bars
      // (iPhone Duo), read by every FoldableScaffold below. Elsewhere it does
      // nothing.
      builder: (context, child) => FoldablePlatformScope(child: child!),
    );
  }
}

/// The shell keeps the three branch stacks alive while `FoldableScaffold`
/// supplies the app bar, navigation chrome, fold handling and pane layout.
class ScaffoldShellRoute extends FoldableShellRoute {
  const ScaffoldShellRoute();

  @override
  List<FoldableShellChildRoute> get branches => const [
    HomeRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Material(child: shell.child);

  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    final shell = panes.shell;
    // Every tab gets the scaffold, so every tab has the navigation. Only Users
    // is a list-detail tab: two panes from 840 (and on a fold). The other tabs
    // never split, so they keep one pane showing the top page of their stack.
    final bool isUsers = panes.branchIndex == 1;
    final bool showEmptyState =
        isUsers && !panes.hasSecondary && panes.constraints.maxWidth >= _split;

    return FoldableScaffold(
      // One scaffold per tab: its pane layout and animations belong to that
      // tab, and are not carried over to the next tab.
      key: ValueKey<int>(panes.branchIndex),
      breakpoints: isUsers
          ? const FoldableBreakpoints(split: _split)
          : const FoldableBreakpoints(split: double.infinity),
      followFold: isUsers,
      appBar: AppBar(
        title: Text(_tabLabels[shell.currentIndex]),
        actions: [
          IconButton(
            tooltip: 'Pick a colour',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () =>
                FoldableRouter.of(context).push(const ColorPickerRoute()),
          ),
        ],
      ),
      navigationBuilder: (context, placement, constraints, padding) {
        final destinations = [
          for (final label in _tabLabels)
            NavigationDestination(
              icon: const Icon(Icons.circle_outlined),
              selectedIcon: const Icon(Icons.circle),
              label: label,
            ),
        ];
        if (placement.isSide) {
          return NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            labelType: NavigationRailLabelType.all,
            // At the bottom of its edge when the platform wants it (iPhone
            // Duo), and never wider than the slot: inside the system strip
            // that is narrower than the rail's 72.
            groupAlignment: switch (placement.alignment) {
              FoldableNavigationAlignment.start => -1.0,
              FoldableNavigationAlignment.center => 0.0,
              FoldableNavigationAlignment.end => 1.0,
            },
            minWidth: math.min(72, constraints.maxWidth),
            destinations: [
              for (final destination in destinations)
                NavigationRailDestination(
                  icon: destination.icon,
                  selectedIcon: destination.selectedIcon,
                  label: Text(destination.label),
                ),
            ],
          );
        }
        return NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: destinations,
        );
      },
      body: panes.primary,
      // The router requires `secondary` to be placed whenever the stack has two
      // pages. With no selection, the right pane of a wide Users tab shows a
      // hint; in one pane it is hidden so the list stays on screen.
      secondaryBody: panes.hasSecondary
          ? panes.secondary
          : showEmptyState
          ? const Center(
              key: Key('no-user-selected'),
              child: Text('Chọn một người dùng'),
            )
          : null,
      hasSecondaryBody: panes.hasSecondary || showEmptyState,
    );
  }
}

/// The router of this app: the shared routes of `routes.dart`, with the tabs
/// in [ScaffoldShellRoute] instead of the bottom bar shell of `main.dart`.
FoldableRouter createRouter() =>
    createExampleRouter(const ScaffoldShellRoute());
