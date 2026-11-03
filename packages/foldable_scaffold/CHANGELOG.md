## 0.1.0

* Initial release.
* `FoldableScaffold`: one pane on a phone, body and secondary body side by side on a foldable's inner screen, a tablet or a wide desktop window, draggable divider, collapsible panes, navigation rail and bottom navigation.
* The divider stops where either pane would get narrower than `minBodySize`, so dragging past an edge leaves no dead zone when dragging back.
* `FoldableBreakpoints` sets the widths of the layout: `rail`, `wideRail`, `split` and `splitMinShortestSide`. `FoldableScaffold.breakpoints` overrides the default, which depends on the platform: on Android and iOS (`FoldableBreakpoints.handheld`) two panes are shown from a width of 600 when the window is at least 600 on its short side, which covers the inner screen of a foldable and a tablet but never a phone, even sideways; elsewhere (`FoldableBreakpoints.desktop`) from a width of 1200, as before.
* Fold and hinge awareness: the scaffold reads the vertical fold or hinge from `MediaQuery.displayFeatures` (`FoldableFold`, also usable in your own widgets). A hinge or a half-open fold puts the body on one side and the secondary body on the other, whatever the width, and the hinge area is not a divider handle. A flat fold starts the divider on the crease, and folding or unfolding the device puts it back there. `FoldableScaffold.followFold` turns it off. Horizontal folds and cutouts are ignored.
* The side-by-side layout on desktop starts at a width of exactly 1200 (it used to start just above), as documented.
* The divider is hidden when a pane collapses into the other one.
* Removed the unused `NullableWidgetBuilder` typedef.
* `FoldablePaneLayout` and `FoldableScaffoldScope` expose the layout to the panes.
* `FoldableMotion` scales the animation durations below it.
* `FoldablePaneTransitionScope` lets a page transition snap pane switches.
