import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => router.open(const HomeRoute()),
        ),
      ),
      body: ListView(
        children: [
          for (final id in const ['1', '7', '42'])
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('User $id'),
              subtitle: Text("open(UserRoute(id: '$id'))"),
              // The list is the parent of the detail, so it stays below.
              onTap: () => router.open(UserRoute(id: id)),
            ),
        ],
      ),
    );
  }
}

class UserPage extends StatelessWidget {
  const UserPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    return Scaffold(
      // The automatic back button pops to whatever is below: the users list
      // after open, Home after push.
      appBar: AppBar(title: Text('User $id')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('User $id', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => router.pop(),
              child: const Text('pop()'),
            ),
            TextButton(
              onPressed: () => router.open(const HomeRoute()),
              child: const Text('open(HomeRoute())'),
            ),
          ],
        ),
      ),
    );
  }
}
