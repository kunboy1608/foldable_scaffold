import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'app_route.dart';
import 'details_routes.dart';

/// The navigation lab: one button per way to move.
class HomeRoute extends TabRoute {
  const HomeRoute();

  @override
  String get path => '/home';

  @override
  int get tab => 0;

  @override
  Widget build(BuildContext context) {
    final router = AppRouterScope.of(context);
    return ListView(
      children: [
        ValueListenableBuilder<String>(
          valueListenable: lastAction,
          builder: (context, value, _) => Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Last action'),
              subtitle: Text(value),
            ),
          ),
        ),
        const LabSection('Stack: push and pop'),
        LabAction(
          title: 'push',
          subtitle: 'Adds one page on top. Back returns here.',
          onTap: () {
            router.push(const DetailsRoute(id: '1'));
            logAction('push(Details 1)');
          },
        ),
        LabAction(
          title: 'push, wait for a result',
          subtitle: 'The page pops with a value, like Navigator.push.',
          onTap: () async {
            final color = await router.push<String>(const PickRoute());
            logAction('push<String>(Pick) returned $color');
          },
        ),
        LabAction(
          title: 'push three pages at once (batch)',
          subtitle: 'One rebuild for the whole change.',
          onTap: () {
            router.active.batch(() {
              router.push(const DetailsRoute(id: '1'));
              router.push(const DetailsRoute(id: '2'));
              router.push(const DetailsRoute(id: '3'));
            });
            logAction('batch(push x3)');
          },
        ),
        const LabSection('go: replace the children of a page'),
        LabAction(
          title: 'go(context, route)',
          subtitle: 'Drops what is above this page, then shows the route.',
          onTap: () {
            router.go(context, const DetailsRoute(id: '10'));
            logAction('go(context, Details 10)');
          },
        ),
        LabAction(
          title: 'go(null, route)',
          subtitle: 'No context: the tab root is the parent.',
          onTap: () {
            router.go(null, const DetailsRoute(id: '11'));
            logAction('go(null, Details 11)');
          },
        ),
        LabAction(
          title: 'go to another tab',
          subtitle: 'A tab root switches tab and pops it to its root.',
          onTap: () {
            router.go(null, const InboxRoute());
            logAction('go(null, Inbox)');
          },
        ),
        const LabSection('From a string'),
        LabAction(
          title: 'goLocation("/details?id=42")',
          subtitle: 'Matched like a deep link, redirects apply.',
          onTap: () {
            router.goLocation('/details?id=42');
            logAction('goLocation(/details?id=42)');
          },
        ),
        LabAction(
          title: 'pushLocation("/details?id=43")',
          subtitle: 'Matched like a deep link, appended as is.',
          onTap: () {
            router.pushLocation('/details?id=43');
            logAction('pushLocation(/details?id=43)');
          },
        ),
        const LabSection('Redirects'),
        LabAction(
          title: 'go to a guarded page',
          subtitle: 'AdminRoute.redirect sends go to the Forbidden page.',
          onTap: () {
            router.go(context, const AdminRoute());
            logAction('go(Admin) -> redirected');
          },
        ),
        LabAction(
          title: 'push the same guarded page',
          subtitle: 'push never redirects, so Admin shows.',
          onTap: () {
            router.push(const AdminRoute());
            logAction('push(Admin) -> no redirect');
          },
        ),
      ],
    );
  }
}

class InboxRoute extends TabRoute {
  const InboxRoute();

  @override
  String get path => '/inbox';

  @override
  int get tab => 1;

  @override
  Widget build(BuildContext context) {
    final router = AppRouterScope.of(context);
    return ListView(
      children: [
        for (var index = 1; index <= 5; index++)
          ListTile(
            title: Text('Conversation $index'),
            subtitle: const Text(
              'Wide window: opens in the second pane. Each tab keeps its own '
              'stack.',
            ),
            onTap: () => router.push(DetailsRoute(id: '$index')),
          ),
      ],
    );
  }
}

class SettingsRoute extends TabRoute {
  const SettingsRoute();

  @override
  String get path => '/settings';

  @override
  int get tab => 2;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const LabSection('Sessions'),
        LabAction(
          title: 'Replay the onboarding',
          subtitle: 'The state says "not onboarded": main gives way.',
          onTap: () => updateSession(context, onboarded: false),
        ),
        LabAction(
          title: 'Sign out',
          subtitle: 'The main stacks are dropped (disposeOnLeave).',
          onTap: () =>
              updateSession(context, loggedIn: false, onboarded: false),
        ),
      ],
    );
  }
}
