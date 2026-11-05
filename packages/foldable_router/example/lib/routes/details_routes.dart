import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'app_route.dart';

/// A page on top of a tab. Every button is another way to navigate.
class DetailsRoute extends AppRoute {
  const DetailsRoute({this.id});

  final String? id;

  @override
  String get session => mainSession;

  @override
  String get path => '/details';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) {
    final router = AppRouterScope.of(context);
    final navigator = FoldableNavigator.of(context, listen: true);
    final next = '${(int.tryParse(id ?? '') ?? 0) + 1}';
    return Scaffold(
      appBar: AppBar(title: Text('Details ${id ?? ''}')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.layers),
            title: const Text('Stack of this tab'),
            subtitle: Text(
              [
                for (final page in navigator.pages) page.name ?? '(no URL)',
              ].join('  >  '),
            ),
          ),
          const Divider(),
          LabAction(
            title: 'push Details $next',
            subtitle: 'Adds a page on top.',
            onTap: () => DetailsRoute(id: next).push(context),
          ),
          LabAction(
            title: 'go(context) Details $next',
            subtitle: 'Replaces the pages above this one, keeps this one.',
            onTap: () => DetailsRoute(id: next).go(context),
          ),
          LabAction(
            title: 'pushAndRemoveUntil Details $next',
            subtitle: 'Pushes after keeping only the tab root.',
            onTap: () => DetailsRoute(id: next).pushAndRemoveUntil<void>(
              context,
              (page) => page == router.active.pages.first,
            ),
          ),
          LabAction(
            title: 'pushAndReplace Details $next',
            subtitle: 'Swaps this page for the next one, like pushReplacement.',
            onTap: () => DetailsRoute(id: next).pushAndReplace<void>(context),
          ),
          LabAction(
            title: 'back()',
            subtitle: 'Pops this page, or shows the first tab.',
            onTap: router.back,
          ),
          LabAction(
            title: 'popUntil the tab root',
            subtitle: 'Removes pages until the root is on top.',
            onTap: () => router.active.popUntil(
              (page) => page == router.active.pages.first,
            ),
          ),
          LabAction(
            title: 'popToRoot()',
            subtitle: 'Same thing, shorter.',
            onTap: router.active.popToRoot,
          ),
        ],
      ),
    );
  }
}

/// Returns a value to the page that pushed it.
class PickRoute extends AppRoute {
  const PickRoute();

  @override
  String get session => mainSession;

  @override
  String get path => '/pick';

  // Code only: the result has nowhere to go from a URL, so a URL for it shows
  // the not found page.
  @override
  bool get deepLinkable => false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick a colour')),
      body: ListView(
        children: [
          for (final name in const ['red', 'green', 'blue'])
            ListTile(
              title: Text(name),
              // Completes the future of the push.
              onTap: () => FoldableNavigator.of(context).pop(name),
            ),
        ],
      ),
    );
  }
}

/// Always redirects: `go` ends on [ForbiddenRoute], `push` shows this page.
class AdminRoute extends AppRoute {
  const AdminRoute();

  @override
  String get session => mainSession;

  @override
  String get path => '/admin';

  @override
  FoldableRoute? redirect(BuildContext context, FoldableRouteState state) {
    return const ForbiddenRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: const Center(child: Text('Pushed, so no redirect ran.')),
    );
  }
}

class ForbiddenRoute extends AppRoute {
  const ForbiddenRoute();

  @override
  String get session => mainSession;

  @override
  String get path => '/forbidden';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forbidden')),
      body: const Center(
        child: Text('The redirect of /admin brought you here.'),
      ),
    );
  }
}
