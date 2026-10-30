# foldable_dev_tools

An in-app development overlay for
[`foldable_scaffold`](../foldable_scaffold) and
[`foldable_router`](../foldable_router).

Use it when you do not have a foldable on the desk: pretend the window is a
phone or an open foldable, draw a hinge, slow the animations down, and watch
what the router does.

## Install

```sh
flutter pub add foldable_dev_tools
```

## Usage

Wrap the app **inside** `MaterialApp.builder`, so the overlay can use the app's
theme:

```dart
MaterialApp(
  builder: (context, child) => FoldableDevTools(
    router: router, // optional, logs push/pop/go
    child: child!,
  ),
  // ...
)
```

A small bug button appears in the corner of the screen and opens the panel.

## What the panel does

* **Viewport**: presets (phone, large phone, foldable closed/open, tablet,
  laptop, desktop) and width/height sliders. The app is wrapped in a `SizedBox`
  and a `MediaQuery` override, so `LayoutBuilder`s (and `FoldableScaffold`)
  react exactly like a window resize.
* **Hinge**: draw a hinge over the simulated screen and move it.
* **Motion**: slow every pane and page animation down (`FoldableMotion`).
* **Panes**: the current mode (single body, single secondary, split), whether
  the scaffold can split, and the simulated size. Add a
  `FoldablePaneLayoutObserver` inside the scaffold to feed it:

  ```dart
  FoldableScaffold(
    bodyBuilder: (_, _) => Stack(
      children: [const FoldablePaneLayoutObserver(), body],
    ),
    // ...
  )
  ```

* **Navigation**: the last navigations with their URL, branch and stack depth.
  Add the router with `FoldableDevTools(router: router)` or
  `router.addObserver(controller)`.

## From code and tests

```dart
final controller = FoldableDevToolsController()
  ..viewport = FoldableViewport.foldableOpen
  ..showHinge = true
  ..slowMotion = true;

FoldableDevTools(controller: controller, router: router, child: app);
```

The controller has `isOpen`, `viewport`, `setViewportSize`, `showHinge`,
`hingePosition`, `slowMotion`, `pane`, `events` and `clearEvents`.

## Release safe

`FoldableDevTools` only shows the overlay in debug builds; in release it
returns its child unchanged, so it is safe to leave in `MaterialApp.builder`.

## Example

Run [`example/`](example/lib/main.dart).
