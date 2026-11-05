import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router_scope.dart';

/// Three sessions share one router. Each has its own roots, page stacks and
/// shell, and exactly one is on screen:
///
/// * [guestSession]: signed out. Sign in, sign up. Top page only.
/// * [onboardingSession]: signed in, not onboarded yet. Top page only.
/// * [mainSession]: the tabs, in a navigation rail / bar. Shows every way to
///   navigate.
const guestSession = 'guest';
const onboardingSession = 'onboarding';
const mainSession = 'main';

/// Opened over [mainSession] with `openSession`; closing it shows the tabs
/// again.
const checkoutSession = 'checkout';

/// The app state behind the sessions. [updateSession] changes it and asks the
/// router to check which sessions still exist.
bool _loggedIn = false;
bool _onboarded = false;

bool get isLoggedIn => _loggedIn;
bool get isOnboarded => _onboarded;

/// Whether the tabs may be opened, see `canActivate` in `app_router.dart`.
///
/// A real app reads a stored token here, which is why a condition may be
/// async: the router waits for it in `refresh()`.
Future<bool> get isReady async => _loggedIn && _onboarded;

/// Changes the state and lets the router check the sessions again: the ones
/// that no longer hold are closed, and the base is chosen again.
Future<void> updateSession(
  BuildContext context, {
  bool? loggedIn,
  bool? onboarded,
}) {
  _loggedIn = loggedIn ?? _loggedIn;
  _onboarded = onboarded ?? _onboarded;
  return AppRouterScope.of(context).refresh();
}

/// Marks the onboarding done and puts [route] on screen in [mainSession].
///
/// Navigation waits for the refresh, so [route] opens in the tabs and the
/// router does not show the main session's default route in between.
Future<void> completeOnboarding(
  BuildContext context,
  FoldableRoute route,
) async {
  final router = AppRouterScope.of(context);
  _onboarded = true;
  final refreshed = router.refresh();
  router.go(null, route);
  await refreshed;
}

/// What the last button did, shown on the Home tab.
final lastAction = ValueNotifier<String>('Nothing yet. Try a button below.');

void logAction(String message) => lastAction.value = message;
