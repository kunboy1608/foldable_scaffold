import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';
import '../session.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _color;

  Future<void> _pickColor() async {
    // push adds one page and completes with the value given to pop.
    final picked = await FoldableRouter.of(
      context,
    ).push<String>(const ColorPickerRoute());
    if (mounted && picked != null) setState(() => _color = picked);
  }

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('foldable_router example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section(
              'open vs push',
              'open replaces the stack with the route and its parents; '
                  'push adds exactly one page. Watch the stack below.',
            ),
            FilledButton(
              key: const Key('open-user'),
              onPressed: () => router.open(const UserRoute(id: '7')),
              child: const Text("open(UserRoute(id: '7'))"),
            ),
            OutlinedButton(
              key: const Key('push-user'),
              onPressed: () => router.push<void>(const UserRoute(id: '7')),
              child: const Text("push(UserRoute(id: '7'))"),
            ),
            OutlinedButton(
              key: const Key('open-users'),
              onPressed: () => router.open(const UsersRoute()),
              child: const Text('open(UsersRoute())'),
            ),
            const _Section(
              'Auth guard',
              'ProfileRoute has an async redirect (800 ms). It also guards '
                  'its child SettingsRoute. This page stays while it runs.',
            ),
            ListenableBuilder(
              listenable: session,
              builder: (context, _) => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    session.loggedIn ? 'Logged in' : 'Logged out',
                    key: const Key('session'),
                  ),
                  if (session.loggedIn)
                    TextButton(
                      key: const Key('logout'),
                      onPressed: () {
                        session.logout();
                        router.refresh();
                      },
                      child: const Text('Log out'),
                    )
                  else
                    TextButton(
                      key: const Key('open-login'),
                      onPressed: () => router.open(const LoginRoute()),
                      child: const Text('open(LoginRoute())'),
                    ),
                ],
              ),
            ),
            FilledButton(
              key: const Key('open-profile'),
              onPressed: () => router.open(const ProfileRoute()),
              child: const Text('open(ProfileRoute())'),
            ),
            OutlinedButton(
              key: const Key('open-settings'),
              onPressed: () => router.open(const SettingsRoute()),
              child: const Text('open(SettingsRoute())'),
            ),
            const _Section(
              'push with result',
              'The picker is pushed with push<String> and answers with pop.',
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                FilledButton(
                  key: const Key('pick-color'),
                  onPressed: _pickColor,
                  child: const Text('push<String>(ColorPickerRoute())'),
                ),
                Text('Picked: ${_color ?? 'nothing yet'}'),
              ],
            ),
            const _Section(
              'Not found',
              'Every route instance is valid, so the not-found page is only '
                  'reached from a URL: on web, type /nope (or /users/detail '
                  'without ?id=) in the address bar.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          Text(body, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
