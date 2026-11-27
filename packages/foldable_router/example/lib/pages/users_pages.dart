import 'package:material_ui/material_ui.dart';
import 'package:foldable_router/foldable_router.dart';

import '../routes.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _ids = ['1', '7', '42'];

  /// What is typed in the search field: the list keeps the users whose name
  /// contains it. The page keeps it while it moves between panes.
  String _query = '';

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
          final ids = [
            for (final id in _ids)
              if ('user $id'.contains(_query.trim().toLowerCase())) id,
          ];
          return ListView(
            children: [
              // At the top of the list, in the left pane of a two-pane tab:
              // the on-screen keyboard must not take the focus away from it.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  key: const Key('users-search'),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search users',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              for (final id in ids)
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
      body: Column(
        children: [
          // Scrolls when the on-screen keyboard leaves little room.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    UserAvatar(id: id, radius: 64),
                    const SizedBox(height: 16),
                    Text(
                      'User $id',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
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
            ),
          ),
          // At the very bottom on purpose: tapping it brings up the on-screen
          // keyboard, which must not cover it (in one pane and in two).
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                key: const Key('user-note'),
                decoration: InputDecoration(
                  labelText: 'Note about user $id',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
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
