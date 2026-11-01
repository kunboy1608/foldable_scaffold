import 'package:foldable_router/foldable_router.dart';

import '../app_state.dart';

/// A route that belongs to one session. A route of another session is sent to
/// that session's first screen by the guard in `app_router.dart`, so a signed
/// out user who types `/home` still lands on sign in.
abstract class AppRoute extends FoldableRoute {
  const AppRoute();

  /// The session this screen belongs to, or null when any session may show it.
  String? get session => null;
}

/// A route that is also a tab root of [mainSession].
abstract class TabRoute extends AppRoute {
  const TabRoute();

  @override
  String get session => mainSession;

  /// Index of the tab this route belongs to.
  int get tab;
}
