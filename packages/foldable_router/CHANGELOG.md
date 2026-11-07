## Unreleased

* New: `NormalRoute`, a go_router style route declared with `path`, `builder`
  and nested `routes`. Nested routes form a branch stack: a deep link to a leaf
  (`/home/calendar/event/1`) rebuilds the whole `Home > Calendar > Event`
  stack and activates the right branch and shell.
* New: several top-level `FoldableShellRoute`s in one `FoldableRouter` (e.g. a
  `MainShellRoute` and a `StatisticShellRoute`). Their branch stacks are kept
  independently, so `router.showShell(statisticShell)` switches shell while the
  shell being left keeps its state. `FoldableRouter.shells` lists them.
* New: when `FoldableRouterConfig.matcher` is null, the router matches URLs
  against the declared route tree itself, so a tree-only app needs no matcher.
* `FoldableRoute.routes` declares the routes nested under a route, for the
  ancestor stack a deep link rebuilds.
* `FoldableRouterBase` gains `openLocation`, `pushLocation`, `showShell` and
  `shells`, so a route seen through `FoldableRouterScope` can switch shell and
  navigate by location.
* Breaking: the session layer is removed. `FoldableSession`,
  `FoldableSessionSplit`, `FoldableSessionStack`, `FoldableSessionRouter`,
  `FoldableSessionBackButton`, `FoldableRoute.session`, and the
  `FoldableRouterBase.canCloseSession`/`closeSession`/`openSession` members are
  gone.
* Breaking: `FoldableRouter` now takes a route tree. Its constructor takes
  `routes: List<FoldableRouteBase>` instead of `roots`. Group the tabs in a
  `FoldableShellRoute(branches:, builder:)`, or use
  `FoldableRouter.branches(branches: ...)` for the common tabbed app. Pass
  `FoldableRouter.buildShell` as the delegate `builder`.
* New: `FoldableShellRoute` groups the root of every branch (tab) behind a
  shell and keeps the split two-pane navigator, like go_router's `ShellRoute`.
  Plain top-level `FoldableRoute`s next to it are shown full screen.

## 0.2.0-dev.1

* Breaking: the `go` family of navigations is renamed to `open`:
  `FoldableRouter.go` becomes `open`, `goLocation` becomes `openLocation`,
  `goUri` becomes `openUri`, `goFromPage` becomes `openFromPage`,
  `goBackToRoot` becomes `openBackTarget`, `backGoesToRoot` becomes
  `backHasTarget`, `FoldableNavigatorController.goBranch` becomes `openBranch`,
  `FoldableNavigationKind.go` becomes `open`, and `FoldableRoute.go` becomes
  `FoldableRoute.open`.

## 0.1.0-dev.2

* `FoldableSessionStack.initRoute` is optional: without it the session starts
  with no page, like a `Navigator` with no routes, and the first route shown in
  it fills it.
* Breaking: sessions are checked by `FoldableSessionRouter.refresh()`.
  `FoldableSession.canActivate` may be async and gets the `BuildContext` of the root
  navigator (`FutureOr<bool> Function(BuildContext)`) and
  `FoldableSessionStack` takes it, `canBeBase` and the new `parent` too. A
  session that does not hold, and its children, are closed with their stacks;
  the base is chosen again, and `onNoSession` is called when none is left.
  Nothing is on screen until the first `refresh()` completes; URLs and
  navigation that arrive first, or during a `refresh()`, wait for it. A URL of
  a session that does not exist yet is kept. `initialSessionOf` and
  `evaluateSessions()` are gone, `isActivatable` too.
* `pushAndReplace` replaces the top page of the current branch, like
  `Navigator.pushReplacement`, on the controller, `FoldableRouter` and
  `FoldableSessionRouter`. On the router a branch root is never replaced (the
  route is pushed on top), and `pushReplacementLocation` takes a URL.
* A route navigates itself: `route.go(context)`, `route.push(context)`,
  `route.pushAndReplace(context)` and `route.pushAndRemoveUntil(context, ...)`.
  `FoldableRouterDelegate` provides the router through `FoldableRouterScope`,
  and `FoldableRouterBase` declares the four methods (the default throws).
  `FoldableSessionRouter` gains `pushAndRemoveUntil`.
* `FoldableRoute.deepLinkable` false now means the route can not be opened from
  a URL or deep link (it is not found) and has no URL in the address bar. Use
  `FoldableRouterConfig.match` for a match that respects it.
