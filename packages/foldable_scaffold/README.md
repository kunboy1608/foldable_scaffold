# foldable_scaffold

> [!WARNING]
> **Experimental.** This is a prerelease (`0.1.0-dev.6`). The API will change
> without notice and the package is not ready for production use.

A [Scaffold](https://pub.dev/documentation/material_ui/latest/material_ui/Scaffold-class.html)
with two panes, for foldables, tablets and desktop windows.

The scaffold only takes care of the layout: you fill the panes with anything
you like. [`foldable_router`](../foldable_router) puts a page stack in them,
but a `FoldableScaffold` works on its own.

## Install

```sh
flutter pub add foldable_scaffold:^0.1.0-dev.6
```

## Usage

```dart
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:material_ui/material_ui.dart';

class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  String? _message;

  @override
  Widget build(BuildContext context) {
    return FoldableScaffold(
      appBar: AppBar(title: const Text('Mail')),
      primaryNavigation: NavigationRail(/* ... */),
      bottomNavigationBar: NavigationBar(/* ... */),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Hello'),
            onTap: () => setState(() => _message = 'Hello'),
          ),
        ],
      ),
      // Passing a secondary body is enough to show the second pane.
      hasSecondaryBody: _message != null,
      secondaryBody: Center(child: Text(_message ?? '')),
      // hasSecondaryBody: false hides the pane and keeps the widget.
      onSecondBodyClose: (didPop, _) => setState(() => _message = null),
    );
  }
}
```

### Widgets or builders

The slots take a widget, as `Scaffold` does: `body`, `secondaryBody`, `appBar`,
`primaryNavigation` and `bottomNavigationBar`. Each one also has a builder for
the widgets that need the constraints of the slot: `bodyBuilder`,
`secondaryBodyBuilder`, `appBarBuilder`, `primaryNavigationBuilder` and
`bottomNavigationBarBuilder`. A slot takes one or the other, not both.

Use a builder when the content depends on the width of the pane, which changes
while the divider is dragged:

```dart
FoldableScaffold(
  body: const MessageList(),
  secondaryBodyBuilder: (context, constraints) => Text(
    'This pane is ${constraints.maxWidth.round()} wide.',
  ),
)
```

A builder may return null, which leaves the pane empty. That never changes the
layout: whether there is a second pane is decided by `secondaryBody` (or
`secondaryBodyBuilder`) and `hasSecondaryBody`, not by what the builder returns.

### The hidden pane

A pane that is not on screen (one-pane layouts, `hasSecondaryBody: false`, or a
pane that collapsed into the other one) is never taken out of the widget tree.
Its widgets stay mounted, so a page stack, a scroll position or text being typed
is still there when the pane comes back, and it comes back instantly with
nothing jumping.

While it has no width, though, nothing of it is seen or reachable: it does not
take focus (Tab or a screen reader), it is left out of the semantics tree, it
does not take pointer events, and its tickers (animations) are muted. This only
kicks in once the pane has actually collapsed to zero width: a pane that is
sliding in or out still has a non-zero width and stays fully live, so the page
slides of `FoldableNavigator` are never cut short.

## Layout rules

The width at which the scaffold changes layout depends on the platform. Android
and iOS (also in a mobile browser) are *handheld*, everything else is *desktop*.

| Scaffold width | Handheld | Desktop |
| --- | --- | --- |
| < 600 | one pane, `bottomNavigationBar` | one pane, `bottomNavigationBar` |
| 600 and above | `primaryNavigation` on the start side | `primaryNavigation` on the start side |
| two panes | from 600, if the window is at least 600 on its **short** side | from 1200 |

### Where the navigation goes

The navigation can be below the panes, above them, or beside them, on either
side. Where it goes is decided by a function, the *placement resolver*, so each
platform and each device can have its own rule. By default, that is
`defaultNavigationPlacement`, which is the table above: a bar below the panes
under 600, a rail on the start side from 600. It is exported, so a custom
resolver can start from it and change only the cases it cares about:

```dart
FoldableScaffold(
  navigationPlacement: (info) => info.scaffoldHeight < 400
      ? const FoldableNavigationPlacement.end() // short and wide: on the side
      : defaultNavigationPlacement(info),
  navigationBuilder: (context, placement, constraints, padding) =>
      placement.isSide
      ? NavigationRail(/* ... */)
      : NavigationBar(/* ... */),
  // ...
)
```

`FoldableLayoutInfo` has what a resolver can use: the size of the scaffold and
of the window, the platform, the text direction, the system insets, the
breakpoints, the fold, whether there is a secondary body, and the side where the
platform wants vertical bars. A resolver must not depend on the navigation
itself (its size or content): the room it leaves is what the panes share.

| `FoldableNavigationPlacement` | Where |
| --- | --- |
| `.bottom()` | below the panes, in `Scaffold.bottomNavigationBar`: the floating action button, `extendBody` and the insets work as usual |
| `.top()` | above the panes, under the app bar |
| `.start({extent})`, `.end({extent})` | beside the panes, on the start or end side of the text direction |
| `.left({extent})`, `.right({extent})` | beside the panes, on the physical left or right edge, whatever the text direction |
| `.none()` | no navigation |

`extent` is how wide a side navigation is, without the system inset on its side
(which the scaffold adds). Without it, it is `minWidthNavigation` (72), or
`maxWidthNavigation` (192) above 1000.

`navigationBuilder` makes the navigation for whichever placement the resolver
chose, so one widget can be a `NavigationBar` or a `NavigationRail`. The slots
`primaryNavigation` and `bottomNavigationBar` stay for the usual case:
`primaryNavigation` is shown when the placement is a side, and
`bottomNavigationBar` when it is the bottom or the top. A `navigationBuilder`
and these slots cannot be passed together. The navigation is a different widget
on each edge, so its state does not move with it: keep the selected tab in your
own state.

`foldable_scaffold` has a resolver for each platform
(`FoldableNavigationPlacements.handheld` for Android and iOS, `.desktop` for the
others, `.forPlatform(platform)`). Today they agree, but a platform can now
differ without touching the others.

#### iPhone Duo

On iPhone Duo, the system puts navigation bars, toolbars and tab bars on the
side of the display: always on the outer display, and in some poses of the
inner one (the inner display in portrait keeps the bars on the top and the
bottom). It decides which side, which can follow the language or the hardware,
and tells an iOS app with the `verticalBarEdge` trait in UIKit or the
`toolbarVerticalEdge` environment value in SwiftUI, so the width alone cannot
tell. Flutter does not expose that value yet. The easy way is
[`FoldablePlatformScope`](#iphone-duo-the-platform-bridge), which reads it on
iOS and provides it. To provide it yourself (from your own platform code, or
to test), use `FoldableVerticalBarScope`:

```dart
FoldableVerticalBarScope(
  edge: edgeFromThePlatform, // null when the system wants no vertical bar
  child: MaterialApp(/* ... */),
)
```

The default placement then puts the navigation on that side, whatever the
width: `start` and `end` follow the text direction, `left` and `right` do not.
With no scope, or a null edge, nothing changes. On iPhone Duo, the system also
moves the app bar and the toolbar to the side; the scaffold's app bar stays on
top, so for that case give `appBarBuilder` your own layout.

### iPhone Duo: the platform bridge

Flutter does not put the hinge, the cameras or the side of the vertical bars of
iPhone Duo in `MediaQuery`: that data exists only in UIKit (iOS 27.1 and later:
`UIView.ReservedRegion` and `UITraitCollection.verticalBarEdge`). This package is
also a Flutter plugin with an iOS part (and only an iOS part: every other
platform has no native code and uses the package as plain Dart) that reads it,
and `FoldablePlatformScope` hands it to your tree.

```dart
MaterialApp(
  builder: (context, child) => FoldablePlatformScope(child: child!),
  home: const MyHome(),
)
```

Put it **below the `WidgetsApp`**, in `MaterialApp.builder` (or the `builder` of
`CupertinoApp` or `WidgetsApp`): `WidgetsApp` makes its own `MediaQuery`, which
would replace one made above it. If the builder also rewrites
`MediaQuery.displayFeatures` (a fold simulator, like the example's), put that
below the scope to override the platform, or above it to merge. On every
platform but iOS (and on the web) the widget returns its child untouched and
never uses the channel.

On iOS, the scope:

* adds to `MediaQuery.displayFeatures` the **active** reserved regions, merged
  with the features Flutter already reported and without duplicates. A division
  (the hinge) becomes a `DisplayFeatureType.fold` in
  `DisplayFeatureState.postureHalfOpened`: a vertical one is a book, a
  horizontal one a laptop, and `FoldableScaffold` side by side or stacks the
  panes as it does for any other fold. An occlusion (outer or inner camera,
  Dynamic Island) becomes a `DisplayFeatureType.cutout` with
  `DisplayFeatureState.unknown`.
* provides `FoldableVerticalBarScope`: `leading` is `FoldableNavigationEdge.start`,
  `trailing` is `end`, `unspecified` is null.
* gives the whole `FoldablePlatformState` to `FoldablePlatformScope.maybeOf`,
  including the **inactive** regions (a division that is not active because the
  device is fully open; the inner camera while it is off), with their frames.
  Inactive regions are not display features, because they do not affect the
  layout now; read them from the state to leave room for them.

The numbers are in logical pixels (points are logical pixels on iOS) and in the
coordinates of the Flutter view, which is the window when the view covers it.

**Minimum iOS.** The plugin supports iOS 15 and later (the deployment target of the pod and of the Swift package), which is what the App Store requires.

**Xcode.** The plugin names APIs that exist only in the iOS 27.1 SDK, so an
iOS app that depends on `foldable_scaffold` has to be built with an Xcode that
has that SDK (the one that can build for iPhone Duo). An older Xcode fails to
compile the plugin, even for an app that does not care about iPhone Duo. On a
device or simulator with an iOS older than 27.1 the code does not run
(`#available(iOS 27.1, *)`): the plugin answers with no regions and a
`verticalBarEdge` of `unspecified`, so `FoldablePlatformScope` changes nothing.

**How changes are found.** The plugin does not swizzle anything and does not
subclass `FlutterViewController`. While Dart listens it watches the bounds of
the Flutter view and compares the state on a display link at 10 frames per
second (paused in the background), and sends an event only when the data really
changed. It stops when the last listener is gone. Dart also asks for the state
whenever the window metrics change.

**Known limits, and what has not been verified.**

* The Swift code and the podspec have **not been compiled or run**: they were
  written on Linux, from the Apple documentation. They need a check in Xcode
  with the iOS 27.1 SDK.
* The 10 fps display link is a guess. If the system re-evaluates the regions in
  a way that only `updateConstraints` sees, there can be a delay of up to a
  tenth of a second.
* The plugin reads the view of the engine's `FlutterViewController`
  (`FlutterPluginRegistrar.viewController`), the single-view API: a Flutter view
  that does not cover its window (a view in a part of the screen, an
  add-to-app host) reports regions in its own coordinates, which is what the
  frames mean, but nothing was tested there. Several windows or scenes (the
  multi-display features of iPhone Duo) are not handled specially.
* The app bar and the toolbar that the system moves to the side are not
  replaced: only the navigation is.
* The numbers of the real device are still to be measured: see the table of
  device profiles under [Folds and hinges](#folds-and-hinges).

To read what the platform reports (in the simulator, for instance), the
[example](example/lib/main.dart) has a button in its app bar that shows the
data live, and prints it with `debugPrint` each time it changes.

### Text direction

The layout follows the `TextDirection` of the closest `Directionality`
(usually set by the `Localizations`/`MaterialApp` locale):

* In `TextDirection.ltr` (the default) the rail is on the left edge, the body
  is left of the secondary body, and dragging the divider right shrinks the
  secondary body.
* In `TextDirection.rtl` everything is mirrored: the rail is on the right
  edge, the secondary body is on the left and the body on the right, and
  dragging the divider left shrinks the secondary body. The system inset on
  the start side is added to the rail width, and the pane's `MediaQuery`
  clears that inset instead.

The fold or hinge coordinates stay in physical window coordinates
(left → right); the scaffold mirrors them internally, so a separating hinge
still puts one pane on each side with the hinge area in the middle.

On a handheld, body and secondary body are shown side by side, with a draggable
divider, on the inner screen of a foldable (a Galaxy Z Fold, an unfolded iPhone
Fold) and on a tablet. A phone keeps one pane in either orientation: it is never
more than about 480 on its short side. A narrow window, such as half a tablet in
multi-window, keeps one pane too.

| Device | Window (logical size) | Panes |
| --- | --- | --- |
| Phone | 360 x 800 to 440 x 956, also sideways | one |
| Galaxy Z Fold8, folded | about 411 x 960 | one |
| Galaxy Z Fold8, open | about 635 x 841 | two |
| Galaxy Z Fold8 Ultra, open | about 740 x 822 | two |
| iPhone Duo, open (sizes are not official) | about 640 x 904 | two |
| Tablet | 800 x 1280 | two |
| Desktop window | 1200 and wider | two |

The sizes of the foldables are worked out from their published pixel counts and
densities: check them on your device by printing `MediaQuery.sizeOf(context)`.

Override the default with `breakpoints`:

```dart
FoldableScaffold(
  // Split from 840 wide, on any platform and whatever the height.
  breakpoints: const FoldableBreakpoints(split: 840),
  // ...
)

// Or start from one of the two presets.
breakpoints: const FoldableBreakpoints.handheld(split: 700),
```

* In a single-pane layout the secondary body replaces the body. Set
  `focusOnPrimaryBody` to keep the body when the secondary body is open.
* The divider stops where either pane would get narrower than `minBodySize`.
  A pane that still ends up narrower than `minBodySize`, because the available
  width cannot hold two of them, collapses into the other one.
* Switching the one visible pane is instant while `paneTransition` is true, so
  a page slide does not run a pane resize on top of it.
  `FoldablePaneTransitionScope` provides that signal automatically when a
  `FoldableNavigator` builds the scaffold.

## Insets

The panes get the `MediaQuery` that the `Scaffold` makes for its body, so a
`ListView`, a `SafeArea` or a nested `Scaffold` in a pane pads the right way:

| | `MediaQuery.padding.bottom` in a pane |
| --- | --- |
| `bottomNavigationBar` on screen, `extendBody: true` | the height of the bar: the pane runs under it, pad the end of the content |
| `bottomNavigationBar` on screen, `extendBody: false` (the default) | 0: the pane ends above the bar |
| no bar on screen (the rail replaces it, or no bar) | the system inset |

The top inset is taken by the app bar (`appBar`), and the start-side inset
(the left one in LTR, the right one in RTL)
by the rail. With the keyboard open the body is resized, and the panes see no
`viewInsets`, so a `Scaffold` in a pane does not shrink a second time.

## Resizing the panes

The divider is dragged. With `snapWidths` it snaps to set widths when it is
released, like the
[M3 pane handle](https://m3.material.io/foundations/layout/scaffold/panes):

```dart
FoldableScaffold(
  // Snap to these widths when the divider is released, if a pane is within
  // snapThreshold (32) of one. Either pane can be the one that snaps.
  snapWidths: const [360, 412],
  // ...
)
```

Around a hinge the divider is not a handle, and snapping does not apply.

## Theming

The divider is themed with `FoldableScaffoldThemeData`, a `ThemeExtension`: put
it in the `ThemeData` of the app to style every divider below it. Every field is
optional, and a field left null keeps the look the divider always had.

```dart
MaterialApp(
  theme: ThemeData(
    extensions: const [
      FoldableScaffoldThemeData(
        dividerColor: Colors.black26, // the handle at rest
        dividerActiveColor: Colors.teal, // hovered, dragged or focused
        dividerBackgroundColor: Colors.white, // the divider slot
        handleSize: Size(6, 64),
        handleActiveWidth: 16,
        handleBorderRadius: BorderRadius.all(Radius.circular(3)),
        animationDuration: Duration(milliseconds: 150),
      ),
    ],
  ),
  // ...
)
```

`FoldableScaffold.theme` overrides it for one scaffold: a field that the
scaffold sets wins over the one of the `ThemeData`, and a field that is null in
both is defaulted. The defaults are the ones the divider always had: a 4 x 50
handle, 12 wide when it is active, a pill of `ThemeData.dividerColor` that turns
`ColorScheme.primary`, on the `scaffoldBackgroundColor`.

## Custom divider

`dividerBuilder` replaces the handle, and nothing else: the scaffold keeps
dragging it, sets the resize cursor, runs the keyboard shortcuts and gives it
the focus and the semantics.

```dart
FoldableScaffold(
  dividerBuilder: (context, state) => Icon(
    state.isDragging ? Icons.drag_handle : Icons.drag_indicator,
    color: state.isFocused ? Theme.of(context).colorScheme.primary : null,
  ),
  // ...
)
```

`FoldableDividerState` says whether the divider is `isHovering`, `isDragging`
and `isFocused`, whether it is `atFold` (a builder is not called then, as there
is no handle), and the `textDirection` and `axis` of the divider.

## Keyboard and screen readers

The divider takes the keyboard focus, in the tab order, whenever it is a handle
(not around a hinge, not in a one-pane layout), and the default handle shows the
focus.

| Key | What it does |
| --- | --- |
| Left / Right arrow | Move the divider by `dividerKeyboardStep` (16 by default), so the secondary pane shrinks or grows, following the text direction exactly like a drag does |
| Shift + arrow | The same, four steps at once |
| Home / End | The smallest, or the largest, the secondary pane can be, then snapped like a released drag |

The width stays within `minBodySize` and the room the divider has; the arrow keys
do not snap to `snapWidths`.

A screen reader reads the divider as a slider, labelled `dividerSemanticLabel`
("Resize panes"), valued with the share of the pane area the secondary pane
takes, and its increase and decrease actions move the divider by one step.

## Controller

```dart
class _MailScreenState extends State<MailScreen> {
  final _controller = FoldableScaffoldController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: FoldableScaffold(
          controller: _controller,
          body: const MessageList(),
          secondaryBody: const Message(),
        ),
      ),
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => TextButton(
          onPressed: _controller.resetDivider,
          child: Text('Secondary pane: ${_controller.secondaryWidth?.round()}'),
        ),
      ),
    ],
  );
}
```

The controller tells where the divider is (`secondaryWidth`, null while there is
one pane, `isSplit`, `isDraggingDivider`), moves it (`setSecondaryWidth`, clamped
like a drag and snapped to `snapWidths` when asked) and puts it back where it
starts (`resetDivider`: the middle, or the crease of a flat fold).

It does not open or close the secondary body: `secondaryBody` and
`hasSecondaryBody` (and the width of the scaffold) decide that, not the divider.
A controller that is passed belongs to the widget that created it, which disposes
it; the scaffold only disposes the one it made. `FoldableScaffold.of(context)`
and `FoldableScaffold.maybeOf(context)` find the controller of the closest
scaffold above, the one that was passed or the one the scaffold made, the way
`Scaffold.of` finds a scaffold.

## State restoration

With `restorationId`, the position of the divider, and whether the user placed
it, are restored with the rest of the app state:

```dart
FoldableScaffold(
  restorationId: 'mail',
  // ...
)
```

The divider keeps its data under an id of its own, `'mail_panes'`, in a scope of
its own, so it does not collide with the `'mail'` that the underlying `Scaffold`
claims. Without a `restorationId` nothing is restored, as before.

## Other Scaffold slots

`floatingActionButton`, `floatingActionButtonLocation`,
`floatingActionButtonAnimator`, `persistentFooterButtons`,
`persistentFooterAlignment`, `persistentFooterDecoration`, `drawer`,
`onDrawerChanged`, `endDrawer`, `onEndDrawerChanged`, `bottomSheet`,
`backgroundColor`, `resizeToAvoidBottomInset`, `primary`,
`drawerDragStartBehavior`, `drawerScrimColor`, `drawerEdgeDragWidth`,
`drawerEnableOpenDragGesture`, `endDrawerEnableOpenDragGesture` and
`restorationId` and `drawerBarrierDismissible` go to the underlying `Scaffold`, with the same names and
defaults as `Scaffold` (so `extendBody` defaults to `false`). They span the
whole scaffold, rail and both panes.

Two slots are not forwarded because `FoldableScaffold` manages them itself:
`appBar`/`bottomNavigationBar` (use the `appBar` and `bottomNavigationBar`
arguments above) and `body` (the two panes). `bottomSheetScrimBuilder` is not
forwarded either, because `Scaffold`'s default for it is private.

## Folds and hinges

A device with a fold or hinge (a Galaxy Z Fold, a Pixel Fold, a dual-screen
device such as iPhone Duo) reports it in `MediaQuery.displayFeatures`. The
scaffold reads it, as `FoldableFold`, and places the panes around it. A fold
has a direction (`FoldableFold.axis`): a **vertical** one runs from the top to
the bottom of the window and has a pane on its left and on its right (the book
posture, or a dual-screen device in landscape); a **horizontal** one runs across
the window and has a pane above it and one below it (the tabletop posture, or a
dual-screen device in portrait).

| The device reports | What the scaffold does |
| --- | --- |
| A **vertical hinge** (two screens side by side) | body on one screen, secondary body on the other (left and right, mirrored in RTL), whatever the width. The hinge area stays empty and is not a handle. |
| A **vertical half-open fold** (book posture) | the same: one pane on each side of the fold. |
| A **horizontal hinge** (two screens, one above the other) | the panes are stacked: **body above, secondary body below**, whatever the width and the text direction. The hinge area stays empty and is not a handle. |
| A **horizontal half-open fold** (tabletop or laptop posture) | the same: body above the fold, secondary body below it. |
| A **flat vertical fold** (fully open) | the content crosses the crease. Two panes still follow `breakpoints`, and the divider *starts* on the crease. The user can drag it away. |
| A **flat horizontal fold** (fully open) | ignored, like a cutout: the width decides the layout as if there were no fold. |
| Nothing (a phone, a tablet, desktop, web) | nothing changes. |

Only a fold that *separates* the screen (a hinge, or a half-open fold) changes
the layout around a horizontal fold. The rules:

* **Room.** Stacking needs a secondary body to show (`hasSecondaryBody`) and
  both halves at least `minBodySize` **tall**: `minBodySize` is the minimum
  height as well as the minimum width. A vertical fold needs it wide. Without
  room the usual rules apply.
* **Under the app bar and the navigation.** The fold is in window coordinates,
  but the panes start below the app bar, the navigation above them and the system
  inset, and end above the navigation below them, whose sizes are up to your
  widgets. The scaffold measures where the pane area really is after layout and
  subtracts it, so the hinge is where it is on the device whatever you put
  around the panes. The scaffold must cover the height of the window for this
  (and the width of it for a vertical fold): a scaffold inside something
  smaller ignores the fold of that direction.
* **More than one fold.** The first fold of `displayFeatures` that applies wins,
  except that a flat vertical fold gives way to a separating horizontal one
  (`FoldableFold.fromFeatures`).
* **Drag and controller.** Around any hinge the divider is the hinge: it is not
  a handle, takes no focus and has no semantics, `setSecondaryWidth` and
  `resetDivider` do nothing. While the panes are stacked,
  `FoldableScaffoldController.isSplit` is true, `isStacked` is true and `axis`
  is `Axis.vertical`; `secondaryWidth` is the width of the pane area.
  `FoldablePaneLayout.axis` tells the widgets in the panes the same.
* **Animation.** Moving a pane between side by side and stacked does not
  animate (a width does not turn into a height): the panes are in their new place
  at once. Moving the hinge within the stacked layout animates as usual.
* **Insets.** Stacked, the pane above has no bottom inset in its `MediaQuery`
  and the one below has no top inset: neither has the other side's.

Folding or unfolding a vertical fold moves the divider back to the crease. Cutouts
are ignored.

```dart
FoldableScaffold(
  followFold: true, // the default; false ignores the fold
  // ...
)

// In a pane, to adapt your own content:
final fold = FoldableFold.maybeOf(context);
if (fold != null && fold.isSeparating) {
  // Keep text and buttons off the hinge area: fold.bounds.
  // fold.isHorizontal: the panes are above and below it.
}
```

One frame can be seen differently on the first launch: with a horizontal hinge
there is no measure of the pane area yet, so the scaffold lays the panes out from
an estimate and does not paint them for that first frame, then shows them in the
right place. Later changes of posture show the right layout at once. Opening the
keyboard (which shrinks the pane area) can leave the lower half too short to
stack: the usual rules apply then.

The numbers of real devices, to test the layout against, go in
[`test/foldable_scaffold_device_profiles_test.dart`](test/foldable_scaffold_device_profiles_test.dart):
a table of sizes and display features (iPhone Duo's displays and poses, still to
be filled in from the Device Hub of Xcode) whose tests run once a profile has its
numbers.

The fold is in window coordinates. iOS (except dual-screen devices such as
iPhone Duo, through [`FoldablePlatformScope`](#iphone-duo-the-platform-bridge))
and the web report no folds; there the width rules
above are all that decide.

To try it without a foldable, run the [example](example/lib/main.dart): the
fold button in its app bar pretends the device has a hinge or a fold, vertical
or horizontal. In your own app, `foldable_dev_tools` has the same switch.

## Exposing the layout to the panes

`FoldablePaneLayout` (and `FoldableScaffoldScope.canSplit`) is an
`InheritedWidget` below the scaffold, so the widgets in the panes can ask what
is visible:

```dart
final layout = FoldablePaneLayout.maybeOf(context);
if (layout?.secondaryVisible ?? false) {
  // The details pane is on screen.
}
```

## Animation speed

`FoldableMotion` scales every duration of the foldable widgets below it:

```dart
FoldableMotion(
  scale: (duration) => duration * 6, // slow motion
  child: FoldableScaffold(/* ... */),
)
```

## Example

Run [`example/`](example/lib/main.dart) for a two-pane mail app.
