# foldable_router_example

Example app for [foldable_router](../README.md): a tabbed home drawn by a
`FoldableShellRoute`, with every way to navigate (`push`, `open`,
`openLocation`, `batch`, `popUntil`, redirects), swipe back and deep links.

Its route tree also has full-screen siblings of the shell — `CheckoutRoute`
(`/checkout`) and `AboutRoute` (`/about`) — plain top-level routes that cover
the tabs when opened and return to them on back.

```sh
flutter run
```
