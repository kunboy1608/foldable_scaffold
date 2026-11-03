# foldable_core

> [!WARNING]
> **Experimental.** This is a prerelease (`0.1.0-dev.1`). The API will change
> without notice and the package is not ready for production use.

Small shared signals that let `foldable_scaffold` and `foldable_router` work
together without depending on each other.

| Widget | Carries | Provided by | Read by |
|---|---|---|---|
| `FoldableScaffoldScope` | `canSplit`: wide enough for two panes | scaffold | router |
| `FoldablePaneLayout` | which panes are visible | scaffold | router, dev tools |
| `FoldablePaneTransitionScope` | pages are sliding right now | router | scaffold |
| `FoldableMotion` | animation duration scaling | dev tools, tests | scaffold, router |

You rarely need this package directly: `foldable_scaffold` and
`foldable_router` both re-export it.
