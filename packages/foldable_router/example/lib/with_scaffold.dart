import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

import 'app.dart';
import 'session.dart';

/// Example that hosts a [FoldableRouter] shell inside a [FoldableScaffold].
///
/// The scaffold supplies the pane layout (breakpoints, divider, animated pane
/// switching) and the router supplies the page stacks, one per branch. It has
/// the same features as the main example (`main.dart`): a status bar, an async
/// auth guard, a splash while the first redirect runs, a not-found page, Hero
/// avatars, a push-with-result picker and a two-pane Users tab.
///
/// Run with: `flutter run lib/with_scaffold.dart`
void main() {
  usePathUrlStrategy();
  runApp(const _ExampleApp());
}

final router = _MailRouter();

class _ExampleApp extends StatelessWidget {
  const _ExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_router + foldable_scaffold',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      darkTheme: ThemeData.dark(),
      routerConfig: router.routerConfig,
      // Same frame as the main example: the router's pages on top, the status
      // bar below.
      builder: (context, child) => Column(
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: child!,
            ),
          ),
          StatusBar(router: router),
        ],
      ),
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
          '/users': (params) => const UsersRoute(),
          '/users/detail': (params) => UserRoute(id: params.getString('id')),
          '/login': (params) =>
              LoginRoute(from: params.getStringOrNull('from')),
          '/profile': (params) => const ProfileRoute(),
          '/profile/settings': (params) => const SettingsRoute(),
          '/pick-color': (params) => const ColorPickerRoute(),
        },
        notFoundBuilder: (context, uri) => NotFoundPage(uri: uri),
        // Shown on first launch while the first redirect is pending.
        pendingBuilder: (context) => const SplashPage(),
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
    HomeRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) {
    return FoldableScaffold(
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
                      icon: Icon(_iconFor(branch, selected: false)),
                      selectedIcon: Icon(_iconFor(branch, selected: true)),
                      label: Text(_labelFor(branch)),
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
                    icon: Icon(_iconFor(branch, selected: false)),
                    selectedIcon: Icon(_iconFor(branch, selected: true)),
                    label: _labelFor(branch),
                  ),
              ],
            );
          },
    );
  }
}

String _labelFor(FoldableShellChildRoute branch) => switch (branch.segment) {
  '' => 'Home',
  'users' => 'Users',
  'profile' => 'Profile',
  final other => other,
};

IconData _iconFor(FoldableShellChildRoute branch, {required bool selected}) {
  return switch (branch.segment) {
    '' => selected ? Icons.home : Icons.home_outlined,
    'users' => selected ? Icons.people : Icons.people_outline,
    'profile' => selected ? Icons.person : Icons.person_outline,
    _ => selected ? Icons.circle : Icons.circle_outlined,
  };
}

// ---------------------------------------------------------------------------
// Routes
// ---------------------------------------------------------------------------

class HomeRoute extends FoldableShellChildRoute {
  const HomeRoute();

  @override
  String get segment => '';

  @override
  FoldableShellParent get parent => const MailShellRoute();

  // Slow on first launch only: this is what makes `pendingBuilder` visible.
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
  FoldableShellParent get parent => const MailShellRoute();

  // The auth guard. Redirects run from the root ancestor down, so this also
  // protects every route that has ProfileRoute in its parent chain.
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

// ---------------------------------------------------------------------------
// Pages
// ---------------------------------------------------------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _color;

