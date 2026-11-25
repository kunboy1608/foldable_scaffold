# foldable_scaffold

Flutter packages for apps with two panes: foldables, tablets and desktop.

| Package | What it is |
|---|---|
| [foldable_scaffold](packages/foldable_scaffold) | Two-pane `Scaffold` with a resizable divider and animated pane switching. |
| [foldable_router](packages/foldable_router) | Router with one page stack per tab, swipe back, deep links, redirects and guards. |
| [foldable_dev_tools](packages/foldable_dev_tools) | In-app overlay to simulate window sizes, inspect panes and log navigation. |
| [foldable_core](packages/foldable_core) | Shared signals that let the scaffold and the router work together. |

`foldable_scaffold` and `foldable_router` do not depend on each other; both
build on `foldable_core`.

## Dùng cùng nhau

`foldable_scaffold` supplies the pane layout (breakpoints, divider, animated
switching) and `foldable_router` supplies the page stacks, one per tab. They
meet in the router's shell: the scaffold's `paneContent` publishes the pane
rectangles and the router places its pages in them.

```dart
import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';

class MailShellRoute extends FoldableShellRoute {
  const MailShellRoute();

  @override
  List<FoldableShellChildRoute> get branches => const [
    InboxRoute(),
    UsersRoute(),
    ProfileRoute(),
  ];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) {
    return FoldableScaffold(
      appBar: AppBar(title: const Text('Mail')),
      // The router places its pages in the rects the scaffold publishes.
      paneContent: (BuildContext context, FoldablePaneRects rects) =>
          shell.child,
      hasSecondaryBody: shell.hasSecondary,
      // Closing the secondary pane pops a full-screen overlay first, then the
      // top page of the branch.
      onSecondBodyClose: (bool didPop, Object? result) =>
          shell.closeSecondary?.call(),
      navigationBuilder: (BuildContext context,
          FoldableNavigationPlacement placement,
          BoxConstraints constraints,
          EdgeInsets padding) =>
          placement.isSide
              ? NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: shell.goBranch,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.inbox),
                      label: Text('Inbox'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people),
                      label: Text('Users'),
                    ),
                  ],
                )
              : NavigationBar(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: shell.goBranch,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
                    NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
                  ],
                ),
    );
  }
}

class InboxRoute extends FoldableShellChildRoute {
  const InboxRoute();

  @override
  String get segment => '';

  @override
  FoldableShellParent get parent => const MailShellRoute();

  @override
  Widget build(BuildContext context) => const InboxPage();
}

// UsersRoute / UserRoute ... same pattern.

void main() => runApp(MaterialApp.router(routerConfig: createRouter().routerConfig));
```

## Development

The repo is a Dart workspace managed with [melos](https://melos.invert.dev) and
[fvm](https://fvm.app).

```sh
fvm flutter pub get
fvm dart run melos run analyze
fvm dart run melos run test
```

## License

See [LICENSE](LICENSE).
