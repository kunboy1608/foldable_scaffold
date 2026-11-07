import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import 'app_state.dart';
import 'app_router_scope.dart';
import 'routes/app_route.dart';
import 'routes/checkout_routes.dart';
import 'routes/guest_routes.dart';
import 'routes/onboarding_routes.dart';
import 'routes/route_registry.dart';

/// What every session shares: URL matching, the not found screen, the guard
/// and the back target.
final appConfig = FoldableRouterConfig(
  matcher: matchRoute,
  notFound: NotFoundRoute.new,
  // A URL cannot open a screen of another session: the first screen of the
  // session on screen is shown instead. Navigating from code to a route of
  // another session opens that session, and never gets here.
  redirect: (context, state) {
    final router = AppRouterScope.of(context);
    final owner = state.route.session;
    return owner != null && owner != router.activeSessionId
        ? router.activeSession.roots.first
        : null;
  },
  branchOf: (route) => route is TabRoute ? route.tab : null,
  // Back at the root of another tab shows the first tab.
  backTarget: (router) => router.currentIndex == 0 ? null : router.roots.first,
);

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
          onDestinationSelected: (index) => appRouter.open(null, tabs[index]),
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
          onDestinationSelected: (index) => appRouter.open(null, tabs[index]),
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
    FoldableSessionStack(
      id: guestSession,
      // Top page only: no tabs, and no state kept below it.
      // Only while signed out: signing in closes it.
      canActivate: (_) => !isLoggedIn,
      disposeOnLeave: true,
      initRoute: const SignInRoute(),
    ),
    FoldableSessionStack(
      id: onboardingSession,
      // Top page only: no tabs, and no state kept below it.
      // Start from the first step every time.
      canActivate: (_) => isLoggedIn && !isOnboarded,
      disposeOnLeave: true,
      initRoute: const WelcomeRoute(),
    ),
    FoldableSessionSplit(
      id: mainSession,
      // A signed out user cannot open the tabs. May be async.
      canActivate: (_) => isReady,
      // Forget what the last user opened.
      disposeOnLeave: true,
      branches: tabs,
      shell: _buildMainShell,
    ),
    FoldableSessionStack(
      id: checkoutSession,
      // Full screen, over whatever session is open.
      // Fresh every time it is opened.
      disposeOnLeave: true,
      // Goes with the tabs when they stop existing, e.g. on sign out.
      parent: mainSession,
      canBeBase: false,
      initRoute: const CheckoutRoute(),
    ),
  ],
);

final appNavigatorKey = GlobalKey<NavigatorState>();

final appDelegate = FoldableRouterDelegate(
  router: appRouter,
  config: appConfig,
  navigatorKey: appNavigatorKey,
  // Draws the shell of whichever session is on screen.
  builder: appRouter.buildShell,
);
