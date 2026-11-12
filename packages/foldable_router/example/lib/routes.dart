import 'dart:async';

import 'package:flutter/material.dart';
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
  List<FoldableRoute> get branches => const [
    HomeRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      MainShell(shell: shell);
}

class HomeRoute extends FoldableRoute {
  const HomeRoute();

  @override
  String get path => '/';

  @override
  FoldableRoute? get parent => const MainShellRoute();

  // Slow on first launch only: this is what makes `pendingBuilder` visible.
  // It runs again when the shell re-checks the Home branch (goBranch,
  // refresh) but `session.restore` only waits the first time.
  @override
  FutureOr<FoldableRoute?> redirect(RouteState state) async {
    await session.restore();
    return null;
  }

  @override
  Widget build(BuildContext context) => const HomePage();
}

class UsersRoute extends FoldableRoute {
  const UsersRoute();

  @override
  String get path => '/users';

  @override
  FoldableRoute? get parent => const MainShellRoute();

  @override
  Widget build(BuildContext context) => const UsersPage();
}

class UserRoute extends FoldableRoute {
  const UserRoute({required this.id});

  final String id;

  @override
  String get path => '/users/detail';

  // Constructor fields travel in the query string: /users/detail?id=7
  @override
  Map<String, String?> get params => {'id': id};

  // `open(UserRoute(...))` builds the stack [UsersRoute, UserRoute].
  @override
  FoldableRoute? get parent => const UsersRoute();

  @override
  Widget build(BuildContext context) => UserPage(id: id);
}

class LoginRoute extends FoldableRoute {
  const LoginRoute({this.from});

  /// The location the user wanted, e.g. `/profile/settings`.
  final String? from;

  @override
  String get path => '/login';

  @override
  Map<String, String?> get params => {'from': from};

  @override
  Widget build(BuildContext context) => LoginPage(from: from);
}

class ProfileRoute extends FoldableRoute {
  const ProfileRoute();

  @override
  String get path => '/profile';

  @override
  FoldableRoute? get parent => const MainShellRoute();

  // The auth guard. Redirects run from the root ancestor down, so this also
  // protects every route that has ProfileRoute in its parent chain.
  // `state.target` is where the navigation is heading (this route or a
  // descendant); we hand it to the login page so it can send the user back.
  // LoginRoute is outside this chain, so the guard cannot loop.
  @override
  FutureOr<FoldableRoute?> redirect(RouteState state) async {
    if (await session.check()) return null;
    return LoginRoute(from: state.target.uri.toString());
  }

  @override
  Widget build(BuildContext context) => const ProfilePage();
}

class SettingsRoute extends FoldableRoute {
  const SettingsRoute();

  @override
  String get path => '/profile/settings';

  // No redirect of its own: the parent's guard covers it.
  @override
  FoldableRoute? get parent => const ProfileRoute();

  @override
  Widget build(BuildContext context) => const SettingsPage();
}

class ColorPickerRoute extends FoldableRoute {
  const ColorPickerRoute();

  @override
  String get path => '/pick-color';

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
  '/users/detail': (params) => UserRoute(id: params['id']!),
  '/login': (params) => LoginRoute(from: params['from']),
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
