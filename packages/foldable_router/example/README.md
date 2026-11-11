# foldable_router example

A small app to try `foldable_router` by hand.

```sh
fvm flutter run -d chrome   # web: the address bar shows the route URLs
fvm flutter run -d linux
```

What to try:

- **open vs push** - the bar at the bottom always shows the current stack and
  location (it listens to the router, which is a `Listenable`).
- **Auth guard** - `/profile` and `/profile/settings` are protected by the
  async `redirect` of `ProfileRoute`; the old page stays while it runs.
- **Login** - `/login?from=...` returns you to the location you asked for
  (`router.routeFor(uri)` turns it back into a route).
- **Logout** - calls `router.refresh()`, which kicks you out of the profile.
- **push with result** - the colour picker returns a value through `pop`.
- **Hero** - in the users list, tap a user: the avatar flies to the detail and
  back (`Hero` works as usual; it also follows the predictive back gesture).
- **Not found** - on web, type an unknown URL such as `/nope`.
- **Predictive back** - enabled on Android (`android:enableOnBackInvokedCallback`).

Code: `lib/routes.dart` (routes and router), `lib/session.dart` (fake auth),
`lib/app.dart` (`MaterialApp.router` and the status bar), `lib/pages/`.
