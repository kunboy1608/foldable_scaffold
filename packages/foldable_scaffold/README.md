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

| Available width | What is shown |
| --- | --- |
| < 600 | one pane, `bottomNavigationBuilder` |
| 600 – 1200 | one pane, `primaryNavigationBuilder` on the left |
| > 1200 | body and secondary body side by side, with a draggable divider |

* In a single-pane layout the secondary body replaces the body. Set
  `focusOnPrimaryBody` to keep the body when the secondary body is open.
* A pane narrower than `minBodySize` collapses into the other one.
* Switching the one visible pane is instant while `paneTransition` is true, so
  a page slide does not run a pane resize on top of it.
  `FoldablePaneTransitionScope` provides that signal automatically when a
  `FoldableNavigator` builds the scaffold.

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
