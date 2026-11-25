## 0.2.0-dev.1

* Added `FoldablePaneLayout.read` for non-subscribing layout lookups.
* Corrected `FoldablePaneLayout.maybeOf` documentation to clarify that it
  subscribes to layout changes.
* Breaking: `FoldableScaffoldScope` removed. Its single field (`canSplit`)
  lives on `FoldablePaneLayout`, which also carries `primaryVisible`,
  `secondaryVisible` and `axis`.
* Breaking: `FoldablePaneTransitionScope` constructor parameter renamed
  `transition` → `transitions`.
* Breaking: `FoldablePaneScope.owner` is now `FoldablePaneOwner?` instead of
  `Object?`; `FoldablePaneOwner` is an `abstract interface class` in core so
  `foldable_router` can type the page entry without core importing router.
* Added `FoldablePane` enum (`single`, `primary`, `secondary` + `isSlot`).
* Added `FoldablePaneLayout` (`canSplit`, `primaryVisible`,
  `secondaryVisible`, `axis`, `isSplit`, `bodyPane`, `of`, `maybeOf`).
* Added `FoldablePaneScope` (`pane`, `owner`, `maybeOf`, `read`, `paneOf`;
  `paneOf` falls back to `FoldablePane.single` without a provider).
* Added `FoldablePaneTransitions` (ref-counted `begin` / `end`,
  `ValueListenable<bool>`).
* Added `FoldablePaneTransitionScope` (`of`, `read`, `isTransitioningOf`).
* `FoldableMotion`: API unchanged; dartdoc corrected — it no longer mentions
  `FoldableNavigator` (that class does not exist).
* Version bumped to `0.2.0-dev.1` (pre-release: breaking changes allowed).

## 0.1.0-dev.1

* Experimental prerelease: the API may change and it is not ready for production.
* Initial release, split out of `foldable_scaffold`.
* `FoldablePaneLayout` and `FoldableScaffoldScope` expose the layout to the panes.
* `FoldablePaneTransitionScope` tells the scaffold that pages are sliding.
* `FoldableMotion` scales animation durations.
