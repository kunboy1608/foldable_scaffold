import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

import 'pages/account_pages.dart';
import 'pages/home_page.dart';
import 'pages/misc_pages.dart';
import 'pages/users_pages.dart';
import 'session.dart';

final _tabLabels = <String>['Home', 'Users', 'Profile'];

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
    );
  }
}

/// The shell keeps the three branch stacks alive while `FoldableScaffold`
/// supplies the app bar, navigation chrome, fold handling and pane layout.
class MainShellRoute extends FoldableShellRoute {
  const MainShellRoute();

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
    final bool isUsers = panes.branchIndex == 1;
    if (!isUsers || panes.constraints.maxWidth < 840) return null;

    return FoldableScaffold(
      breakpoints: const FoldableBreakpoints(split: 840),
      followFold: true,
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
            groupAlignment: 0,
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
      secondaryBody: panes.hasSecondary
          ? panes.secondary
          : const Center(
              key: Key('no-user-selected'),
              child: Text('Chọn một người dùng'),
            ),
    );
  }
}

class HomeRoute extends FoldableShellChildRoute {
  const HomeRoute();

  @override
  String get segment => '';

  @override
  FoldableShellParent get parent => const MainShellRoute();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    await session.restore();
    return null;
  }

  @override
  Widget build(BuildContext context) => const HomePage();
}

class UsersRoute extends FoldableShellChildRoute {
  const UsersRoute();

  @override
  String get segment => 'users';

  @override
  FoldableShellParent get parent => const MainShellRoute();

  @override
  Widget build(BuildContext context) => const UsersPage();
}

class UserRoute extends FoldableShellChildRoute {
  const UserRoute({required this.id});

  final String id;

  @override
  String get segment => 'detail';

  @override
  Map<String, Object?> get params => {'id': id};

  @override
  FoldableShellParent get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => UserPage(id: id);
}

class ProfileRoute extends FoldableShellChildRoute {
  const ProfileRoute();

  @override
  String get segment => 'profile';

  @override
  FoldableShellParent get parent => const MainShellRoute();

  @override
  FutureOr<FoldableRoute?> redirect(
    BuildContext context,
    RouteState state,
  ) async {
    if (await session.check()) return null;
    return LoginRoute(from: state.target.uri.toString());
  }

  @override
  Widget build(BuildContext context) => const ProfilePage();
}

class SettingsRoute extends FoldableShellChildRoute {
  const SettingsRoute();

  @override
  String get segment => 'settings';

  @override
  FoldableShellParent get parent => const ProfileRoute();

  @override
  Widget build(BuildContext context) => const SettingsPage();
}

class LoginRoute extends FoldableFlatRoute {
  const LoginRoute({this.from});

  final String? from;

  @override
  String get segment => 'login';

  @override
  Map<String, Object?> get params => {'from': from};

  @override
  Widget build(BuildContext context) => LoginPage(from: from);
}

class ColorPickerRoute extends FoldableFlatRoute {
  const ColorPickerRoute();

  @override
  String get segment => 'pick-color';

  @override
  Widget build(BuildContext context) => const ColorPickerPage();
}

final Map<String, FoldableRouteFactory> routeTable = {
  '/users': (params) => const UsersRoute(),
  '/users/detail': (params) => UserRoute(id: params.getString('id')),
  '/login': (params) => LoginRoute(from: params.getStringOrNull('from')),
  '/profile': (params) => const ProfileRoute(),
  '/profile/settings': (params) => const SettingsRoute(),
  '/pick-color': (params) => const ColorPickerRoute(),
};

FoldableRouter createRouter() => FoldableRouter(
  initial: const MainShellRoute(),
  routes: routeTable,
  notFoundBuilder: (context, uri) => NotFoundPage(uri: uri),
  pendingBuilder: (context) => const SplashPage(),
);
