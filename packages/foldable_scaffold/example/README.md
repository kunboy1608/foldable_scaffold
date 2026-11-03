# foldable_scaffold_example

A mail app on a `FoldableScaffold` that uses everything the package does: a
list in the body, the message in the secondary body, a navigation rail or bar, a
draggable divider, and the usual `Scaffold` slots.

```sh
flutter run
```

## Layout

Resize the window to see the layout change: one pane in a narrow window, both
in a wide one (1200 on desktop, 600 on the inner screen of a foldable or a
tablet). The card at the top of the list says what the scaffold decided.

## Folds

The fold button in the app bar pretends the device has a fold, so you can see
how the panes follow it without a foldable:

* **Hinge (two screens)** and **Fold, half open**: one pane on each side, at any
  width. The divider cannot be dragged.
* **Fold, flat**: the divider starts on the crease and can be dragged away. On a
  desktop window this needs "Phone and tablet rules" (two panes from 600 wide).

## Layout options

The tune button in the app bar opens the end drawer, where every setting of the
scaffold can be changed while the panes are on screen:

* **Snap** (`snapWidths`): release the divider near 360 or 412 and a pane snaps
  to it.
* **`focusOnPrimaryBody`**, **`followFold`** and **`breakpoints`** (two panes from
  840).
* **`minBodySize`** and **`dividerSize`**.
* **Slow motion** (`FoldableMotion`).

## Scaffold slots

* `drawer`: the menu button of the app bar, with the mailboxes.
* `floatingActionButton` and `bottomSheet`: Compose opens a composer in the
  bottom sheet.
* `onSecondBodyClose`: the system back closes the message first.
