# foldable_core

> [!WARNING]
> **Experimental.** This is a prerelease (`0.2.0-dev.1`). The API will change
> without notice and the package is not ready for production use.

Small shared signals that let `foldable_scaffold` and `foldable_router` work
together without depending on each other. `foldable_core` depends only on
`flutter`; neither `foldable_scaffold` nor `foldable_router` depends on the
other.

| Item | Carries | Provided by | Read by | Behaviour without a provider |
|---|---|---|---|---|
| `FoldablePane` | `single` / `primary` / `secondary` + `isSlot` | — (vocabulary) | scaffold, router, app | n/a |
| `FoldablePaneLayout` | `canSplit`, `primaryVisible`, `secondaryVisible`, `axis`, `isSplit` | `FoldableScaffold` | router, page, app | `maybeOf` / `read` → `null`; caller assumes single pane |

`FoldablePaneLayout.maybeOf(context)` subscribes the caller to layout changes;
use `FoldablePaneLayout.read(context)` for a non-subscribing lookup in
`initState` or callbacks.
| `FoldablePaneScope` | `pane`, `owner` (`FoldablePaneOwner?`) | scaffold (one per pane) + router (one per page) | page, `FoldableRouter.paneOf` / `close` | `paneOf` → `FoldablePane.single` |
| `FoldablePaneTransitions` | transition count → `value` | `foldable_router` | `FoldableScaffold` | scaffold animates as before |
| `FoldablePaneTransitionScope` | `ValueListenable<bool>` of the above | `foldable_router` | `FoldableScaffold` | `isTransitioningOf` → `false` |
| `FoldableMotion` | `Duration Function(Duration)` scale | app / dev tools | scaffold, router | duration unchanged |

You rarely need this package directly: `foldable_scaffold` and
`foldable_router` both re-export it.

## Breaking changes in 0.2.0-dev.1

* `FoldableScaffoldScope` removed — replaced by `FoldablePaneLayout` (which
  also carries `primaryVisible`, `secondaryVisible` and `axis`).
* `FoldablePaneTransitionScope`: constructor parameter renamed
  `transition` → `transitions`.
* `FoldablePaneScope.owner` is now `FoldablePaneOwner?` (was `Object?`);
  `FoldablePaneOwner` is an `abstract interface class` in core.
* New public types: `FoldablePane`, `FoldablePaneLayout`, `FoldablePaneScope`,
  `FoldablePaneOwner`, `FoldablePaneTransitions`, `FoldablePaneTransitionScope`.
* Removed from exports: `FoldableScaffoldScope`.
