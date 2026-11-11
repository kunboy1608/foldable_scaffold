# foldable_router

A small Navigation 2.0 router for Flutter. Routes are plain Dart classes, their
constructor fields are the parameters, and guards are (optionally async)
`redirect` methods. No code generation, no dependencies beyond Flutter.

## Usage

Declare routes by subclassing `FoldableRoute`. Paths are static; parameters
travel in the query string (`/users/detail?id=7`).

```dart
class UsersRoute extends FoldableRoute {
  const UsersRoute();

  @override
  String get path => '/users';

  @override
  Widget build(BuildContext context) => const UsersPage();
}

class UserRoute extends FoldableRoute {
  const UserRoute({required this.id});

  final String id;

  @override
  String get path => '/users/detail';

  @override
  Map<String, String?> get params => {'id': id};

  @override
  FoldableRoute? get parent => const UsersRoute();

  @override
  FutureOr<FoldableRoute?> redirect(RouteState state) async =>
      await auth.isSignedIn() ? null : const LoginRoute();

  @override
  Widget build(BuildContext context) => UserPage(id: id);
}
```

Create the router. The `routes` table turns a URL (deep link, web address bar)
back into a route instance:

```dart
final router = FoldableRouter(
  initial: const HomeRoute(),
  routes: {
    '/users': (params) => const UsersRoute(),
    '/users/detail': (params) => UserRoute(id: params['id']!),
    '/login': (params) => const LoginRoute(),
  },
  notFoundBuilder: (context, uri) => NotFoundPage(uri: uri),
  pendingBuilder: (context) => const SplashPage(), // optional
);

void main() => runApp(MaterialApp.router(routerConfig: router.routerConfig));
```

Navigate:

```dart
// Replaces the stack with the parent chain: [UsersRoute, UserRoute].
await router.open(const UserRoute(id: '7'));

// Adds exactly one page and waits for its result.
final picked = await router.push<String>(const UserRoute(id: '7'));
router.pop('result'); // or FoldableRouter.of(context).pop('result')

// Re-run the redirects of the current stack, e.g. after sign-out.
await router.refresh();
```

Observe the stack. The router is a `Listenable` that notifies whenever
`router.stack` / `router.location` change. `FoldableRouter.of(context)` does
not rebuild the calling widget on such a change, so listen explicitly:

```dart
ListenableBuilder(
  listenable: router,
  builder: (context, _) => Text(
    // location: URI of the top page (what the address bar shows), the
    // unknown URI on the not-found page, null before the first navigation.
    '${router.location}  (${router.stack.length} pages)',
  ),
);
```

Go from a URI to a route, with the same lookup as deep links:

```dart
// null when the path is not in `routes` or the factory throws.
final route = router.routeFor(Uri.parse('/users/detail?id=7'));

// Like a URL from the platform: opens the route (redirects apply) or shows
// notFoundBuilder. Errors come through the future, as for `open`.
await router.openUri(Uri.parse('/users/detail?id=7'));
```

A runnable demo of all of the above lives in [`example/`](example/) (`cd example && fvm flutter run -d chrome`).

## Behaviour

- **Redirects** run one after another from the root ancestor down to the
  target. The first one returning a route restarts the navigation with that
  route. More than `maxRedirects` (default 5) consecutive redirects, or a
  target visited twice, fail with a `FoldableRedirectException`.
- While redirects are pending the current page stays on screen and
  `router.isNavigating` is `true`. On first launch `pendingBuilder` is shown.
- **Latest navigation wins**: a navigation that is still pending when a newer
  one starts is discarded.
- If a `redirect` throws, the navigation is cancelled, the stack is unchanged
  and the future returned by `open` / `push` completes with the error.
- `pop` on the last page does nothing; the system back button then leaves
  the app.
- The URL reflects the top page only. A URL not found in `routes`, or whose
  factory throws (for example a missing required parameter), shows
  `notFoundBuilder`. A trailing slash is ignored, and the URI of `initial`
  always resolves to `initial`, which therefore needs no entry in `routes`.
- Listeners of the router are called only when `stack` / `location` actually
  change: not for a `refresh` without redirect, a `pop` on the last page, or a
  discarded or failed navigation.
- There is no automatic refresh; call `refresh()` when the state your
  redirects depend on changes.
