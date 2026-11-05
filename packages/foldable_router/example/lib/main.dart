import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router.dart';
import 'app_router_scope.dart';

void main() => runApp(const RouterExample());

/// Swipe back works from the left edge in a single-pane window; in a split
/// window the detail page and the list are side by side.
class RouterExample extends StatefulWidget {
  const RouterExample({super.key});

  @override
  State<RouterExample> createState() => _RouterExampleState();
}

class _RouterExampleState extends State<RouterExample> {
  @override
  void initState() {
    super.initState();
    // Nothing is on screen until the sessions were checked once.
    appRouter.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppRouterScope(
      router: appRouter,
      child: MaterialApp.router(
        title: 'foldable_router',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        ),
        routerDelegate: appDelegate,
        routeInformationParser: const FoldableRouteInformationParser(),
      ),
    );
  }
}
