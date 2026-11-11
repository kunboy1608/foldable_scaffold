## 0.0.1

* Initial release.
* `FoldableRoute`: class-based routes with static paths, query-string
  parameters, a `parent` chain and sync/async `redirect`.
* `FoldableRouter`: `open`, `push`/`pop` with results, manual `refresh`,
  `isNavigating`, deep-link / web URL handling through a `routes` table,
  `notFoundBuilder` and `pendingBuilder`.
* Redirect loop and limit detection (`RedirectLoopException`,
  `RedirectLimitException`).
