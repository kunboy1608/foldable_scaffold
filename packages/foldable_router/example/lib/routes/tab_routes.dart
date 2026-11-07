import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'app_route.dart';
import 'checkout_routes.dart';
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
          title: 'route.push(context)',
          subtitle: 'Adds one page on top. Back returns here.',
          onTap: () {
            const DetailsRoute(id: '1').push<void>(context);
            logAction('route.push(context)');
          },
        ),
        LabAction(
          title: 'push, wait for a result',
          subtitle: 'The page pops with a value, like Navigator.push.',
          onTap: () async {
            final color = await const PickRoute().push<String>(context);
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
        const LabSection('open: replace the children of a page'),
        LabAction(
          title: 'route.open(context)',
          subtitle: 'Drops what is above this page, then shows the route.',
          onTap: () {
            const DetailsRoute(id: '10').open(context);
            logAction('route.open(context)');
          },
        ),
        LabAction(
          title: 'open(null, route)',
          subtitle: 'No context: the tab root is the parent.',
          onTap: () {
            router.open(null, const DetailsRoute(id: '11'));
            logAction('open(null, Details 11)');
          },
        ),
        LabAction(
          title: 'open another tab',
          subtitle: 'A tab root switches tab and pops it to its root.',
          onTap: () {
            router.open(null, const InboxRoute());
            logAction('open(null, Inbox)');
          },
        ),
        const LabSection('From a string'),
        LabAction(
          title: 'openLocation("/details?id=42")',
          subtitle: 'Matched like a deep link, redirects apply.',
          onTap: () {
            router.openLocation('/details?id=42');
            logAction('openLocation(/details?id=42)');
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
        LabAction(
          title: 'openLocation("/pick")',
          subtitle:
              'PickRoute is not deepLinkable: a URL shows the not found page.',
          onTap: () {
            router.openLocation('/pick');
            logAction('openLocation(/pick) -> not found');
          },
        ),
        const LabSection('Sessions'),
        LabAction(
          title: 'push a route of another session',
          subtitle:
              'CheckoutRoute.session opens the checkout session over the '
              'tabs. Its back button closes it.',
          onTap: () async {
            final result = await const CheckoutRoute().push<String>(context);
            logAction('push(Checkout) returned $result');
          },
        ),
        const LabSection('Redirects'),
        LabAction(
          title: 'open a guarded page',
          subtitle: 'AdminRoute.redirect opens the Forbidden page instead.',
          onTap: () {
            router.open(context, const AdminRoute());
            logAction('open(Admin) -> redirected');
          },
        ),
        LabAction(
          title: 'push the same guarded page',
          subtitle: 'push follows the redirects too: Forbidden is pushed.',
          onTap: () {
            router.push(const AdminRoute());
            logAction('push(Admin) -> redirected');
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
    return ListView(
      children: [
        for (var index = 1; index <= 5; index++)
          ListTile(
            title: Text('Conversation $index'),
            subtitle: const Text(
              'Wide window: opens in the second pane. Each tab keeps its own '
              'stack.',
            ),
            onTap: () => DetailsRoute(id: '$index').push<void>(context),
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