* Stacked sessions: `FoldableSessionRouter.openSession(id, route:)` opens a
  session over the one on screen (the lower one keeps its page stacks) and
  returns a future that `closeSession(result)` completes. `FoldableSession`
  gets `initialRoute` and `closable`, and the router can start from
  `initialSessionOf`. System back at the root of a closable session closes it.
  `sessionOf` and `refresh()` are gone: `resetSession(id)` closes every open
  session and starts over from `id`, and `replaceSession` replaces the one on
  screen. A restored snapshot of another session puts that session on screen.
* Breaking: `FoldableSessionStack` takes `initRoute` (its first page) instead of
  `roots`, and `FoldableSessionSplit` takes `branches: List<BranchRoute>` instead
  of `roots`. A `BranchRoute` is the root route of a tab: the page it builds
  never shows a back button (`FoldableBackButton` hides itself; `hideBackButton`
  turns that off). `FoldableAppBar` is an `AppBar` with the same parameters
  that also leaves out its automatic back button there, with no empty room (a
  plain `AppBar` shares one route with every page, so it can only draw its icon
  empty).
  `FoldableRoute.buildPage` wraps `build` for it.
* Session conditions: `FoldableSessionSplit.canActivate` says when a session may
  be on screen, `canBeBase` whether it can be the base (`FoldableSessionStack`
  has neither). Without an
  `initialSessionOf` the router opens the first session whose
  condition holds, and `evaluateSessions()` chooses again after the app state
  changed. A session whose condition is false is not opened, moved to the top
  or switched to (`openSession`, `replaceSession`, `resetSession`, a route's
  `session`, a URL): nothing is shown instead, unlike a redirect, and
  `onActivationDenied` is told. `replaceSession` and `resetSession` return
  whether they ran.
* `FoldableRoute.session` names the session that shows a route. With a
  `FoldableSessionRouter`, `go`/`push`/`pushAndReplace`/`pushAndRemoveUntil` of
  a route of another session create that session or move it to the top (null
  keeps the session on screen). `openSession` of an open session moves it to
  the top too.
* Breaking: `roots` moved out of `FoldableRouterConfig`: `FoldableRouter` takes
  `roots`, and a `FoldableSession` has its own `roots` instead of a `config`.
  The rest of the config (matcher, `notFound`, redirects, `branchOf`,
  `backTarget`, observers, ...) is shared by all sessions and passed once, to
  `FoldableRouterDelegate(config: ...)`. `FoldableRouterBase.attachConfig` hands
  it to the router; routers also take `config:` directly, for use without a
  delegate. `FoldableRouter.roots` is public, for a shared `backTarget`.
* A URL can switch session through the route the matcher returns: its
  `FoldableRoute.session` names the owner, and the session switches when it is
  `deepLinkable`.
* `FoldableSessionRouter(initialSessionOf: (context) => id)` chooses the base
  session with a `BuildContext`, for example from a provider; it replaces the
  `initialSession` id. It runs when
  `buildShell` first builds; a startup URL and a state to restore wait for it,
  `isResolved` tells whether it ran, and other members throw before that.
* `FoldableSessionBackButton` for an app bar: shown only while a session can be
  closed, and always closes the session on top, never a page.
* The automatic back button of an `AppBar` pops the page it sits on, like
  `FoldableBackButton`, when it is pressed with a pointer.
  
## 0.1.0-dev.1

* Experimental prerelease: the API may change and it is not ready for production.
* Initial release.
* `FoldableNavigator` is an abstract class with two implementations:
  `FoldableSplitNavigator` (created by `FoldableNavigator(...)`), with one page
  stack per branch, split-view panes, offstage pages, Cupertino slides and
  left-edge swipe back, and `FoldableStackNavigator` (created by
  `FoldableNavigator.stack(...)`), which mounts only the top page of the
  current branch and ignores the other branches.
* `FoldableBackButton` pops the page it belongs to. It also works outside a
  page, such as in the app bar of a shell: it follows the closest navigator's
  `canPop` and pops the top page. `FoldableNavigator.canPop(context)` exposes
  the same check for custom leading widgets.
* An `AppBar` with no `leading` shows its automatic back button while the
  navigator can pop, like with `go_router`: the navigators keep a local history
  entry on the enclosing route, so `FoldableBackButton` is not required.
* `FoldableRouter`: deep links, per-route and global redirects with async
  support and a loop cap, branch roots, back policy and observers.
* Observers receive an event for every navigation, including pops by the back
  button, swipe or system back, and tab switches through
  `controller.goBranch` (`FoldableNavigationKind.branch` is now emitted).
* A redirect that throws is reported through `FlutterError.reportError` and the
  navigation is abandoned, instead of leaving an unhandled async error.
