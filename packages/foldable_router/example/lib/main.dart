import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const RouterExample());

/// A route that is also a tab root.
abstract class TabRoute extends FoldableRoute {
  const TabRoute();

  /// Index of the tab this route belongs to.
  int get tab;
}

class HomeRoute extends TabRoute {
  const HomeRoute();

  @override
  String get path => '/home';

  @override
  int get tab => 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (var index = 1; index <= 5; index++)
          ListTile(
            title: Text('Conversation $index'),
            subtitle: const Text('Tap to open it in the second pane'),
            onTap: () => _router.push(DetailsRoute(id: '$index')),
          ),
      ],
    );
  }
}

class InboxRoute extends TabRoute {
  const InboxRoute();

  @override
  String get path => '/inbox';

  @override
  int get tab => 1;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Inbox: each tab keeps its own stack.'));
  }
}

class SettingsRoute extends TabRoute {
  const SettingsRoute();

  @override
  String get path => '/settings';

  @override
  int get tab => 2;

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Settings'));
  }
}

class DetailsRoute extends FoldableRoute {
  const DetailsRoute({this.id});

  final String? id;

  @override
  String get path => '/details';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const FoldableBackButton(),
        title: Text('Conversation ${id ?? ''}'),
      ),
      body: Center(child: Text('Opened from a URL or from code: $location')),
    );
  }
}

class NotFoundRoute extends FoldableRoute {
  const NotFoundRoute(this.uri);

  final Uri uri;

  @override
  String get path => uri.path;

  @override
  String get location => uri.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route for $uri')),
    );
  }
}

FoldableRoute? _match(Uri uri) {
  return switch (uri.path) {
    '/home' => const HomeRoute(),
    '/inbox' => const InboxRoute(),
    '/settings' => const SettingsRoute(),
    '/details' => DetailsRoute(id: RouteQuery.fromUri(uri).string('id')),
    _ => null,
  };
}

final _router = FoldableRouter(
  config: FoldableRouterConfig(
    roots: const [HomeRoute(), InboxRoute(), SettingsRoute()],
    matcher: _match,
    notFound: NotFoundRoute.new,
    branchOf: (route) => route is TabRoute ? route.tab : null,
    // Back at the root of another tab shows the first tab.
    backTarget: (router) => router.currentIndex == 0 ? null : const HomeRoute(),
  ),
);

final _navigatorKey = GlobalKey<NavigatorState>();

final _delegate = FoldableRouterDelegate(
  router: _router,
  navigatorKey: _navigatorKey,
  builder: _buildShell,
);

Widget _buildShell(BuildContext context) {
  return FoldableNavigator(
    controller: _router.controller,
    builder: (context, body, secondaryBody) {
      return FoldableScaffold(
        topNavigationBuilder: (context, constraints) => AppBar(
          title: Text(switch (_router.currentIndex) {
            0 => 'Home',
            1 => 'Inbox',
            _ => 'Settings',
          }),
        ),
        bodyBuilder: (_, _) => body,
        secondaryBodyBuilder: (_, _) => secondaryBody,
        hasSecondaryBody: secondaryBody != null,
        primaryNavigationBuilder: (context, constraints, padding) {
          return NavigationRail(
            selectedIndex: _router.currentIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) =>
                _router.go(null, _router.config.roots[index]),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inbox),
                label: Text('Inbox'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          );
        },
        bottomNavigationBuilder: (context, constraints) {
          return NavigationBar(
            selectedIndex: _router.currentIndex,
            onDestinationSelected: (index) =>
                _router.go(null, _router.config.roots[index]),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          );
        },
      );
    },
  );
}

/// Swipe back works from the left edge in a single-pane window; in a split
/// window the detail page and the list are side by side.
class RouterExample extends StatelessWidget {
  const RouterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_router',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      routerDelegate: _delegate,
      routeInformationParser: const FoldableRouteInformationParser(),
    );
  }
}
