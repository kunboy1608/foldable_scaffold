import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';

import 'pages/account_pages.dart';
import 'pages/home_page.dart';
import 'pages/misc_pages.dart';
import 'pages/shell_page.dart';
import 'pages/users_pages.dart';
import 'session.dart';

/// The shell: a bottom [NavigationBar] around three branches. Home, Users
/// and Profile are the roots of the branches; routes whose parent chain runs
/// through one of them (UserRoute, SettingsRoute) are shown inside that tab.
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
      MainShell(shell: shell);

  // The Users tab (branch 1) shows two panes when the tab is at least 840
  // wide: the list on the left, the opened user on the right. Other tabs,
  // and narrow windows, keep the classic one-pane stack.
  @override
  Widget? buildPanes(BuildContext context, FoldablePanes panes) {
    if (panes.branchIndex != 1) return null;
    if (panes.constraints.maxWidth < 840) return null;
    return Row(
      children: [
        Expanded(flex: 2, child: panes.primary),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: panes.hasSecondary
              ? panes.secondary
              : const Center(
                  key: Key('no-user-selected'),
                  child: Text('Chọn một người dùng'),
                ),
        ),
      ],
    );
  }
}

class HomeRoute extends FoldableShellChildRoute {
  const HomeRoute();

  @override
  String get segment => '';

  @override
  FoldableShellParent get parent => const MainShellRoute();

  // Slow on first launch only: this is what makes `pendingBuilder` visible.
  // It runs again when the shell re-checks the Home branch (goBranch,
  // refresh) but `session.restore` only waits the first time.
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

  // Constructor fields travel in the query string: /users/detail?id=7
  @override
  Map<String, Object?> get params => {'id': id};

  // `open(UserRoute(...))` builds the stack [UsersRoute, UserRoute].
  @override
  FoldableShellParent get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => UserPage(id: id);
}

class LoginRoute extends FoldableFlatRoute {
  const LoginRoute({this.from});

  /// The location the user wanted, e.g. `/profile/settings`.
  final String? from;

  @override
  String get segment => 'login';

  @override
  Map<String, Object?> get params => {'from': from};

  @override
  Widget build(BuildContext context) => LoginPage(from: from);
}

class ProfileRoute extends FoldableShellChildRoute {
  const ProfileRoute();

  @override
  String get segment => 'profile';

  @override
  FoldableShellParent get parent => const MainShellRoute();

  // The auth guard. Redirects run from the root ancestor down, so this also
  // protects every route that has ProfileRoute in its parent chain.
  // `state.target` is where the navigation is heading (this route or a
  // descendant); we hand it to the login page so it can send the user back.
  // LoginRoute is outside this chain, so the guard cannot loop.
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

  // No redirect of its own: the parent's guard covers it.
  @override
  FoldableShellParent get parent => const ProfileRoute();

  @override
  Widget build(BuildContext context) => const SettingsPage();
}

class ColorPickerRoute extends FoldableFlatRoute {
  const ColorPickerRoute();

  @override
  String get segment => 'pick-color';

  @override
  Widget build(BuildContext context) => const ColorPickerPage();
}

/// URL path -> route. Used by the router for deep links and the web address
/// bar, and by `router.routeFor(uri)`. A factory that throws (missing `id`)
/// leads to the not-found page. The `initial` route (the shell, whose URL is
/// `/`) needs no entry. The shell itself has no path: opening one of these
/// routes builds the shell around the branch the route belongs to.
final Map<String, FoldableRouteFactory> routeTable = {
  '/users': (params) => const UsersRoute(),
  // Typed getters: missing or malformed values throw, which shows the
  // not-found page. `params['id']!` would still work (raw string).
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
  // Shown on first launch while the first redirect is pending.
  pendingBuilder: (context) => const SplashPage(),
);
