## 0.1.0-dev.10

Changed (behaviour, breaking in the pre-release):

* `FoldableBreakpoints` and `FoldableFold` have moved to `foldable_core`.
  `foldable_scaffold` still re-exports them (through `package:foldable_core`
  and its own entry point), so imports keep working.
* The whole package builds on `package:material_ui/material_ui.dart`; the
  SDK's `package:flutter/material.dart` is no longer imported by the
  library itself.

New:

* `example/lib/with_scaffold.dart` (`foldable_router`'s example): three tabs
  in a shell, one pane on a phone, two panes on a tablet, chrome from
  `FoldableScaffold`, and a full-screen page pushed above the shell — with
  `test/with_scaffold_test.dart` covering both layouts.

## 0.1.0-dev.9

Changed (behaviour, breaking in the pre-release):

* On iPhone Duo the default navigation (the platform asks for vertical bars) now follows Apple's guidelines: it sits **inside** the system strip of its side (84 wide on the inner display in landscape, with the clock, Wi-Fi and the camera), in line with the system icons, and at the **bottom**. Before, the slot was the extent plus the strip (156) with the rail beside the strip, at the top.
* `FoldableNavigationPlacementResolver` default (`FoldableNavigationPlacements`) for a vertical bar edge returns `alignment: end, insideInset: true`. Bottom bars and rails by breakpoint are unchanged. With no system inset on that side the slot is the extent as before.

New:

* `FoldableNavigationAlignment` (`start`, `center`, `end`) and `FoldableNavigationPlacement.alignment` (default `start`): the position along the edge (top, middle, bottom for a side navigation). With `end` the scaffold keeps the bottom system inset (home indicator) off a side navigation; the builder reads it to align its content (`NavigationRail.groupAlignment`). For a top or bottom bar it is the horizontal direction and only the builder reads it.
* `FoldableNavigationPlacement.insideInset` (default false): a side navigation sits in the system inset strip of its edge. With an inset greater than zero the slot is as wide as the strip (`extent` ignored), the navigation fills it with no side padding and `constraints.maxWidth` is the strip's width; with no inset it is a normal slot. The cutouts in that strip (the camera) are avoided, so the navigation moves under them. All named constructors take both new parameters; `==`, `hashCode` and `toString` include them.
* `avoidCutouts: false` only switches off the cutout avoidance: the placement in the strip and the bottom inset of `alignment: end` stay.
* The `padding` given to a side navigation builder is still 0 on its edge and the system's on the other sides, the bottom included, also when the scaffold padded it (`alignment: end`): do not apply it again.

Fixed:

* A `NavigationRail` (or any widget with its own `SafeArea`) in a side navigation took the system inset of its edge a second time, because `MediaQuery.padding` still held it after the scaffold had applied it. Inside the 84 wide strip that left the rail no width: its icons and labels were drawn outside the strip (seen on the iPhone Duo outer display, 678x466, vertical bar on the start edge). The scaffold now removes the edge inset, and the bottom one when it padded it, from the `MediaQuery` of the side navigation. Test: `foldable_scaffold_rail_safe_area_test.dart`.

Example: the rail uses `groupAlignment` from `placement.alignment` and a `minWidth` that fits `constraints.maxWidth`.

Tests that changed: `defaultNavigationPlacement puts the navigation on the side the platform asks for` and `FoldableVerticalBarScope puts the navigation on the side below the rail width` (navigation test) now expect `alignment: end, insideInset: true`; the slot test of the real iPhone Duo case in `foldable_scaffold_side_inset_test.dart` now uses an explicit `insideInset: false` placement (the dev.8 layout).

Not verified: not run on a device.

## 0.1.0-dev.8

Fixed:

* The content of a navigation beside the panes (a rail) was under the system inset of its edge. The slot is as wide as the extent plus that inset (`padding.left` or `padding.right`), but the navigation was given the whole slot, so a `NavigationRail` centred its icons across it and they landed in the status bar or camera strip (seen on a real iPhone Duo inner display in landscape: `padding.right` is 84, and the Inbox icon of the rail was under the status bar). Android with a notch on the side of the rail was affected too. The scaffold now pads the navigation on the side of the inset, so its content is in the extent only. The slot width, `navigationWidth` and the panes do not change. This applies whatever `avoidCutouts` is.

Changed (behaviour, breaking in the pre-release):

* The `constraints` that `navigationBuilder` and `primaryNavigationBuilder` get for a side navigation are now the extent (the inset of the edge is taken off).
* The `padding` they get now means "the system inset the scaffold has not applied to the navigation": the side of the rail (left or right) is 0, the other sides are unchanged. A navigation that used `padding.left`/`padding.right` on its own side to keep off the system bars must not do it any more, or it is counted twice. The top, bottom and bar navigations are unchanged.
* The area of a rail used to look for cutouts is the extent only, without the inset strip.

Example: the Platform data dialog shows `view padding (raw, before the dialog's SafeArea)` (the dialog's `SafeArea` was eating the real padding and the report showed zero) and labels `MediaQuery.padding` as the value inside the dialog.

The device profiles test has a `padding` per profile (zero for now, to fill in from the new line) and checks the head of a side navigation is out of the system inset.

Not verified: not run on a device.

## 0.1.0-dev.7

New:

* `FoldableScaffold.avoidCutouts` (default true): the app bar and a navigation beside the panes (a rail) stay clear of the cameras and the Dynamic Island. iPhone Duo reports a zero `MediaQuery.padding` in every pose and gives the cameras only as `DisplayFeatureType.cutout` display features (through `FoldablePlatformScope`), so the rail and the actions of the app bar ended up under them.
  * The app bar (`appBar` and `appBarBuilder`) is wrapped in a `MediaQuery` with the space the cutout needs added to the left or right padding, so `AppBar` moves its toolbar content and keeps its background at full width. An app bar of your own has to respect `MediaQuery.padding` as well.
  * A rail gets the space as padding at the top (a cutout above it) or at the bottom (a cutout below it): its width does not change, and its background does not fill the part left clear. The `padding` given to `navigationBuilder` and `primaryNavigationBuilder` is still the system's.
  * A cutout that lies entirely inside the system padding (Android) is ignored, so the space is not counted twice. Cutouts are in window coordinates, so they apply only to a scaffold as wide and as tall as the window; `avoidCutouts: false` keeps the old layout.
  * Not handled: the content of the panes, a navigation below or above the panes, and toolbars inside the panes.

The device profiles test checks, for each iPhone Duo pose, that an app bar action and the head of a rail are out of every cutout.

Not verified: not run on a device.

## 0.1.0-dev.6

New:

* `foldable_scaffold` is now also a Flutter plugin with an iOS part (iOS only: the other platforms have no native code and use it as plain Dart). It brings to Flutter what only UIKit knows on iPhone Duo (`UIView.ReservedRegion`, `UITraitCollection.verticalBarEdge`, iOS 27.1 and later): the fold, the cameras and the Dynamic Island as display features, and the side of the system's vertical bars.
* `FoldablePlatformScope` wraps the app (in `MaterialApp.builder`, below the `WidgetsApp`) and, on iOS only, puts the active reserved regions in `MediaQuery.displayFeatures` (merged with the existing ones, without duplicates; a division is a `fold` in `postureHalfOpened`, an occlusion is a `cutout`) and provides `FoldableVerticalBarScope` (`leading` is `start`, `trailing` is `end`, `unspecified` is null). On every other platform it returns its child untouched and does not use the channel. `FoldablePlatformScope.maybeOf(context)` gives the whole state.
* `FoldablePlatformState` (immutable, `==`/`hashCode`, `fromMap` that never throws and falls back to safe defaults, `displayFeatures`), `FoldableReservedRegion` (`frame`, `isActive`, `margins`), `FoldablePlatformSource` (the interface of where the data comes from) and `ChannelFoldablePlatformSource` (the real one: the method channel `foldable_scaffold/platform` with `getState`, the event channel `foldable_scaffold/platform/events`, protocol version 1).
* Inactive regions are in the state but are not display features: a division that is not active (the device is fully open) is no fold, and a camera that is off covers nothing.
* The iOS plugin supports iOS 15 and later (CocoaPods and Swift Package Manager).
* Building the iOS plugin needs an Xcode with the iOS 27.1 SDK (the one that builds for iPhone Duo): it names APIs that older SDKs do not have, so an older Xcode fails to compile any iOS app that depends on this package. On an iOS older than 27.1 the calls are skipped (`#available`) and the plugin answers with no regions and an unspecified edge.
* Changes are found without swizzling or subclassing the view controller: a watch on the bounds of the Flutter view and a light display link that compares the state (only while Dart listens), plus a `getState` call when the window metrics change.
* The example wraps the app in the scope (the simulated folds keep working and override the platform's), has a "Platform data" button that shows the numbers live, and prints them with `debugPrint` when they change, to measure a device.

The numbers of iPhone Duo (sizes, active regions and vertical bar edge for its poses) are in the device profiles test, which now runs against them.

Not verified: the Swift code and the podspec were written without Xcode and have **not been compiled or run**.

## 0.1.0-dev.5

**Breaking changes:**

* `FrameGeometry`, `computeFrameGeometry` and the navigation slots now work from a placement. `hasPrimaryNavigation` became `hasNavigation` and a `placement` is required (internal API, not exported).

New:

* The navigation can go below the panes, above them, or beside them on either side, and a function decides it. `FoldableScaffold.navigationPlacement` takes a `FoldableNavigationPlacementResolver` that gets a `FoldableLayoutInfo` (sizes of the scaffold and the window, platform, text direction, insets, breakpoints, fold, secondary body, and the vertical bar edge) and returns a `FoldableNavigationPlacement`: `.bottom()`, `.top()`, `.start({extent})`, `.end({extent})`, `.left({extent})`, `.right({extent})` or `.none()`. `start`/`end` follow the text direction, `left`/`right` are physical.
* `defaultNavigationPlacement(info)`, exported, is what the scaffold uses without a resolver: a bottom bar under `FoldableBreakpoints.rail`, a rail on the start side from there, the same as before. `FoldableNavigationPlacements.handheld`, `.desktop` and `.forPlatform` are the rules by platform (they agree for now). A custom resolver can fall back to it.
* `FoldableScaffold.navigationBuilder` builds the navigation for whichever placement was chosen (a bar or a rail), with the placement, the constraints and the system insets. It replaces `primaryNavigation` and `bottomNavigationBar` when passed, and passing both is an error. Those slots still work: `primaryNavigation` for a side, `bottomNavigationBar` for the bottom or the top.
* `FoldableVerticalBarScope`, for iPhone Duo: the system puts its bars on the side of the display on the outer display and in some poses of the inner one, and tells the app which side (`verticalBarEdge` in UIKit, `toolbarVerticalEdge` in SwiftUI). Flutter does not expose it, so the app reads it and gives it to the scope; the default placement then goes there whatever the width.
* A navigation beside the panes can be on the right: the pane area and the fold are laid out from the physical edge, the system inset is taken from the side the navigation is on, and the panes keep their state when the navigation moves.
* The example has a "Vertical bar (iPhone Duo)" option in the end drawer, and uses a single `navigationBuilder`.

**Horizontal folds and hinges:**

* A **separating horizontal fold** (a hinge, or a half-open fold: the tabletop posture, or a dual-screen device in portrait such as iPhone Duo) stacks the panes: the body above the fold, the secondary body below it, whatever the width and the text direction (RTL only mirrors the horizontal order). The fold area between them is the divider: empty, not a handle, no focus, no semantics. Stacking needs a secondary body and both halves at least `minBodySize` *tall* (`minBodySize` is the minimum height as well as the minimum width), otherwise the usual rules apply. While stacked, `FoldableScaffoldScope.canSplit` is true whatever the width. A **flat horizontal fold is ignored**, like a cutout; vertical folds behave exactly as before.
* The fold is in window coordinates, but the panes start below the app bar, the navigation above them and the system inset, and end above the navigation below them, whose sizes belong to your widgets. The scaffold measures where the pane area is after layout (a small render object, reported after the frame and only when the value changes: no rebuild loop) and subtracts it. A horizontal fold needs the scaffold to be as tall as the window, as a vertical one needs it to be as wide. The first frame of the app, before there is a measure, lays the panes out from an estimate and does not paint them; the next frame shows them in the right place. Changes of posture later use the last measure and are right at once; a new measure never animates the panes.
* With several folds, the first of `displayFeatures` that applies wins; a flat vertical fold gives way to a separating horizontal one.
* `FoldableFold` has an `axis` (`Axis.vertical` by default, so the constructor and `maybeOf` are unchanged), `isVertical`, `isHorizontal` and `paneAxis`; `center` is the position across the fold. `FoldableFold.fromFeatures` finds horizontal folds too (separating ones only) and takes `vertical`/`horizontal` flags. `FoldableLayoutInfo.fold` can therefore be horizontal.
* `FoldableScaffoldController` has `axis` (`Axis.horizontal` side by side, `Axis.vertical` stacked, null with one pane) and `isStacked`. Stacked, `isSplit` is true, `setSecondaryWidth` and `resetDivider` do nothing (as around a vertical hinge) and `secondaryWidth` is the width of the pane area.
* `FoldablePaneLayout` (in `foldable_core`) has an `axis`, `Axis.horizontal` by default, so existing code is unaffected.
* Stacked panes keep their state when the posture changes. The pane above has no bottom inset in its `MediaQuery`, the one below no top inset. A pane with no extent along the axis is hidden (no focus, no semantics, no pointer, muted tickers) as before, now along either axis.
* The geometry works along an axis: `PaneGeometry` has `primaryExtent`, `dividerExtent`, `secondaryExtent` and an `axis`, `computePaneLayout` takes `axis`, `totalExtent`, `foldStart` and `foldEnd`, and one delegate lays the panes out along either (internal API, not exported; the old `*Width` and `foldLeft`/`foldRight` names are gone, the tests of the old behaviour were renamed and pass otherwise unchanged). Between side by side and stacked the panes are in their new place at once, as extents along different axes cannot be interpolated; on one axis they animate as before.
* The example has "Hinge, horizontal (two screens stacked)" and "Fold, half open, horizontal" in the fold menu.
* `test/foldable_scaffold_device_profiles_test.dart` is a table of device profiles (iPhone Duo outer display, inner display portrait and landscape, partially folded) whose numbers are still to be filled in from the Device Hub of Xcode; their tests are skipped until then.

Known limits: opening the keyboard shrinks the pane area, and can leave the lower half under `minBodySize` and unstack the panes; a navigation whose height animates moves the hinge inside the pane area and re-lays the panes out for the length of the animation.

## 0.1.0-dev.4

New:

* `FoldableScaffoldThemeData`, a `ThemeExtension` for the divider: `dividerColor` (the handle), `dividerActiveColor` (hovered, dragged or focused), `dividerBackgroundColor` (the slot), `handleSize`, `handleActiveWidth`, `handleBorderRadius` and `animationDuration`. Put it in `ThemeData.extensions` to style every scaffold, or pass it as `FoldableScaffold.theme` for one. Every field is nullable and falls back to the inherited theme, then to the defaults the divider always had, so nothing changes until it is configured. The divider now reads the theme of the app through `material_ui`: before, it fell back to `ThemeData.fallback()` and ignored the colors of the app.
* `FoldableScaffold.dividerBuilder`, to replace the handle with any widget. It gets a `FoldableDividerState` (`isHovering`, `isDragging`, `isFocused`, `atFold`, `axis`, `textDirection`); dragging, the cursor, the keyboard, the focus and the semantics stay with the scaffold.
* The divider is now focusable, in the tab order, and shows the focus. The arrow keys move it by `dividerKeyboardStep` (16 by default, four times as much with Shift), following the text direction like a drag does, Home and End put it at the edges of its range (and snap it like a released drag), and the width stays within `minBodySize`. Standard `Shortcuts`/`Actions`/`Intent`, no raw key handling.
* The divider is a slider for screen readers: it is labelled (`dividerSemanticLabel`, "Resize panes" by default), gives the share of the pane area the secondary pane takes, and its increase and decrease actions move it by one keyboard step. Around a hinge, and in a one-pane layout, it is not focusable and has no semantics.
* `FoldableScaffoldController` (and `FoldableScaffold.of`/`.maybeOf`): reads `secondaryWidth`, `isSplit` and `isDraggingDivider`, and provides `setSecondaryWidth` (clamped like a drag, snapped on request) and `resetDivider`. The controller given to the scaffold is not disposed by it; the one the scaffold makes is, and `of`/`maybeOf` find it. It does not open or close the secondary body.
* State restoration of the divider: with `restorationId`, the divider position and whether the user placed it survive the app being restarted. The data lives under `'${restorationId}_panes'`, in a scope of its own, so it does not collide with the `restorationId` that the underlying `Scaffold` claims.

Internal:

* `FoldableScaffoldController.attach`, `detach` and `update` are `@internal` (from `package:meta`, a new dependency): they are for the scaffold, not part of the API of an app.
* The divider metrics are no longer stored while building: they are computed with the layout and published with the controller state after the frame. The controller is told only when `secondaryWidth`, `isSplit`, `isDraggingDivider` or the divider range changed, so a frame that changes none of them queues no callback.
* Fixed an unresolved dartdoc reference on `followFold`.
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
