## 0.1.0

* Initial release.
* `FoldableScaffold`: one pane below 1200, body and secondary body side by side from 1200, draggable divider, collapsible panes, navigation rail and bottom navigation.
* The divider stops where either pane would get narrower than `minBodySize`, so dragging past an edge leaves no dead zone when dragging back.
* The side-by-side layout starts at a width of exactly 1200 (it used to start just above), as documented.
* The divider is hidden when a pane collapses into the other one.
* Removed the unused `NullableWidgetBuilder` typedef.
* `FoldablePaneLayout` and `FoldableScaffoldScope` expose the layout to the panes.
* `FoldableMotion` scales the animation durations below it.
* `FoldablePaneTransitionScope` lets a page transition snap pane switches.
