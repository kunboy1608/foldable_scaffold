## 0.0.1

* **Breaking:** `FoldableRoute.params` is now `Map<String, Object?>` (was
  `Map<String, String?>`): values may be `String`, `int`, `double`, `bool` or
  `DateTime`. An unsupported type, or a non-finite `double`, throws an
  `ArgumentError` (also in release). `int`/`double` are written with
  `toString()`, `bool` as `true`/`false`, and `DateTime` in UTC via
  `toIso8601String()`. Equality and `hashCode` use the encoded query, so
  `{'id': 1}` equals `{'id': '1'}` and two `DateTime`s for the same instant
  are equal.
* **Breaking:** `FoldableRoute.redirect` (and `FoldableShellRoute.redirect`)
  is now `redirect(BuildContext context, RouteState state)` (was
  `redirect(RouteState state)`). `context` is the `Router` widget's context,
  above the `Navigator` (the one go_router passes to its redirects). The same
  context is used for launch, deep links / platform URLs, `open`, `openUri`,
  `push`, `refresh` and the shell's tab-switch re-check. `open`, `openUri`,
  `push` and `refresh` before the router is mounted now complete with a
  `StateError`, and a redirect resumed after the router is removed is dropped.
* New `FoldableParams` (exported by the library): the decoded query handed to
  a `FoldableRouteFactory` (`FoldableRoute Function(FoldableParams)`), with
  `operator []` for the raw string, `contains`, an unmodifiable `values`, and
  `getString` / `getInt` / `getDouble` / `getBool` / `getDateTime` plus
  `…OrNull` variants that throw a `FormatException` on a malformed value
  rather than treating it as absent.
* Fixed: when the `Router` re-parsed a location equal to the one on screen
  (which happens whenever an inherited widget a redirect depends on, such as
  `MediaQuery.sizeOf` or `Theme.of`, changes), it used to be opened again and
  replace the stack with the parent chain of the top route. It now runs a
  silent re-check instead: it never replaces an `open` / `openUri` / `push` /
  explicit `refresh` / shell tab switch in flight (it waits and runs once on
  the stack it left), does not set `isNavigating`, and leaves the stack,
  shell branch stacks, pending `push` futures and listeners untouched when
  every redirect allows it; a redirect that now returns a route navigates
  there.
* Fixed (Android): when the `Router` rebuilt while a page could be popped
  (for example on every frame of the keyboard animation, when a redirect
  reads `MediaQuery`), the root `Navigator` reported "cannot pop" then "can
  pop" in the same frame. Android re-registered the back callback of the app
  above the one of the on-screen keyboard, so the key that hides the keyboard
  popped the top page instead. The router now forwards a single, final value
  per frame.
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
