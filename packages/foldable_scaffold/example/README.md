# foldable_scaffold_example

A mail app on a `FoldableScaffold`: a list in the body, the message in the
secondary body, a navigation rail or bar, and a draggable divider.

```sh
flutter run
```

Resize the window to see the layout change. The fold button in the app bar
pretends the device has a fold, so you can see how the panes follow it without a
foldable:

* **Hinge (two screens)** and **Fold, half open**: one pane on each side, at any
  width. The divider cannot be dragged.
* **Fold, flat**: the divider starts on the crease and can be dragged away. On a
  desktop window this needs "Phone and tablet rules" (two panes from 600 wide).

The card at the top of the list says what the scaffold decided.
