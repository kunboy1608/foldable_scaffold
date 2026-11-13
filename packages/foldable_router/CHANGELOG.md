## 0.0.1

* Initial release.
* `FoldableRoute`: class-based routes with static paths, query-string
  parameters, a `parent` chain and sync/async `redirect`.
* `FoldableRouter`: `open`, `push`/`pop` with results, manual `refresh`,
  `isNavigating`, deep-link / web URL handling through a `routes` table,
  `notFoundBuilder` and `pendingBuilder`.
* Redirect loop and limit detection (`RedirectLoopException`,
  `RedirectLimitException`).
* `FoldableRouter` is a `Listenable` that notifies when `stack` changes, and
  exposes `location`, the URI currently reported to the platform.
* `FoldableRouter.routeFor(uri)` turns a URI into a route with the `routes`
  table; `FoldableRouter.openUri(uri)` opens a URI like a deep link, with
  errors delivered through the returned future.
* `FoldableShellRoute` (with `FoldableShellState`): a persistent frame
  (bottom navigation, rail, ...) in the middle of a parent chain, with one
  lazily built nested navigator and stack per branch (`goBranch` keeps the
  stacks, `open` only replaces the stack of the target branch, `push` inside
  a shell throws `UnsupportedError`, back and `pop` work per navigator, and
  the Android predictive-back state is reported to the engine).
* Fixed: the Android predictive back gesture only acts on the branch that is
  actually on screen. A hidden tab, or a branch covered by a full-screen
  page, no longer takes the gesture (its pages are kept, heroes and all).
  With a shell the value reported to the engine
  (`SystemNavigator.setFrameworkHandlesBack`) is now a single synthesized
  state instead of whichever nested navigator dispatched last.
* Fixed: a back in a shell now handles exactly one thing, in this order: a
  dialog on the root navigator, a full-screen page above the shell, a
  pageless route on top of the visible branch (bottom sheet, menu, dialog
  on the branch navigator), then one page back inside the visible branch.
  Before, with no full-screen page, a dialog or sheet was ignored: back
  left the app from a branch root and popped the page *below* an open
  dialog otherwise, and the predictive back state reported to the engine
  did not see them. The state is now updated as dialogs open and close,
  and the gesture is hidden from branch pages while a dialog covers them.
* Two panes: a shell can override `buildPanes` to show two panes of the same
  tab on wide layouts (`FoldablePanes.primary` left,
  `FoldablePanes.secondary` right); one pane stays the default and every
  other public API is unchanged. Pages never leave their navigator — they
  only change place — so state, focus, scroll and hero controllers survive.
  `FoldableRouter.paneOf(context)` reports the pane of a page and
  `FoldableRouter.close(context)` closes a page together with every page
  above it in one stack update.
* The hero controllers of the branches are disposed when the shell goes away.
* Two panes: a page transition is laid out in the pane of its own page and
  clipped to it, so the scrim, background, snapshot, scale, slide and fade a
  transition paints never reach the other pane (on Linux the Zoom transition
  no longer dims the left pane while the right page enters). One-pane
  transitions, including predictive back, are unchanged; a page's state still
  survives every pane move.
