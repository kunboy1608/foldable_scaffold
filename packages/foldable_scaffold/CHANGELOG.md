## 0.1.0-dev.4

New:

* `FoldableScaffoldThemeData`, a `ThemeExtension` for the divider: `dividerColor` (the handle), `dividerActiveColor` (hovered, dragged or focused), `dividerBackgroundColor` (the slot), `handleSize`, `handleActiveWidth`, `handleBorderRadius` and `animationDuration`. Put it in `ThemeData.extensions` to style every scaffold, or pass it as `FoldableScaffold.theme` for one. Every field is nullable and falls back to the inherited theme, then to the defaults the divider always had, so nothing changes until it is configured. The divider now reads the theme of the app through `material_ui`: before, it fell back to `ThemeData.fallback()` and ignored the colors of the app.
* `FoldableScaffold.dividerBuilder`, to replace the handle with any widget. It gets a `FoldableDividerState` (`isHovering`, `isDragging`, `isFocused`, `atFold`, `axis`, `textDirection`); dragging, the cursor, the keyboard, the focus and the semantics stay with the scaffold.
* The divider is now focusable, in the tab order, and shows the focus. The arrow keys move it by `dividerKeyboardStep` (16 by default, four times as much with Shift), following the text direction like a drag does, Home and End put it at the edges of its range (and snap it like a released drag), and the width stays within `minBodySize`. Standard `Shortcuts`/`Actions`/`Intent`, no raw key handling.
* The divider is a slider for screen readers: it is labelled (`dividerSemanticLabel`, "Resize panes" by default), gives the share of the pane area the secondary pane takes, and its increase and decrease actions move it by one keyboard step. Around a hinge, and in a one-pane layout, it is not focusable and has no semantics.
* `FoldableScaffoldController` (and `FoldableScaffold.of`/`.maybeOf`): reads `secondaryWidth`, `isSplit` and `isDraggingDivider`, and provides `setSecondaryWidth` (clamped like a drag, snapped on request) and `resetDivider`. The controller given to the scaffold is not disposed by it; the one the scaffold makes is, and `of`/`maybeOf` find it. It does not open or close the secondary body.
* State restoration of the divider: with `restorationId`, the divider position and whether the user placed it survive the app being restarted. The data lives under `'${restorationId}_panes'`, in a scope of its own, so it does not collide with the `restorationId` that the underlying `Scaffold` claims.

Internal:

* The keyboard math and the semantics percentage are pure functions in `src/foldable_scaffold_layout.dart` (`computeKeyboardSecondarySize`, `computeSecondaryPanePercent`), testable without pumping a widget.
* The divider moved to `src/foldable_scaffold_divider.dart`, with the theme in `src/foldable_scaffold_theme.dart` and the controller in `src/foldable_scaffold_controller.dart`. No behavior, layout or pixel change without the new arguments: the 115 tests of 0.1.0-dev.3 pass unchanged.

## 0.1.0-dev.3

**Breaking change:**

* `extendBody` now defaults to `false`, as `Scaffold` does. Pass `extendBody: true` to get the old behaviour (the panes run under the bottom navigation bar and pad for it).

New:

* A hidden pane (one-pane layouts, `hasSecondaryBody: false`, or a pane that collapsed) no longer leaks out of the screen: while it has no width it does not take focus, is left out of the semantics tree, does not take pointer events and its tickers are muted, so a `Row`/`TextField`/`ListTile` in the unseen pane cannot be focused, read by a screen reader or keep animating. The pane stays in the widget tree, so its state (page stack, scroll position, text being typed) is kept and it comes back instantly. The exclusion only applies once the pane has collapsed to zero width, so a pane that is sliding in or out stays fully live and the page slide of `FoldableNavigator` is not cut short.
* Full RTL support, following `Directionality`: the navigation rail moves to the right edge, the secondary body goes to the left and the body to the right, the divider drags in the mirrored direction, and the start-side system inset is added to the rail (and cleared from the panes) on the correct side. `FoldableFold` keeps physical window coordinates; the scaffold mirrors them, so a separating hinge or a flat fold still lines up.
* Forwarded the rest of `Scaffold`'s arguments, with the same names and defaults: `floatingActionButtonAnimator`, `persistentFooterButtons`, `persistentFooterAlignment`, `persistentFooterDecoration`, `onDrawerChanged`, `onEndDrawerChanged`, `drawerDragStartBehavior`, `drawerScrimColor`, `drawerEdgeDragWidth`, `drawerEnableOpenDragGesture`, `endDrawerEnableOpenDragGesture`, `restorationId` and `drawerBarrierDismissible`. `bottomSheetScrimBuilder` is not forwarded because `Scaffold`'s default for it is private.

Internal:

* Split layout calculation out of `build()` into `src/foldable_scaffold_layout.dart`: `computeFrameGeometry`, `computePaneLayout`, `computeSnapTarget` and the pane geometry classes are now pure and testable without pumping a widget. No behavior change.

## 0.1.0-dev.2

**Breaking changes**, closer to `Scaffold`:

* The slots take a widget, as `Scaffold` does: `body`, `secondaryBody`, `appBar`, `primaryNavigation` and `bottomNavigationBar`.
* Renamed the builders that keep the pane constraints: `topNavigationBuilder` is now `appBarBuilder`, `bottomNavigationBuilder` is now `bottomNavigationBarBuilder`. `bodyBuilder`, `secondaryBodyBuilder` and `primaryNavigationBuilder` keep their names, as the optional builder variant of their slot.
* `body` and `bodyBuilder` are both optional, but one of them is required. A slot takes a widget or a builder, not both: the constructor asserts it.
* Removed the null probe of `secondaryBodyBuilder`. The scaffold no longer calls the builder an extra time to find out whether it returns null: the second pane exists when `secondaryBody` (or `secondaryBodyBuilder`) is passed and `hasSecondaryBody` is not false, which now defaults to true. A builder that returns null only leaves the pane empty, and does not change the layout nor whether the back gesture is blocked.
* `hasSecondaryBody` is the explicit switch: set it to false to keep the widget but hide the pane.

## 0.1.0-dev.1

* Experimental prerelease: the API may change and it is not ready for production.
* Initial release.
* The usual `Scaffold` slots are forwarded: `floatingActionButton`, `floatingActionButtonLocation`, `drawer`, `endDrawer`, `bottomSheet`, `backgroundColor` and `resizeToAvoidBottomInset`.
* Fixed the `MediaQuery` of the panes. It now comes from the `Scaffold` body, so with `extendBody` the bottom padding is the height of the bottom navigation bar (it used to be only the system inset, which let lists run under the bar); without `extendBody` it is zero above the bar, and the system inset when no bar is shown (the rail replaces it, or there is no `bottomNavigationBuilder`). The keyboard is no longer counted twice: the body is resized, so the panes see no `viewInsets`.
* `snapWidths` (with `snapThreshold`): the divider snaps to set widths, such as 360 or 412, when it is released. Either pane can be the one that snaps. Off by default.
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