* A navigation waiting for a `BuildContext` stops scheduling frames once its
  router is disposed.
* `FoldableRouterDelegate` and `FoldableRouteInformationParser` for
  `MaterialApp.router`.
* `LazyBranch` builds a branch on its first visit.
* `FoldablePageContent` is the interface for custom page types: any `Page`
  that implements it is shown by both navigators. `CupertinoPage` is now
  supported next to `FoldablePage` and `MaterialPage`, and an unsupported page
  type throws a clearer `FlutterError`.
* Per-page transitions: `FoldablePageTransition` (`cupertino`, the default,
  `fade`, `none` and `custom(builder)`) is set with the `transition:` parameter
  of `FoldableNavigator`, `FoldableNavigator.stack`, `FoldableSplitNavigator`
  and `FoldableStackNavigator`, and per page with `FoldablePage.transition` and
  `FoldableRoute.transition`. A push uses the transition of the new page, a pop
  that of the removed page. `none` starts no animation, and swipe back is only
  offered when the top page's transition supports it (`cupertino`).
* A page's `restorationId` gives its content a `RestorationScope` in both
  navigators, so scroll positions and text fields inside it are restored.
* `RouteQuery` reads typed query parameters; `FoldablePath` matches
  `/record/:id` style patterns.
* `FoldablePath` supports a trailing wildcard, `/files/*rest`, that matches one
  or more remaining segments and captures them joined with `/`.
* `RouteQuery` reads repeated query keys (`strings`, `integers`, `decimals`,
  `booleans`, `RouteQuery.all`), and `RouteQuery.build` writes an `Iterable`
  as a repeated key. `integer` only accepts plain decimal integers (no `0x10`
  or `+3`) and `decimal` returns null for `NaN` and infinity.
* `FoldableSession` and `FoldableSessionRouter`: several self-contained
  sessions (each with its own roots, redirects, navigator and shell), one on
  screen at a time, picked by `initialSessionOf` and switched by `resetSession()`.
  `buildShell` plugs into `FoldableRouterDelegate.builder`, so a session can
  render with or without a scaffold.
* `FoldableSession` is abstract with two implementations that pick the
  navigator: `FoldableSessionSplit` and `FoldableSessionStack`
  (`FoldableNavigatorKind` and `FoldableSession.navigator` are gone). Its
  `shell` is
  optional and receives a navigator factory, so a shell arranges the navigator
  the session selected instead of creating one itself.
* A stack session may start with no roots: `roots` can be empty for a
  `FoldableSessionStack`, and the stack shows nothing until
  its first navigation fills it. `FoldableNavigatorController.empty()` supports
  the same at the navigator level. A split session still needs at least one
  root.
* State restoration: `FoldableRouterDelegate(restorationId: ...)` (off by
  default) saves the page stacks and restores them after the system ended the
  app, before the first frame and without redirects or observer events.
  `FoldableRouter.saveState` and `restoreState` keep the current branch and the
  URLs of the pages above the roots; pages without a URL are dropped, as are
  URLs the matcher no longer knows. `FoldableSessionRouter` also saves the
  active session. `FoldableRouterBase` gets `saveState` and `restoreState` with
  no-op defaults. With the id set, the platform's startup route is applied
  after the restore instead of during `setNewRoutePath`.
* Android predictive back: a system back gesture from the left edge drives the
  same user-driven slide as the edge swipe (progress follows the finger, commit
  pops one page and finishes the slide, cancel slides back), in both
  navigators. It needs `android:enableOnBackInvokedCallback="true"` and applies
  only when a swipe back could start; otherwise the system back pops at once as
  before. Only tested with simulated events, not on a device.
* `push`, `pushLocation` and `pushAndRemoveUntil` follow the redirects, so a
  guard cannot be skipped by pushing. A redirect that changes the route pushes
  the new one. They take an optional `context`, wait for the first frame when
  there is no `BuildContext` yet, stay on the branch that was on screen and are
  applied in the order they were made even when a redirect is async. A `go`
  that starts meanwhile cancels a push that is still waiting.
* A redirect loop (more than `FoldableRouterConfig.maxRedirects` redirects in
  one navigation) throws a `FlutterError` with the chain of routes when
  `throwOnRedirectLoop` is true (the default in debug builds). Otherwise the
  `notFound` route is shown and the error is reported; the route the loop ended
  on is never shown. A cap of zero now allows no redirect, and a chain of
  exactly `maxRedirects` redirects is no longer cut short.
* A matcher that returns null for `/` shows the first root instead of
  `notFound` (the platform opens `/` at startup).
