# foldable_scaffold

> [!WARNING]
> **Experimental.** This is a prerelease (`0.1.0-dev.4`). The API will change
> without notice and the package is not ready for production use.

A [Scaffold](https://pub.dev/documentation/material_ui/latest/material_ui/Scaffold-class.html)
with two panes, for foldables, tablets and desktop windows.

The scaffold only takes care of the layout: you fill the panes with anything
you like. [`foldable_router`](../foldable_router) puts a page stack in them,
but a `FoldableScaffold` works on its own.

## Install

```sh
flutter pub add foldable_scaffold:^0.1.0-dev.4
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
| 600 and above | `primaryNavigation` on the left | `primaryNavigation` on the left |
| two panes | from 600, if the window is at least 600 on its **short** side | from 1200 |

| Scaffold width | Handheld | Desktop |
| --- | --- | --- |
| < 600 | one pane, `bottomNavigationBar` | one pane, `bottomNavigationBar` |
| 600 and above | `primaryNavigation` on the start side | `primaryNavigation` on the start side |
| two panes | from 600, if the window is at least 600 on its **short** side | from 1200 |

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
| iPhone Fold, open (not released, sizes are leaks) | about 640 x 904 | two |
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

On Android, a device with a vertical fold or hinge (a Galaxy Z Fold, a Pixel
Fold, a dual-screen device) reports it in `MediaQuery.displayFeatures`. The
scaffold reads it, as `FoldableFold`, and places the panes around it:

| The device reports | What the scaffold does |
| --- | --- |
| A **hinge** (two screens) | body on one screen, secondary body on the other, whatever the width. The hinge area stays empty and is not a handle. |
| A **half-open fold** (book posture) | the same: one pane on each side of the fold. |
| A **flat fold** (fully open) | the content crosses the crease. Two panes still follow `breakpoints`, and the divider *starts* on the crease. The user can drag it away. |
| Nothing (a phone, a tablet, desktop, web) | nothing changes. |

Folding or unfolding the device moves the divider back to the crease. A fold
needs room: each side must be at least `minBodySize` wide, or the usual rules
apply. Horizontal folds (laptop or tabletop posture) and cutouts are ignored.

```dart
FoldableScaffold(
  followFold: true, // the default; false ignores the fold
  // ...
)

// In a pane, to adapt your own content:
final fold = FoldableFold.maybeOf(context);
if (fold != null && fold.isSeparating) {
  // Keep text and buttons off the hinge area: fold.bounds.
}
```

The fold is in window coordinates, so it only applies to a scaffold as wide as
the window. iOS and the web report no folds; there the width rules above are all
that decide.

To try it without a foldable, run the [example](example/lib/main.dart): the
fold button in its app bar pretends the device has a hinge or a fold. In your
own app, `foldable_dev_tools` has the same switch.

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
