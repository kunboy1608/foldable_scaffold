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

## ShellRoute

A `FoldableShellRoute` puts a persistent frame (a bottom navigation bar, a
side rail, ...) in the middle of a parent chain. The shell is a normal link of
the chain: every route whose `parent` chain runs through it is shown *inside*
it, and each branch gets its own nested navigator, so each tab keeps its own
stack and page state.

```dart
class MainShellRoute extends FoldableShellRoute {
  const MainShellRoute();

  // The root route of each tab, in order. A route belongs to the branch
  // whose root is the element right below the shell in its parent chain.
  @override
  List<FoldableRoute> get branches => const [HomeRoute(), UsersRoute()];

  @override
  Widget buildShell(BuildContext context, FoldableShellState shell) =>
      Scaffold(
        body: shell.child, // the pages of the current branch
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: shell.goBranch,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
          ],
        ),
      );
}

class UsersRoute extends FoldableRoute {
  const UsersRoute();

  @override
  String get path => '/users';

  @override
  FoldableRoute? get parent => const MainShellRoute(); // this is the Users tab

  @override
  Widget build(BuildContext context) => const UsersPage();
}

class UserRoute extends FoldableRoute {
  // ...shown inside the Users tab: users -> detail.
  @override
  FoldableRoute? get parent => const UsersRoute();
}
```

Use the shell as `initial` (`FoldableRouter(initial: const MainShellRoute())`);
it needs no entry in `routes`, and `/` resolves to it (its first branch).

Rules:

- The shell has no path and never appears in the URL: `location` is always
  the URI of the top page of the current branch (or of the topmost
  full-screen page above the shell). The shell's `path` is `''` and
  `build` is never called (it throws `UnsupportedError`): the frame comes
  from `buildShell`.
- The shell's `redirect` runs before the redirects of the branch routes,
  as for any ancestor. A route that reaches the shell without one of its
  `branches` in between, or a parent chain with two shells, is an error.
- `open(route)` inside a branch replaces only that branch's stack (keeping
  its unchanged bottom) and switches to it; the other branches keep their
  stacks. `open(shell)` opens the first branch. `open(route)` outside the
  shell drops the shell and every branch stack.
- `push` of a route inside a shell throws an `UnsupportedError` (also when
  a redirect lands there): use `open`. Pushing a route outside the shell
  shows a full-screen page above it and returns its result through `pop`,
  as usual.
- `FoldableShellState.goBranch(index)` switches tabs, keeping the stack of
  the target. Branches are built lazily: the first visit runs the redirects
  (shell first, then the branch root) and opens the branch root; a later
  visit keeps the stack but re-checks the redirects. `goBranch` is a normal
  navigation: it sets `isNavigating` and can be superseded.
- Back (and `pop`) first removes a full-screen page above the shell, then
  goes one page back inside the current branch, and does nothing at the
  branch root (the system then leaves the app; it never jumps to the first
  tab). The router reports the predictive back state to the system, and
  `Hero` works between two pages of the same branch, through the nested
  navigator.
- A back in a shell handles exactly one thing, in this order: a pageless
  route on top of the root navigator (dialog opened with
  `useRootNavigator: true`), a full-screen page above the shell, a pageless
  route on top of the visible branch (bottom sheet, popup menu, dialog
  opened with `useRootNavigator: false`), then one page back inside the
  visible branch. `PopScope`s of the user (in a page or in a dialog) are
  respected; hidden tabs are never touched, and the state reported to the
  engine follows dialogs opening and closing.
- `router.stack` is `[shell, ...pages of the current branch, ...full-screen
  pages]`; `location` and the router's listeners follow the current tab.
- `refresh()` re-runs the redirects of the shell, the current branch and
  any full-screen page; the other branches are re-checked when shown again
  with `goBranch`.
- Deep links / `openUri` into a branch build only that branch.

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
