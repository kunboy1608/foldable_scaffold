## Unreleased

* `FoldableNavigator` is now an abstract class with two implementations:
  `FoldableSplitNavigator` (the previous behavior, still created by
  `FoldableNavigator(...)`) and `FoldableStackNavigator` (created by
  `FoldableNavigator.stack(...)`), which mounts only the top page of the
  current branch and ignores the other branches.
* An `AppBar` with no `leading` now shows its automatic back button while the
  navigator can pop, like with `go_router`: the navigators keep a local history
  entry on the enclosing route, so `FoldableBackButton` is no longer required.
* `FoldableBackButton` now works outside a page, such as in the app bar of a
  shell: it follows the closest navigator's `canPop` and pops the top page.
  `FoldableNavigator.canPop(context)` exposes the same check for custom leading
  widgets.
* A stack session may start with no roots: `FoldableRouterConfig.roots` can be
  empty for `FoldableNavigatorKind.stack`, and the stack shows nothing until
  its first navigation fills it. `FoldableNavigatorController.empty()` supports
  the same at the navigator level. A split session still needs at least one
  root.
* `FoldableSession.navigator` picks the navigator of a session
  (`FoldableNavigatorKind.split` or `.stack`). `FoldableSession.shell` is now
  optional and receives a navigator factory, so a shell arranges the navigator
  the session selected instead of creating one itself.
* A navigation waiting for a `BuildContext` no longer schedules frames forever
  after its router is disposed.
* `FoldableSession` and `FoldableSessionRouter`: several self-contained sessions (each with its own roots, redirects and shell), one on screen at a time, picked by `sessionOf` and switched by `refresh()`. `buildShell` plugs into `FoldableRouterDelegate.builder`, so a session can render with or without a scaffold.

## 0.1.0

* Initial release.
* `FoldableNavigator` with one page stack per branch, split-view panes, offstage pages, Cupertino slides, left-edge swipe back and `FoldableBackButton`.
* `FoldableRouter`: deep links, per-route and global redirects with async support and a loop cap, branch roots, back policy and observers.
* `FoldableRouterDelegate` and `FoldableRouteInformationParser` for `MaterialApp.router`.
* `LazyBranch` builds a branch on its first visit.
* `RouteQuery` reads typed query parameters; `FoldablePath` matches `/record/:id` style patterns.
