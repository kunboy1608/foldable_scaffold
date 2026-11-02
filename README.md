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
