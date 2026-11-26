## 0.1.0-dev.2

New:

* `FoldableBreakpoints`: the widths at which a scaffold changes its layout
  (handheld vs desktop presets, `forPlatform`, `copyWith`, `canSplit`).
* `FoldableFold`: a fold or hinge from `MediaQuery.displayFeaturesOf`
  (`fromFeatures`, `maybeOf`, `bounds`, `isSeparating`, `axis`, `center`),
  plus `DisplayFeature`-based detection of separating vs flat folds.

Both were split out of `foldable_scaffold` and are re-exported by both
packages, so existing imports keep working.

## 0.1.0-dev.1

* Experimental prerelease: the API may change and it is not ready for production.
* Initial release, split out of `foldable_scaffold`.
* `FoldablePaneLayout` and `FoldableScaffoldScope` expose the layout to the panes.
* `FoldablePaneTransitionScope` tells the scaffold that pages are sliding.
* `FoldableMotion` scales animation durations.
