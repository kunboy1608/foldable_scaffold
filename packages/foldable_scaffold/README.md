# foldable_scaffold

A [Scaffold](https://pub.dev/documentation/material_ui/latest/material_ui/Scaffold-class.html)
with two panes, for foldables, tablets and desktop windows.

The scaffold only takes care of the layout: you fill the panes with anything
you like. [`foldable_router`](../foldable_router) puts a page stack in them,
but a `FoldableScaffold` works on its own.

## Install

```sh
flutter pub add foldable_scaffold
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
      topNavigationBuilder: (context, constraints) =>
          AppBar(title: const Text('Mail')),
      primaryNavigationBuilder: (context, constraints, padding) =>
          NavigationRail(/* ... */),
      bottomNavigationBuilder: (context, constraints) =>
          NavigationBar(/* ... */),
      bodyBuilder: (context, constraints) => ListView(
        children: [
          ListTile(
            title: const Text('Hello'),
            onTap: () => setState(() => _message = 'Hello'),
          ),
        ],
      ),
      hasSecondaryBody: _message != null,
      secondaryBodyBuilder: (context, constraints) =>
          Center(child: Text(_message ?? '')),
      // hasSecondaryBody: false hides the second pane. Without it, the scaffold
      // calls the builder an extra time to see whether it returns null.
      onSecondBodyClose: (didPop, _) => setState(() => _message = null),
    );
  }
}
```

## Layout rules

The width at which the scaffold changes layout depends on the platform. Android
and iOS (also in a mobile browser) are *handheld*, everything else is *desktop*.

| Scaffold width | Handheld | Desktop |
| --- | --- | --- |
| < 600 | one pane, `bottomNavigationBuilder` | one pane, `bottomNavigationBuilder` |
| 600 and above | `primaryNavigationBuilder` on the left | `primaryNavigationBuilder` on the left |
| two panes | from 600, if the window is at least 600 on its **short** side | from 1200 |

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
