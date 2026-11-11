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