  Future<void> _pickColor() async {
    // push adds one page and completes with the value given to pop.
    final picked = await FoldableRouter.of(
      context,
    ).push<String>(const ColorPickerRoute());
    if (mounted && picked != null) setState(() => _color = picked);
  }

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: const [_PlatformDataButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section(
              'open',
              'The app runs inside a shell (MailShellRoute) with a rail or a '
                  'tab bar. open replaces the stack with the route and its '
                  'parents; inside the shell it only replaces the stack of the '
                  'branch that route belongs to. Watch the stack below.',
            ),
            FilledButton(
              key: const Key('open-user'),
              onPressed: () => router.open(const UserRoute(id: '7')),
              child: const Text("open(UserRoute(id: '7'))"),
            ),
            OutlinedButton(
              key: const Key('open-users'),
              onPressed: () => router.open(const UsersRoute()),
              child: const Text('open(UsersRoute())'),
            ),
            const _Section(
              'Auth guard',
              'ProfileRoute has an async redirect (800 ms). It also guards '
                  'its child SettingsRoute. This page stays while it runs.',
            ),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    session.loggedIn ? 'Logged in' : 'Logged out',
                    key: const Key('session'),
                  ),
                  if (session.loggedIn)
                    TextButton(
                      key: const Key('logout'),
                      onPressed: () {
                        session.logout();
                        router.refresh();
                      },
                      child: const Text('Log out'),
                    )
                  else
                    TextButton(
                      key: const Key('open-login'),
                      onPressed: () => router.open(const LoginRoute()),
                      child: const Text('open(LoginRoute())'),
                    ),
                ],
              ),
            ),
            FilledButton(
              key: const Key('open-profile'),
              onPressed: () => router.open(const ProfileRoute()),
              child: const Text('open(ProfileRoute())'),
            ),
            OutlinedButton(
              key: const Key('open-settings'),
              onPressed: () => router.open(const SettingsRoute()),
              child: const Text('open(SettingsRoute())'),
            ),
            const _Section(
              'push with result',
              'ColorPickerRoute lives outside the shell: push shows it '
                  'full-screen above the navigation bar and answers with pop.',
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                FilledButton(
                  key: const Key('pick-color'),
                  onPressed: _pickColor,
                  child: const Text('push<String>(ColorPickerRoute())'),
                ),
                Text('Picked: ${_color ?? 'nothing yet'}'),
              ],
            ),
            const _Section(
              'Not found',
              'Every route instance is valid, so the not-found page is only '
                  'reached from a URL: on web, type /nope (or /users/detail '
                  'without ?id=) in the address bar.',
            ),
          ],
        ),
      ),
    );
  }
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  /// The user currently shown in the right pane, if the tab has two panes.
  static String? _selectedUserId(FoldableRouter router, bool twoPane) {
    if (!twoPane) return null;
    for (final route in router.stack.reversed) {
      if (route is UserRoute) return route.id;
      if (route is UsersRoute) break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    final bool twoPane =
        FoldableRouter.paneOf(context) == FoldablePane.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: const [_PlatformDataButton()],
      ),
      body: ListenableBuilder(
        listenable: router,
        builder: (context, _) {
          final String? selected = _selectedUserId(router, twoPane);
          return ListView(
            children: [
              for (final id in const ['1', '7', '42'])
                ListTile(
                  // The whole row is tinted when the user is open in the
                  // right pane of a two-pane tab.
                  selected: selected == id,
                  leading: UserAvatar(id: id),
                  title: Text('User $id'),
                  subtitle: Text("open(UserRoute(id: '$id'))"),
                  // The list is the parent of the detail, so it stays below.
                  onTap: () => router.open(UserRoute(id: id)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The secondary pane animates open from zero width: skip the page
        // until it has room for its app bar and content.
        if (constraints.maxWidth < 240) return const SizedBox.shrink();
        final router = FoldableRouter.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text('User $id'),
            actions: const [_PlatformDataButton()],
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(id: id, radius: 64),
                  const SizedBox(height: 16),
                  Text(
                    'User $id',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('User $id detail'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => router.pop(),
                    child: const Text('pop()'),
                  ),
                  TextButton(
                    onPressed: () => router.open(const HomeRoute()),
                    child: const Text('open(HomeRoute())'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The avatar of a user, shared by the list and the detail so that both ends
/// of the Hero flight are the same widget (only [radius] differs).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.id, this.radius = 20});

  final String id;
  final double radius;

  static String heroTag(String id) => 'user-avatar-$id';

  static Color colorFor(String id) {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return Colors.primaries[seed % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag(id),
      // Also fly during a user-driven pop (Android predictive back, iOS swipe).
      transitionOnUserGestures: true,
      child: Material(
        type: MaterialType.transparency,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: colorFor(id),
          foregroundColor: Colors.white,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 0.6,
            child: FittedBox(child: Text(id)),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.from});

  final String? from;

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    // Where to go after login: the requested location, or Home. `routeFor`
    // is the lookup the router itself uses for deep links.
    final fromUri = Uri.tryParse(from ?? '');
    final target =
        (from == null || fromUri == null ? null : router.routeFor(fromUri)) ??
        const HomeRoute();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        actions: const [_PlatformDataButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              from == null
                  ? 'You are logged out.'
                  : 'You need to log in to see $from',
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('login'),
              onPressed: () {
                session.login();
                // Goes through the guard again, which now lets us in.
                router.open(target);
              },
              child: Text('Log in and open ${target.uri}'),
            ),
            TextButton(
              onPressed: () => router.open(const HomeRoute()),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signs out, then re-runs the redirects of the current stack. On a
/// protected page the guard now answers with LoginRoute.
void _logout(BuildContext context) {
  session.logout();
  FoldableRouter.of(context).refresh();
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile (protected)'),
        actions: const [_PlatformDataButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Only visible when logged in.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => router.open(const SettingsRoute()),
              child: const Text('open(SettingsRoute())'),
            ),
            OutlinedButton(
              key: const Key('logout'),
              onPressed: () => _logout(context),
              child: const Text('Log out + refresh()'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The secondary pane animates open from zero width: skip the page
        // until it has room for its app bar and content.
        if (constraints.maxWidth < 240) return const SizedBox.shrink();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings (protected by parent)'),
            actions: const [_PlatformDataButton()],
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Guarded by ProfileRoute.redirect.'),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const Key('logout'),
                  onPressed: () => _logout(context),
                  child: const Text('Log out + refresh()'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ColorPickerPage extends StatelessWidget {
  const ColorPickerPage({super.key});

  static const colors = {
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
  };

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      // Leaving with the back button completes the push with null.
      appBar: AppBar(
        title: const Text('Pick a color'),
        actions: const [_PlatformDataButton()],
      ),
      body: ListView(
        children: [
          for (final MapEntry(key: name, value: color) in colors.entries)
            ListTile(
              leading: CircleAvatar(backgroundColor: color),
              title: Text(name),
              subtitle: Text("pop('$name')"),
              onTap: () => router.pop(name),
            ),
        ],
      ),
    );
  }
}

/// `pendingBuilder`: shown on launch until the first navigation commits.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting (pendingBuilder)'),
          ],
        ),
      ),
    );
  }
}

/// `notFoundBuilder`: shown for a URL that matches no entry of the route
/// table, or whose factory throws.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Not found'),
        actions: const [_PlatformDataButton()],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('No route for $uri'),
            const SizedBox(height: 8),
            const Text(
              'You get here by typing an unknown URL in the address bar '
              '(web) or from a deep link.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('go-home'),
              onPressed: () =>
                  FoldableRouter.of(context).open(const HomeRoute()),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Opens a dialog with the facts the manual tests need to record: the window,
/// the system insets, the display features and the platform state.
class _PlatformDataButton extends StatelessWidget {
  const _PlatformDataButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Platform data',
      icon: const Icon(Icons.info_outline),
      onPressed: () => _showPlatformData(context),
    );
  }
}

Future<void> _showPlatformData(BuildContext context) {
  final media = MediaQuery.of(context);
  final platform = FoldablePlatformScope.maybeOf(context);
  final text = [
    'window: ${media.size}',
    'padding: ${media.padding}',
    'viewPadding: ${media.viewPadding}',
    'displayFeatures: ${media.displayFeatures}',
    'platform: ${platform ?? '(none)'}',
  ].join('\n');
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Platform data'),
      content: SingleChildScrollView(
        child: Text(text, style: const TextStyle(fontFamily: 'monospace')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            Navigator.of(dialogContext).pop();
          },
          child: const Text('Copy'),
        ),
      ],
    ),
  );
}
