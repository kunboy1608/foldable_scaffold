## 0.2.0-dev.2

New:

* Depends on `foldable_core` and `material_ui`: `FoldableBreakpoints` and
  `FoldableFold` live in `foldable_core` now (both packages still re-export
  them), and the router builds on `material_ui` instead of the SDK's
  `package:flutter/material.dart`.
* `FoldablePanes.shell`: the state of the shell holding the panes, so a
  layout returned by `FoldableShellRoute.buildPanes` (typically a
  `FoldableScaffold`) can read `currentIndex`/`goBranch` and build its
  chrome from the tab that is showing.
* `PaneMetrics.signals` (`PaneSignals`): what a frame inside a tab reports
  back — whether `primary`/`secondary` are visible, the axis, `canSplit` and
  the pane's `MediaQuery`. The router turns it into `twoPane`
  (both panes visible), syncs each page route's opacity/barrier, and hands
  the media back to pages through `FoldablePaneLayout` /
  `FoldableScaffoldScope`.
* `FoldablePaneTransitionScope` around the shell body: announces whether a
  page transition is running (`PaneMetrics.transitions`), so `FoldableScaffold`
  can switch panes instantly instead of resizing them on top of a page slide.
* `FoldableRouter.paneOf(context)`: `FoldablePane.single` / `primary` /
  `secondary` of the calling page, rebuilt when it changes.
* `FoldableRouter.close(context)`: closes the calling page and every page
  above it, in one stack update, in one-pane and two-pane tabs alike.

Changed (behaviour, breaking in the pre-release):

* The cycle check of parent chains compares route identity, not value:
  `chainOf` no longer false-positives when a shell and its first branch
  happen to have the same path (`'/'`).

Fixed:

* A page whose frame the layout collapsed to an empty rectangle (a
  `FoldableScaffold` showing only the secondary body in one pane) is hidden
  like a page deeper in the stack. It used to be laid over the whole tab area,
  where it covered the navigation and app bar and took their taps.
* A tab drawn by a layout keeps its pages in the frames in one pane too. When
  the layout declared a single visible pane (`FoldableScaffold`), the pages
  used to fill the whole tab area after the first rebuild (a window resize)
  and hid the navigation of the scaffold.
* `twoPane` follows the panes the layout reports as soon as it reports them,
  not only when the tab area rebuilds: a `FoldableScaffold` showing one pane
  is no longer treated as two panes until the next resize.
* No modal barrier in a tab drawn by a layout: in one pane it covered the
  whole tab area and took the taps of the layout's chrome.
* A frame moved by an ancestor without being laid out (a pane sliding while
  the navigation of a `FoldableScaffold` moves from the side to the bottom)
  is measured again after the frame, and its page follows it instead of
  staying a few pixels off.
* A page is cut to the visible part of its frame (the frame cut by the clips
  of the layout above it): it is laid out on the whole frame, but painted and
  hit-tested only where the frame is seen. A `FoldableScaffold` pane sliding
  out under the edge of its pane area no longer shows its page over the
  navigation rail.

Deprecated:

* `PaneMetrics._metrics`, `_area`, `stackLength`, `hasSecondary` are
  internal now; use `metrics`, `publishScaffold`/`resetScaffoldSignals`,
  `twoPane` and `signals` instead.

## 0.0.1

* **Breaking:** `FoldableRoute.path` is replaced by `segment`: the part of the
  URL path that belongs to the route alone (`'detail'`, not
  `'/users/detail'`). The new getter `fullPath` joins the segments of the
  `parent` chain (empty segments, such as a shell's, add nothing; leading and
  trailing slashes are ignored) and is used for `uri`, equality and the keys
  of `FoldableRouter.routes`. A route no longer repeats the path of its
  parent. To migrate, rename `path` to `segment` and drop the prefix shared
  with the parent; a route with no parent keeps its path, e.g. `'/login'` or
  `'login'`.
* **Breaking:** `FoldableRoute` is now `sealed`: a route extends
  `FoldableFlatRoute` (outside any shell) or `FoldableShellChildRoute`
  (inside a `FoldableShellRoute`); `FoldableShellParent` (exported, sealed)
  is the common type of a shell and of the routes inside it. The type of
  `parent` follows: `FoldableFlatRoute?` for a flat route and for a shell,
  `FoldableShellParent` (required, not nullable) for a route inside a shell,
  so a parent chain holds at most one shell by construction.
  `FoldableShellRoute.branches` is now `List<FoldableShellChildRoute>`.
  `FoldableRouter.push` only accepts a `FoldableFlatRoute` (pushing a route
  inside a shell, or a shell, no longer compiles).
* Changed: when the redirect of a pushed route lands inside a shell (on a
  `FoldableShellChildRoute` or on the shell itself), the navigation is
  committed like `open` of that route and the push completes with `null`,
  as in go_router, instead of completing with an `UnsupportedError`.
* New `FoldableRouter.pageTransitions` (`FoldablePageTransitionsResolver`):
  picks the `PageTransitionsBuilder` that animates pages. Fixes apps built on
  `package:material_ui` (Flutter 3.47+), where the router read the
  `pageTransitionsTheme` of `package:flutter/material.dart`'s `Theme`, which
  is not in such an app's tree: the app's transitions were ignored and a
  light layer faded in over a dark page (a white flash on Android in dark
  mode). Pages are now built on `widgets` only (no `MaterialPage` /
  `MaterialRouteTransitionMixin`), so the router no longer needs either
  Material library; without the parameter the behaviour is unchanged (the
  SDK Material theme).
* New `FoldableRouter.navigatorKey`: the key of the root `Navigator`. Its
  `currentContext` is a context below the root navigator, for code that has
  no page context at hand (`showDialog`, `showModalBottomSheet`, ...). It is
  `null` until the first navigation completes. The page stack still belongs
  to the router: do not push or pop pages through the key.
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
  stacks, `open` only replaces the stack of the target branch, back and
  `pop` work per navigator, and the Android predictive-back state is
  reported to the engine).
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
