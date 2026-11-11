import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';
import '../session.dart';

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
      appBar: AppBar(title: const Text('Login')),
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
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => router.open(const HomeRoute()),
        ),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings (protected by parent)')),
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
  }
}
