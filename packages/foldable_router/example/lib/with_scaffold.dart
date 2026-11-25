import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

/// Example that hosts a [FoldableRouter] shell inside a [FoldableScaffold].
///
/// The scaffold supplies the pane layout (breakpoints, divider, animated
/// pane switching) and the router supplies the page stacks, one per branch.
/// Run with: `flutter run lib/with_scaffold.dart`
void main() {
  runApp(const _ExampleApp());
}

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    final router = _MailRouter();
    return MaterialApp.router(
      title: 'foldable_router + foldable_scaffold',
      theme: ThemeData(),
      routerConfig: router.routerConfig,
    );
  }
}

/// A router whose shell is drawn by [MailShellRoute] through a
/// [FoldableScaffold].
class _MailRouter extends FoldableRouter {
  _MailRouter()
    : super(
        initial: const MailShellRoute(),
        routes: <String, FoldableRouteFactory>{
          '/users/detail': (params) => UserRoute(id: params.getString('id')),
          '/profile': (params) => const ProfileRoute(),
          '/profile/settings': (params) => const SettingsRoute(),
        },
        notFoundBuilder: (context, uri) =>
            Scaffold(body: Center(child: Text('No route for $uri'))),
      );
}

/// Creates the router used by [main], so tests can drive it directly.
FoldableRouter createRouter() => _MailRouter();

/// The shell: a [FoldableScaffold] whose navigation is a rail on the side and
/// a bottom bar elsewhere, and whose panes are the router's pages.
class MailShellRoute extends FoldableShellRoute {
  const MailShellRoute();

  @override
  List<FoldableShellChildRoute> get branches => const [
    InboxRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) {
    return FoldableScaffold(
      appBar: AppBar(title: const Text('Mail')),
      // The router places each page in its pane rectangle through paneContent.
      paneContent: (BuildContext context, FoldablePaneRects rects) =>
          shell.child,
      hasSecondaryBody: shell.hasSecondary,
      // The back button / divider close of the secondary pane pops the top
      // page of the current branch.
      onSecondBodyClose: (bool didPop, Object? result) =>
          shell.closeSecondary?.call(),
      // A rail beside the panes on wide layouts, a bottom bar otherwise.
      navigationBuilder:
          (
            BuildContext context,
            FoldableNavigationPlacement placement,
            BoxConstraints constraints,
            EdgeInsets padding,
          ) {
            if (placement.isSide) {
              return NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: shell.goBranch,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final branch in branches)
                    NavigationRailDestination(
                      icon: const Icon(Icons.inbox),
                      label: Text(
                        branch.segment.isEmpty ? 'Inbox' : branch.segment,
                      ),
                    ),
                ],
              );
            }
            return NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: shell.goBranch,
              destinations: [
                for (final branch in branches)
                  NavigationDestination(
                    icon: const Icon(Icons.inbox),
                    label: branch.segment.isEmpty ? 'Inbox' : branch.segment,
                  ),
              ],
            );
          },
    );
  }
}

class InboxRoute extends FoldableShellChildRoute {
  const InboxRoute();

  @override
  String get segment => '';

  @override
  FoldableShellParent get parent => const MailShellRoute();

  @override
  Widget build(BuildContext context) => const InboxPage();
}

class UsersRoute extends FoldableShellChildRoute {
  const UsersRoute();

  @override
  String get segment => 'users';

  @override
  FoldableShellParent get parent => const MailShellRoute();

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
  FoldableShellParent get parent => const MailShellRoute();

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

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: ListView(
        children: const [
          ListTile(title: Text('User 7'), subtitle: Text('Open the detail')),
          ListTile(title: Text('User 42'), subtitle: Text('Open the detail')),
        ],
      ),
    );
  }
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: ListView(
        children: const [
          ListTile(title: Text('User 7'), subtitle: Text('Open the detail')),
          ListTile(title: Text('User 42'), subtitle: Text('Open the detail')),
        ],
      ),
    );
  }
}

class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User $id')),
      body: Center(child: Text('User $id detail')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile')),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(child: Text('Settings')),
    );
  }
}
