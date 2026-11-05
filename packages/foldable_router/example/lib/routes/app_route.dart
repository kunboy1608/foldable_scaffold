import 'package:foldable_router/foldable_router.dart';

import '../app_state.dart';

/// A route that belongs to one session, named by [FoldableRoute.session].
///
/// Pushing a route of another session puts that session on top first. A URL
/// never switches session by itself: the guard in `app_router.dart` sends a
/// route of another session to the first screen of the session on screen, so a
/// signed out user who types `/home` still lands on sign in.
abstract class AppRoute extends FoldableRoute {
  const AppRoute();
}

/// A tab root of [mainSession]: a [BranchRoute], so its page never shows a
/// back button.
abstract class TabRoute extends BranchRoute {
  const TabRoute();

  @override
  String get session => mainSession;

  /// Index of the tab this route belongs to.
  int get tab;
}
