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
* `RouteQuery` reads typed query parameters; `FoldablePath` matches
  `/record/:id` style patterns.
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
