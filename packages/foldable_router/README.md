# foldable_router

> [!WARNING]
> **Experimental.** This is a prerelease (`0.2.0-dev.1`). The API will change
> without notice and the package is not ready for production use.

Navigation for foldable apps: one page stack per branch (tab), Cupertino page
slides, edge swipe back, deep links, redirects and guards.

It is built for the two-pane layouts of
[foldable_scaffold](https://github.com/kunboy1608/foldable_scaffold/tree/main/packages/foldable_scaffold),
but it does not depend on it. `FoldableNavigator` hands its panes to any
builder, so you can lay them out with your own widgets. The shared pane
plumbing comes from
[foldable_core](https://github.com/kunboy1608/foldable_scaffold/tree/main/packages/foldable_core).

## Features

- **Route tree with shells.** `FoldableRouter` takes top-level routes;
  `FoldableShellRoute` groups the roots of the tabs (branches) behind a shell
  and keeps the split two-pane behavior, like go_router's `ShellRoute`. Declare
  several shells (e.g. a main and a statistics one); their stacks are kept and
  `router.showShell(...)` switches between them without losing state.
- **go_router style routes.** `NormalRoute(path:, builder:, routes: [...])`
  declares a screen with nested sub-routes. A deep link to a nested page
  rebuilds the whole ancestor stack (`Home > Calendar > Event`) and activates
  the right branch and shell.
- **Two navigators.** `FoldableNavigator(...)` keeps one stack per tab in two
  panes; `FoldableNavigator.stack(...)` shows only the top page of the current
  branch, full screen, without keeping branches.
- **One stack per tab.** Switching tab keeps the pages of both tabs.
- **Two panes.** The second-to-last page is the body, the top page is the
  secondary body; a new page appears next to the current one on a wide window
  and slides over it on a narrow one.
- **Cupertino transitions.** The new page slides in over the old one, which
  gives way a third and lets the new page cast a shadow. Switch to a fade, no
  animation or your own, for the whole navigator or per page.
- **Swipe back.** Drag from the left edge to pop the top page, like iOS. On
  Android, the predictive back gesture drives the same slide.
- **Back buttons.** `FoldableBackButton` pops the page it is on, so in a split
  view each pane pops itself.
- **Pages stay alive.** Hidden pages and pages of other branches stay mounted
  offstage.
- **Deep links.** A `FoldableRoute` has a URL; a matcher turns a URL back into
  a route.
- **Redirects and guards.** Per-route and global, synchronous or async, for
  `open` and `push` alike, with a loop cap that throws while you develop, like
  go_router.
- **Back policy.** Choose what the system back button does when a branch has
  nothing to pop.
- **Observers.** Log every navigation, or drive `foldable_dev_tools`.

## Install

```sh
flutter pub add foldable_router:^0.2.0-dev.1
```

## Quick start

The example uses `FoldableScaffold`, so add `foldable_scaffold` to your
app too; the router itself does not need it.

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

// The platform opens '/' first, so match it too (here: show the first tab).
FoldableRoute? _match(Uri uri) => switch (uri.path) {
  '/' || '/home' => const HomeRoute(),
  '/settings' => const SettingsRoute(),
  '/details' => DetailsRoute(id: RouteQuery.fromUri(uri).string('id')),
  _ => null,
};

// Or with a path pattern:
const detailsPath = FoldablePath('/details/:id');
// detailsPath.match(Uri.parse('/details/3'))?.string('id') == '3'

// 2. The router: a route tree with one shell route (the tabs).
final router = FoldableRouter(
  routes: [
    FoldableShellRoute(
      branches: const [HomeRoute(), SettingsRoute()],
      builder: (context, controller, body, secondaryBody) => FoldableScaffold(
        bodyBuilder: (_, _) => body,
        secondaryBodyBuilder: (_, _) => secondaryBody,
        hasSecondaryBody: secondaryBody != null,
        primaryNavigationBuilder: (context, constraints, padding) =>
            NavigationRail(
              selectedIndex: controller.currentIndex,
              onDestinationSelected: (index) =>
                  router.open(null, router.roots[index]),
              destinations: const [/* ... */],
            ),
      ),
    ),
  ],
  config: FoldableRouterConfig(
    matcher: _match,
    notFound: (uri) => NotFoundRoute(uri),
    branchOf: (route) => route is TabRoute ? route.tab : null,
    backTarget: (router) => router.currentIndex == 0 ? null : router.roots.first,
  ),
);

// 3. Platform glue, created once.
final navigatorKey = GlobalKey<NavigatorState>();
final delegate = FoldableRouterDelegate(
  router: router,
  navigatorKey: navigatorKey,
  builder: router.buildShell,
);

// 4. MaterialApp.
MaterialApp.router(
  routerDelegate: delegate,
  routeInformationParser: const FoldableRouteInformationParser(),
);
```

## `open` and `push`

- `push(route)` adds the route on top of the current branch and leaves
  everything below it alone. It follows the redirects like `open`, so a guard
  cannot be skipped, but it never switches tab. Pushes are applied in the order
  they were made, even when a redirect is async.
- `open(context, route)` resolves the redirects, then replaces the pages above
  the page that navigated. `open(null, route)` uses the branch root as the
  parent. Going to a branch root switches to that tab and pops it to its root
  in one update, so it is rendered once.

```dart
router.push(const DetailsRoute(id: '3'));
router.open(context, const SettingsRoute());
router.openLocation('/details?id=3'); // from a link
```

## Navigators

`FoldableNavigator` is the abstraction that draws a
`FoldableNavigatorController`. Pick an implementation when you create one:

- `FoldableNavigator(...)` creates a `FoldableSplitNavigator`: one page stack
  per branch (tab), the body and the secondary body side by side on a wide
  window, every page kept mounted offstage.
- `FoldableNavigator.stack(...)` creates a `FoldableStackNavigator`: only the
  top page of the current branch, filling the screen. The pages below it and
  the other branches are not mounted, so their state is thrown away. Use it
  for flows without tabs, like sign in or onboarding.

```dart
FoldableNavigator(
  controller: router.controller,
  builder: (context, body, secondaryBody) => FoldableScaffold(/* ... */),
);

FoldableNavigator.stack(controller: router.controller);
```

A stack may start with no page: `FoldableNavigatorController.empty()` shows
nothing until the first page arrives. Likewise, a router may leave its shell
route's branches empty (`FoldableRouter.branches(branches: const [])` with
`allowEmptyRoots: true`); its first navigation fills the stack. A
`FoldableShellRoute` needs at least one branch.

Both support push, pop, `FoldableBackButton`, the system back button and the
left-edge swipe back, and share `FoldableNavigator.of`, `pageOf`,
`popPageOf`, `isTransitioning` and `transitioningOf`.

## Path patterns and query parameters

`FoldablePath` matches `:name` segments and a trailing `*name` wildcard that
takes one or more remaining segments, joined with `/` and percent-decoded
(`/files` and `/files/` do not match):

```dart
const files = FoldablePath('/files/*rest');
files.match(Uri.parse('/files/a%20b/c.txt'))?.string('rest'); // 'a b/c.txt'
```

A query key may be repeated. `strings`, `integers`, `decimals` and `booleans`
return every value in URL order and skip the ones that do not parse, while
`string` and friends read the last value. `RouteQuery.build` writes an
`Iterable` as a repeated key:

```dart
final query = RouteQuery.fromUri(Uri.parse('/search?tag=a&tag=b&page=2'));
query.strings('tag'); // ['a', 'b']
query.integer('page'); // 2
RouteQuery.build('/search', {'tag': ['a', 'b']}); // '/search?tag=a&tag=b'
```

`integer` accepts plain decimal integers only (`-4`, `007`; not `0x10`, `+3`
or `1.5`), and `decimal` never returns `NaN` or infinity.

## Redirects and guards

`FoldableRoute.redirect` runs for the route being opened, then
`FoldableRouterConfig.redirect` runs for every route. Both return the route to
show instead, or null. Return a `Future` to wait, for example for a session
check.

```dart
// Passed to FoldableRouterDelegate(config: ...).
final config = FoldableRouterConfig(
  // ...
  redirect: (context, state) {
    final loggedIn = context.read<Auth>().isLoggedIn;
    if (state.route is! SignInRoute && !loggedIn) {
      return SignInRoute(redirectLink: state.route.location);
    }
    return null;
  },
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

`push`, `pushLocation`, `pushAndRemoveUntil` and `pushAndReplace` run the same redirects, so a
guard holds for them too. A redirect that sends the user elsewhere makes the
push add that route instead, and the future completes with its result when it
is a `T`, else null. Only a page pushed straight onto
`FoldableNavigatorController` skips the redirects. Pass `context:` to hand the
redirects a `BuildContext` of your own.

A navigation that keeps redirecting past `maxRedirects` is a loop. While you
develop (`throwOnRedirectLoop`, true in debug builds) it fails with a
`FlutterError` that lists the chain, and the navigation is abandoned. In release
builds the app shows the `notFound` route instead and reports the error through
`FlutterError.reportError`. The route the loop ended on is never shown, as it
may be the one a redirect guards.

The platform opens `/` first. If your `matcher` returns null for it, the router
shows the first of `roots` rather than `notFound`.

## Back

- The system back button pops the top page of the current branch. On Android,
  a back gesture can preview the pop (see
  [Predictive back (Android)](#predictive-back-android)).
- When a branch has no page to pop, `backTarget` decides: return a route to
  show it, or null to let the app close. Only tabs other than the first one
  usually return a route.
- `FoldableBackButton` pops the page it belongs to, together with the pages
  above it in the branch, so in a split view each pane pops itself. In the app
  bar of a shell, outside any page, it follows
  `FoldableNavigator.canPop(context)` instead and pops the top page.
- `FoldableNavigator.canPop(context)` says whether the closest navigator has a
  page to pop, and rebuilds when navigation changes, for custom app bar
  leading widgets.
- The delegate only goes to the root when its own `PopScope` refused the back,
  so a page inside the navigator refusing a pop does not empty the stack.

An `AppBar` with no `leading` shows the back button by itself while the
navigator can pop, so `FoldableBackButton` is only needed for custom placement.

```dart
// Inside a page, and in the app bar of a shell around the navigator:
AppBar(leading: const FoldableBackButton());

// Or drive another leading widget from the same check:
AppBar(
  automaticallyImplyLeading: false,
  leading: FoldableNavigator.canPop(context)
      ? IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => FoldableNavigator.of(context).pop(),
        )
      : null,
);
```

## Predictive back (Android)

On Android 14 and later, the system back gesture can show a preview while the
finger is still down. For that the app must opt in, in
`android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:enableOnBackInvokedCallback="true"
    ...>
```

With it, a back gesture from the left edge drives the same slide as the
left-edge swipe back: the top page follows the progress the system reports.
When the gesture is committed the page is popped and the slide finishes; when
it is cancelled the page slides back and nothing is popped. Without the
attribute, or on other platforms, back behaves as before.

The navigator follows the gesture only when a swipe back could start: on
Android, with a page below the top one, a top page that can pop, a transition
that supports swipe back (the default `cupertino`), a `transitionDuration` that
is not zero, no split layout showing two panes, and no other swipe running.
Otherwise the system back pops the top page at once, without a preview. So do
the back button, a gesture from the right edge (the slide only goes right), and
a back that a dialog or another route above the navigator should receive first.
When the navigator has no page to pop, the gesture is left to the route around
it, which may play its own predictive transition.

The system back pops exactly one page, once: the navigator pops through its
controller when it follows a gesture, and a gesture it does not follow is
popped by `PopScope` as before. This was tested with simulated platform events
only (the same messages the Android embedder sends), not on a real device or
emulator.

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
too). With `FoldableNavigator(...)`, every page of every branch stays mounted
offstage, so scroll positions and text fields survive tab switches and split
views. `FoldableNavigator.stack(...)` only keeps the top page, so pop back to a
page that was disposed and it builds again. `LazyBranch` defers the first build
of a tab until it is shown (on by default for all but the first tab via
`FoldableRouterConfig.lazyBranches`).

Besides `FoldablePage`, the navigators show `MaterialPage` and `CupertinoPage`
(the one from `package:flutter/cupertino.dart`; a page class from another
package needs the interface below). To use your own `Page` subclass,
implement `FoldablePageContent` (a single `Widget get child`): the navigators
mount that child themselves, and your `createRoute` only matters if the page is
also given to a normal `Navigator`. Any other page type throws a
`FlutterError` that names the supported types.

Give a page a `restorationId` and the navigators wrap its content in its own
`RestorationScope`, so the restorable state inside it (a `ListView` or a
`TextField` with a `restorationId`, a `RestorableInt`) is saved with the app.
Ids must be unique among the pages of a navigator, and the app needs a
restoration scope (`MaterialApp.restorationScopeId`). A page without an id is
unchanged. The split navigator keeps every page mounted, so each page restores
its own state; the stack navigator drops the state of a page when it unmounts
it.

## Transitions

Pages slide like a Cupertino push by default. Pick another transition for all
the pages of a navigator, or for one page:

```dart
// The whole navigator fades.
FoldableNavigator.stack(
  controller: router.controller,
  transition: FoldablePageTransition.fade,
);

// One page opts out, from code or from its route.
FoldablePage(transition: FoldablePageTransition.none, child: ...);

class SettingsRoute extends FoldableRoute {
  @override
  FoldablePageTransition? get transition => FoldablePageTransition.fade;
  // ...
}
```

- `FoldablePageTransition.cupertino` is the default: slide, a third of
  parallax and a shadow. It is the only built-in one with swipe back.
- `.fade` fades the page on top in (push) or out (pop) over the page below.
- `.none` shows or removes the page at once. The navigator starts no
  animation, so `FoldableNavigator.isTransitioning` stays false.
- `FoldablePageTransition.custom(builder, supportsSwipeBack: false)` wraps the
  page with `builder(context, info, child)`. `info.animation` runs 0 to 1 over
  the transition (curved, or the raw drag while swiping back), `info.role` is
  `steady`, `incoming` or `outgoing`, and `info.isPush` says push or pop.

On a push the transition of the page that arrives animates both pages; on a
pop, the one of the page that is removed. A page without a `transition` uses
the navigator's, as do `MaterialPage`, `CupertinoPage` and pages that
implement `FoldablePageContent`. Swipe back is only offered when the top
page's transition supports it. A transition is called for every page, including
those at rest and hidden, and must return the same widget types for every role
(change properties, not the tree). Pages keep their state either way, but a
different tree re-creates their render objects.

## Shell route and the route tree

`FoldableRouter` takes a list of top-level routes, like go_router.
`FoldableShellRoute` groups the roots of the tabs (branches) and draws them
inside a shell, and plain `FoldableRoute`s next to it are shown full screen.
The shell keeps the split two-pane navigator, so `FoldableShellRoute` carries
the split behavior without any activation or stacking machinery.

```dart
final router = FoldableRouter(
  routes: [
    FoldableShellRoute(
      // BranchRoutes: the roots of the tabs. They never show a back button;
      // use FoldableAppBar for the bar.
      branches: const [HomeRoute(), SettingsRoute()],
      builder: (context, controller, body, secondaryBody) => FoldableScaffold(
        bodyBuilder: (_, _) => body,
        secondaryBodyBuilder: (_, _) => secondaryBody,
        hasSecondaryBody: secondaryBody != null,
        primaryNavigationBuilder: (context, constraints, padding) =>
            NavigationRail(
              selectedIndex: controller.currentIndex,
              // router.open(null, tabs[index]) runs redirects.
              onDestinationSelected: (index) =>
                  router.open(null, router.roots[index]),
              destinations: const [/* ... */],
            ),
      ),
    ),
    // A full-screen route, shown over the shell when opened.
    SignInRoute(),
  ],
  config: appConfig,
);

FoldableRouterDelegate(
  router: router,
  navigatorKey: navigatorKey,
  builder: router.buildShell,
);
```

- The shell route's `branches` are the router's `roots`; a root builds the URL
  of its branch (for example `/home`) and is where back goes when the branch
  has nothing to pop.
- Its `builder` arranges the two panes, with the same `(context, controller,
  body, secondaryBody)` a `FoldableNavigator` builder gets. `router.buildShell`
  renders it, or a plain top-level route when one is on screen.
- A plain route next to the shell is a full-screen sibling: opening one covers
  the shell, and back returns to it. To add a page inside the current branch
  instead, `push` a route that is not one of the top-level routes.
- `FoldableRouter.branches(branches: ...)` is shorthand for a tree with a
  single shell route whose builder shows the top page full screen.

There is no session layer. Model app flows with redirects and guards (see
[Redirects and guards](#redirects-and-guards)), or with more than one router
the app swaps itself using the `FoldableRouterBase` mixin.

## State restoration

When the system ends the app in the background, `MaterialApp.router` brings
back only the URL on top, so the user returns to a single page. To get the
page stacks back, give the app a restoration scope and the delegate an id:

```dart
MaterialApp.router(
  restorationScopeId: 'app',
  routerDelegate: FoldableRouterDelegate(
    router: router,
    navigatorKey: navigatorKey,
    builder: (context) => MyShell(),
    restorationId: 'foldable_router', // off while null (the default)
  ),
  routeInformationParser: const FoldableRouteInformationParser(),
);
```

What is saved is `router.saveState()`: the current branch and, for every
branch, the URLs of its pages from bottom to top. On restore each URL goes
through `FoldableRouterConfig.matcher` and the page is built again, before the
first frame:

- The branch roots are not recreated from a URL; the router keeps its own.
- Only routes with a URL are restored. A page whose route is not
  `deepLinkable`, and objects passed to a route's constructor, are not saved:
  those pages are dropped and the ones around them stay.
- A URL the `matcher` no longer knows is dropped (it does not become a
  `notFound` page).
- Nothing runs through the redirects and the observers are not told: restoring
  re-creates what the user already saw.
- A snapshot that does not fit the config (another number of branches, a
  branch index out of range) is ignored.
- The plain top-level route on screen, if any, is saved by its URL and shown
  again over the shell.
- The startup route from the platform is applied after the restore, so on a
  restored app it equals the page on top and changes nothing.

State inside a page, like a scroll position or a text field, is not part of
this: give those widgets their own `restorationId`, as in any Flutter app.
A custom `FoldableRouterBase` saves nothing unless it overrides `saveState` and
`restoreState`.

## Limitations

- **Deep links to non-root pages of another tab.** `branchOf` only recognises
  branch roots, so a URL such as `/inbox/42` does not switch to the inbox tab:
  the page is shown in the current branch.
- **Pages are not `Navigator` routes.** Hero animations are not supported,
  and `Navigator.of(context)` inside a page
  reaches the root navigator, not the stack of the router. Use
  `FoldableNavigator.of(context)` or the router.
- **State restoration covers the routes with a URL.** With
  `FoldableRouterDelegate.restorationId` the page stacks come back after the
  system ended the app, but pages that are not `deepLinkable` and the objects
  passed to a route's constructor are lost, and state inside a page needs the
  page's `restorationId` (see [Pages and state](#pages-and-state)). See [State restoration](#state-restoration).
- **Swipe back is left-edge only.** There is no right-edge swipe for
  right-to-left layouts.
- **Android predictive back is untested on a device.** The gesture drives the
  same slide as the edge swipe (see [Predictive back (Android)](#predictive-back-android)),
  but it has only been exercised with simulated events in tests. It follows
  gestures from the left edge only: a right-edge gesture, the back button and
  pages whose transition has no swipe back pop at once, without a preview.
- **The split navigator keeps every page of every branch mounted.** This keeps
  scroll positions and text fields, at the cost of memory. Use
  `FoldableNavigator.stack(...)` when that matters; `LazyBranch` only defers
  the first build of a tab.

## Example

Run the [example](example/) for a tabbed home drawn by a `FoldableShellRoute`,
with a button for every way to navigate (`push`, `push` with a result, `open`
with and without a context, `openLocation`, `pushLocation`, `batch`,
`pushAndRemoveUntil`, `popUntil`, redirects), with swipe back and deep links.
`FoldableNavigator.stack` is still available for flows without tabs.
