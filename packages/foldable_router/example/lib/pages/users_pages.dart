import 'package:flutter/material.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  /// The user currently shown in the right pane, if the tab has two panes.
  static String? _selectedUserId(FoldableRouter router, bool twoPane) {
    if (!twoPane) return null;
    for (final route in router.stack.reversed) {
      if (route is UserRoute) return route.id;
      if (route is UsersRoute) break;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouter.of(context);
    final bool twoPane = FoldableRouter.paneOf(context) == FoldablePane.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.home_outlined),
          onPressed: () => router.open(const HomeRoute()),
        ),
      ),
      body: ListenableBuilder(
        listenable: router,
        builder: (context, _) {
          final String? selected = _selectedUserId(router, twoPane);
          return ListView(
            children: [
              for (final id in const ['1', '7', '42'])
                ListTile(
                  // The whole row is tinted when the user is open in the
                  // right pane of a two-pane tab.
                  selected: selected == id,
                  // One Hero per user: the avatar flies to the detail and
                  // back (one-pane tabs only: in a two-pane tab the list
                  // stays on screen, so a flight would duplicate it).
                  leading: UserAvatar(id: id),
                  title: Text('User $id'),
                  subtitle: Text("open(UserRoute(id: '$id'))"),
                  // The list is the parent of the detail, so it stays below.
                  onTap: () => router.open(UserRoute(id: id)),
                ),
            ],
          );
        },
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
            UserAvatar(id: id, radius: 64),
            const SizedBox(height: 16),
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

/// The avatar of a user, shared by the list and the detail so that both ends
/// of the Hero flight are the same widget (only [radius] differs).
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.id, this.radius = 20});

  final String id;
  final double radius;

  static String heroTag(String id) => 'user-avatar-$id';

  static Color colorFor(String id) {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return Colors.primaries[seed % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroTag(id),
      // Also fly during a user-driven pop (Android predictive back, iOS swipe).
      transitionOnUserGestures: true,
      // In flight the child lives in the overlay, outside any Scaffold: the
      // Material keeps the text style, the FittedBox scales the label with
      // the circle.
      child: Material(
        type: MaterialType.transparency,
        child: CircleAvatar(
          radius: radius,
          backgroundColor: colorFor(id),
          foregroundColor: Colors.white,
          child: FractionallySizedBox(
            widthFactor: 0.6,
            heightFactor: 0.6,
            child: FittedBox(child: Text(id)),
          ),
        ),
      ),
    );
  }
}
