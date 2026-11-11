import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';

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
      appBar: AppBar(title: const Text('Pick a colour')),
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
      appBar: AppBar(title: const Text('Not found')),
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
