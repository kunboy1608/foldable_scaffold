import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'routes/app_route.dart';
import 'routes/guest_routes.dart';
import 'routes/onboarding_routes.dart';
import 'routes/route_registry.dart';
import 'routes/tab_routes.dart';

/// Keeps a session to its own screens: a route of another session shows
/// [home] instead.
FoldableRedirect _guard(String session, FoldableRoute home) {
  return (context, state) {
    final route = state.route;
    final owner = route is AppRoute ? route.session : null;
    return owner != null && owner != session ? home : null;
  };
}

FoldableRouterConfig _config(
  String session,
  List<FoldableRoute> roots, {
  FoldableBackTarget? backTarget,
}) {
  return FoldableRouterConfig(
    roots: roots,
    matcher: matchRoute,
    notFound: NotFoundRoute.new,
    redirect: _guard(session, roots.first),
    branchOf: (route) => route is TabRoute ? route.tab : null,
    backTarget: backTarget,
  );
}

/// The tabs of [mainSession] in a navigation rail / bar, drawn by the split
/// navigator.
Widget _buildMainShell(
  BuildContext context,
  FoldableNavigatorController controller,
  FoldableNavigator Function(FoldableNavigatorBuilder builder) navigator,
) {
  return navigator((context, body, secondaryBody) {
    return FoldableScaffold(
      topNavigationBuilder: (context, constraints) => AppBar(
        title: Text(switch (controller.currentIndex) {
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
          selectedIndex: controller.currentIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: (index) => appRouter.go(null, tabs[index]),
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
          selectedIndex: controller.currentIndex,
          onDestinationSelected: (index) => appRouter.go(null, tabs[index]),
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
  });
}

/// The router of the example. Screens read it from `AppRouterScope`.
final appRouter = FoldableSessionRouter(
  sessions: [
    FoldableSession(
      id: guestSession,
      // Top page only: no tabs, and no state kept below it.
      navigator: FoldableNavigatorKind.stack,
      disposeOnLeave: true,
      config: _config(guestSession, const [SignInRoute()]),
    ),
    FoldableSession(
      id: onboardingSession,
      // Top page only: no tabs, and no state kept below it.
      navigator: FoldableNavigatorKind.stack,
      // Start from the first step every time.
      disposeOnLeave: true,
      config: _config(onboardingSession, const [WelcomeRoute()]),
    ),
    FoldableSession(
      id: mainSession,
      // Forget what the last user opened.
      disposeOnLeave: true,
      config: _config(
        mainSession,
        tabs,
        // Back at the root of another tab shows the first tab.
        backTarget: (router) =>
            router.currentIndex == 0 ? null : const HomeRoute(),
      ),
      shell: _buildMainShell,
    ),
  ],
  sessionOf: sessionNow,
);

final appNavigatorKey = GlobalKey<NavigatorState>();

final appDelegate = FoldableRouterDelegate(
  router: appRouter,
  navigatorKey: appNavigatorKey,
  // Draws the shell of whichever session is on screen.
  builder: appRouter.buildShell,
);
