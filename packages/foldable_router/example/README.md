# foldable_router example

A small app to try `foldable_router` by hand.

```sh
fvm flutter run -d chrome   # web: the address bar shows the route URLs
fvm flutter run -d linux
```

The app runs inside a shell: `MainShellRoute` draws a bottom `NavigationBar`
with three tabs (Home, Users, Profile), each with its own stack. The bar at
the bottom of the window shows the current stack and location (it listens to
the router, which is a `Listenable`; the shell shows as `[shell]`).

What to try:

- **Tabs** - switch tabs with the bottom bar: each tab keeps its own stack
  and its page state. Inside the shell only `open`/`goBranch` are used;
  opening a route of another branch switches to that tab.
- **open** - `open(UserRoute(id: '7'))` builds `[/, Users]` in the Users tab
  and switches to it. The Users list -> detail keeps its `Hero` flight.
- **Auth guard** - `/profile` and `/profile/settings` are protected by the
  async `redirect` of `ProfileRoute`; the old page stays while it runs.
  Login lives outside the shell, so the tabs disappear while you log in.
- **Login** - `/login?from=...` returns you to the location you asked for
  (`router.routeFor(uri)` turns it back into a route).
- **Logout** - calls `router.refresh()`, which kicks you out of the profile.
- **push with result** - the colour picker is outside the shell: it covers
  the tab bar full-screen and returns a value through `pop`.
- **Hero** - in the users list, tap a user: the avatar flies to the detail and
  back inside the tab (`Hero` works through the nested navigator; it also
  follows the predictive back gesture).
- **Not found** - on web, type an unknown URL such as `/nope`.
- **Predictive back** - enabled on Android
  (`android:enableOnBackInvokedCallback`); back goes one page back inside the
  current tab and leaves the app at the tab root.

Code: `lib/routes.dart` (routes, the shell and the router), `lib/session.dart`
(fake auth), `lib/app.dart` (`MaterialApp.router` and the status bar),
`lib/pages/` (including `shell_page.dart`, the bottom bar).
