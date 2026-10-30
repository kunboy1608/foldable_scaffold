# foldable_router

Navigation for foldable apps: one page stack per branch (tab), Cupertino page
slides, edge swipe back, deep links, redirects and guards, on top of
[`foldable_scaffold`](../foldable_scaffold).

## Features

* **One stack per tab.** Switching tab keeps the pages of both tabs.
* **Two panes.** The second-to-last page is the body, the top page is the
  secondary body; a new page appears next to the current one on a wide window
  and slides over it on a narrow one.
* **Cupertino transitions.** The new page slides in over the old one, which
  gives way a third and lets the new page cast a shadow.
* **Swipe back.** Drag from the left edge to pop the top page, like iOS.
* **Back buttons.** `FoldableBackButton` pops the page it is on, so in a split
  view each pane pops itself.
* **Pages stay alive.** Hidden pages and pages of other branches stay mounted
  offstage.
* **Deep links.** A `FoldableRoute` has a URL; a matcher turns a URL back into
  a route.
* **Redirects and guards.** Per-route and global, synchronous or async, with a
  loop cap, like go_router.
* **Back policy.** Choose what the system back button does when a branch has
  nothing to pop.
* **Observers.** Log every navigation, or drive `foldable_dev_tools`.

## Install

```sh
flutter pub add foldable_router
```

## Quick start

```dart
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

// 1. Routes.
abstract class TabRoute extends FoldableRoute {
  const TabRoute();
  int get tab;
}

class HomeRoute extends TabRoute {
  const HomeRoute();

  @override
  String get path => '/home';

  @override
  int get tab => 0;

  @override
  Widget build(BuildContext context) => const HomeScreen();
}

class SettingsRoute extends TabRoute {
  const SettingsRoute();

  @override
  String get path => '/settings';

  @override
  int get tab => 1;

  @override
  Widget build(BuildContext context) => const SettingsScreen();
}

class DetailsRoute extends FoldableRoute {
  const DetailsRoute({this.id});

  final String? id;

  @override
  String get path => '/details';

  @override
  Map<String, Object?> get query => {'id': id};

  @override
  Widget build(BuildContext context) => DetailsScreen(id: id);
}

FoldableRoute? _match(Uri uri) => switch (uri.path) {
  '/home' => const HomeRoute(),
  '/settings' => const SettingsRoute(),
  '/details' => DetailsRoute(id: RouteQuery.fromUri(uri).string('id')),
  _ => null,
};

// Or with a path pattern:
const detailsPath = FoldablePath('/details/:id');
// detailsPath.match(Uri.parse('/details/3'))?.string('id') == '3'

// 2. Config.
final router = FoldableRouter(
  config: FoldableRouterConfig(
    roots: const [HomeRoute(), SettingsRoute()],
    matcher: _match,
    notFound: (uri) => NotFoundRoute(uri),
    branchOf: (route) => route is TabRoute ? route.tab : null,
    backTarget: (router) =>
        router.currentIndex == 0 ? null : const HomeRoute(),
  ),
);

// 3. Platform glue, created once.
final navigatorKey = GlobalKey<NavigatorState>();
final delegate = FoldableRouterDelegate(
  router: router,
  navigatorKey: navigatorKey,
  builder: (context) => FoldableNavigator(
    controller: router.controller,
    builder: (context, body, secondaryBody) => FoldableScaffold(
      bodyBuilder: (_, _) => body,
      secondaryBodyBuilder: (_, _) => secondaryBody,
      primaryNavigationBuilder: (context, constraints, padding) =>
          NavigationRail(
            selectedIndex: router.currentIndex,
            onDestinationSelected: (index) =>
                router.go(null, router.config.roots[index]),
            destinations: const [/* ... */],
          ),
    ),
  ),
);

// 4. MaterialApp.
MaterialApp.router(
  routerDelegate: delegate,
  routeInformationParser: const FoldableRouteInformationParser(),
);
```

## `go` and `push`

* `push(route)` adds the route on top of the current branch and leaves
  everything below it alone. No redirects, no tab switch.
* `go(context, route)` resolves the redirects, then replaces the pages above
  the page that navigated. `go(null, route)` uses the branch root as the
  parent. Going to a branch root switches to that tab and pops it to its root
  in one update, so it is rendered once.

```dart
router.push(const DetailsRoute(id: '3'));
router.go(context, const SettingsRoute());
router.goLocation('/details?id=3'); // from a link
```

## Redirects and guards

`FoldableRoute.redirect` runs for the route being opened, then
`FoldableRouterConfig.redirect` runs for every route. Both return the route to
show instead, or null. Return a `Future` to wait, for example for a session
check.

```dart
final router = FoldableRouter(
  config: FoldableRouterConfig(
    // ...
    redirect: (context, state) {
      final loggedIn = context.read<Auth>().isLoggedIn;
      if (state.route is! SignInRoute && !loggedIn) {
        return SignInRoute(redirectLink: state.route.location);
      }
      return null;
    },
  ),
);
```

Hand app data to redirects with `stateExtra`; it lands in
`FoldableRouteState.extra`:

```dart
FoldableRouterConfig(
  stateExtra: () => AppSession(isLoggedIn: auth.isLoggedIn),
  redirect: (context, state) =>
      (state.extra! as AppSession).isLoggedIn ? null : const SignInRoute(),
);
```

## Back

* The system back button pops the top page of the current branch.
* When a branch has no page to pop, `backTarget` decides: return a route to
  show it, or null to let the app close. Only tabs other than the first one
  usually return a route.
* `FoldableBackButton` pops the page it belongs to, together with the pages
  above it in the branch, so in a split view each pane pops itself.
* The delegate only goes to the root when its own `PopScope` refused the back,
  so a page inside the navigator refusing a pop does not empty the stack.

## Observers

```dart
class Logger extends FoldableRouterObserver {
  const Logger();

  @override
  void onNavigation(FoldableNavigationEvent event) {
    debugPrint('${event.kind.name} ${event.uri} (${event.depth} pages)');
  }
}

FoldableRouterConfig(observers: const [Logger()], /* ... */);
// Or later: router.addObserver(observer);
```

## Pages and state

Pages are `FoldablePage`s (a plain `Page`, so a normal `Navigator` accepts them
too). Every page of every branch stays mounted offstage, so scroll positions
and text fields survive tab switches and split views. `LazyBranch` defers the
first build of a tab until it is shown (on by default for all but the first
tab via `FoldableRouterConfig.lazyBranches`).

## Example

Run [`example/`](example/lib/main.dart) for tabs, a detail page, swipe back and
deep links.
