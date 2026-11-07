import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router.dart';
import 'app_router_scope.dart';

void main() => runApp(const RouterExample());

/// Swipe back works from the left edge in a single-pane window; in a split
/// window the detail page and the list are side by side.
class RouterExample extends StatelessWidget {
  const RouterExample({super.key});

  @override
  Widget build(BuildContext context) {
    return AppRouterScope(
      router: appRouter,
      child: MaterialApp.router(
        title: 'foldable_router',
        theme: ThemeData(),
        darkTheme: ThemeData.dark(),
        routerDelegate: appDelegate,
        routeInformationParser: const FoldableRouteInformationParser(),
      ),
    );
  }
}
