import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import 'screens.dart';

/// The tabs of the main shell, each a [NormalRoute] with nested sub-routes.
/// A deep link to a nested page (e.g. `/home/calendar/event/1`) rebuilds the
/// whole `Home > Calendar > Event details` stack.
final homeRoute = NormalRoute(
  path: '/home',
  builder: (context) => const HomeScreen(),
  routes: [
    NormalRoute(
      path: '/home/calendar',
      builder: (context) => const CalendarScreen(),
      routes: [
        NormalRoute(
          path: '/home/calendar/event',
          builder: (context) => const EventDetailsScreen(),
        ),
      ],
    ),
    NormalRoute(
      path: '/home/news',
      builder: (context) => const ListNewsScreen(),
      routes: [
        NormalRoute(
          path: '/home/news/new',
          builder: (context) => const NewDetailsScreen(),
        ),
      ],
    ),
  ],
);

final documentRoute = NormalRoute(
  path: '/document',
  builder: (context) => const DocumentScreen(),
  routes: [
    NormalRoute(
      path: '/document/record',
      builder: (context) => const RecordEditorScreen(),
    ),
  ],
);

final profileRoute = NormalRoute(
  path: '/profile',
  builder: (context) => const ProfileScreen(),
  routes: [
    NormalRoute(path: '/profile/edit', builder: (context) => const EditProfileScreen()),
    NormalRoute(path: '/profile/bills', builder: (context) => const BillManagementScreen()),
  ],
);

final profitRoute = NormalRoute(
  path: '/profit',
  builder: (context) => const ProfitScreen(),
  routes: [
    NormalRoute(
      path: '/profit/recipe',
      builder: (context) => const RecipeDetailsScreen(),
    ),
  ],
);

final expenseRoute = NormalRoute(
  path: '/expense',
  builder: (context) => const ExpenseScreen(),
  routes: [
    NormalRoute(
      path: '/expense/recipe',
      builder: (context) => const RecipeDetailsScreen(),
    ),
  ],
);

final signInRoute = NormalRoute(
  path: '/sign-in',
  builder: (context) => const SignInScreen(),
);

final signUpRoute = NormalRoute(
  path: '/sign-up',
  builder: (context) => const SignUpScreen(),
);

/// A split-aware shell around a set of tabs.
FoldableShellBuilder _shell(List<String> labels) {
  return (context, controller, body, secondaryBody) {
    return FoldableScaffold(
      topNavigationBuilder: (context, constraints) =>
          AppBar(title: Text(labels[controller.currentIndex])),
      bodyBuilder: (_, _) => body,
      secondaryBodyBuilder: (_, _) => secondaryBody,
      hasSecondaryBody: secondaryBody != null,
      primaryNavigationBuilder: (context, constraints, padding) {
        return NavigationRail(
          selectedIndex: controller.currentIndex,
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: controller.openBranch,
          destinations: [
            for (final label in labels)
              NavigationRailDestination(
                icon: const Icon(Icons.circle_outlined),
                selectedIcon: const Icon(Icons.circle),
                label: Text(label),
              ),
          ],
        );
      },
      bottomNavigationBuilder: (context, constraints) {
        return NavigationBar(
          selectedIndex: controller.currentIndex,
          onDestinationSelected: controller.openBranch,
          destinations: [
            for (final label in labels)
              NavigationDestination(icon: const Icon(Icons.circle_outlined), label: label),
          ],
        );
      },
    );
  };
}

/// The main tabs (three branches) of the app.
final mainShell = FoldableShellRoute(
  branches: [homeRoute, documentRoute, profileRoute],
  builder: _shell(const ['Home', 'Document', 'Profile']),
);

/// The statistics tabs (two branches), a second, independent shell.
final statisticShell = FoldableShellRoute(
  branches: [profitRoute, expenseRoute],
  builder: _shell(const ['Profit', 'Expense']),
);

/// The app router: the two shells and the full-screen auth routes.
///
/// No `matcher` is given: the router matches URLs against the declared route
/// tree itself, so a deep link rebuilds the whole stack and can switch shell
/// and tab.
final appRouter = FoldableRouter(
  routes: [mainShell, statisticShell, signInRoute, signUpRoute],
  config: FoldableRouterConfig(
    notFound: (uri) =>
        NormalRoute(path: uri.path.isEmpty ? '/' : uri.path, builder: (context) => NotFoundScreen(uri)),
  ),
);

final appNavigatorKey = GlobalKey<NavigatorState>();

final appDelegate = FoldableRouterDelegate(
  router: appRouter,
  navigatorKey: appNavigatorKey,
  builder: appRouter.buildShell,
);