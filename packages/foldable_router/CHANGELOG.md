## 0.1.0

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
  screen at a time, picked by `sessionOf` and switched by `refresh()`.
  `buildShell` plugs into `FoldableRouterDelegate.builder`, so a session can
  render with or without a scaffold.
* `FoldableSession.navigator` picks the navigator of a session
  (`FoldableNavigatorKind.split` or `.stack`). `FoldableSession.shell` is
  optional and receives a navigator factory, so a shell arranges the navigator
  the session selected instead of creating one itself.
* A stack session may start with no roots: `FoldableRouterConfig.roots` can be
  empty for `FoldableNavigatorKind.stack`, and the stack shows nothing until
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
