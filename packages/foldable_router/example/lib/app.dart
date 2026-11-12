import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

/// How the status bar names a route on the stack: the shell has no URL of
/// its own, so it shows as `[shell]`.
String describeRoute(FoldableRoute route) =>
    route is FoldableShellRoute ? '[shell]' : route.uri.toString();

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key, required this.router});

  final FoldableRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'foldable_router example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      routerConfig: router.routerConfig,
      // Wraps every page: the router's pages on top, a status bar below.
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

/// App-wide bar showing `router.isNavigating`, `router.stack` and
/// `router.location`.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.router});

  final FoldableRouter router;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // isNavigating is true while redirects are pending.
            ValueListenableBuilder<bool>(
              valueListenable: router.isNavigating,
              builder: (context, navigating, _) => SizedBox(
                height: 4,
                child: navigating
                    ? const LinearProgressIndicator(key: Key('navigating'))
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              // The router is a Listenable: it notifies whenever the stack
              // (and so the location) changes.
              child: ListenableBuilder(
                listenable: router,
                builder: (context, _) {
                  final stack = router.stack;
                  final style = theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stack.isEmpty
                            ? 'stack: (empty)'
                            : 'stack: ${stack.map(describeRoute).join('  >  ')}',
                        key: const Key('stack'),
                        style: style,
                      ),
                      Text(
                        'location: ${router.location ?? '(none)'}',
                        key: const Key('location'),
                        style: style,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
