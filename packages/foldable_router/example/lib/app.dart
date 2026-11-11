import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

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

/// App-wide bar showing `router.isNavigating` and `router.stack`.
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
              // The delegate notifies whenever the stack changes.
              child: ListenableBuilder(
                listenable: router.routerConfig.routerDelegate,
                builder: (context, _) {
                  final stack = router.stack;
                  return Text(
                    stack.isEmpty
                        ? 'stack: (empty)'
                        : 'stack: ${stack.map((r) => r.uri).join('  >  ')}',
                    key: const Key('stack'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
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
