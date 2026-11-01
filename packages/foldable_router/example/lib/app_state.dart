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

/// The app state that picks the session. Change it, then call
/// `AppRouterScope.of(context).refresh()`.
bool _loggedIn = false;
bool _onboarded = false;

/// The session that matches the current app state.
String sessionNow() {
  if (!_loggedIn) return guestSession;
  return _onboarded ? mainSession : onboardingSession;
}

/// Changes the state and lets the router follow it.
void updateSession(BuildContext context, {bool? loggedIn, bool? onboarded}) {
  _loggedIn = loggedIn ?? _loggedIn;
  _onboarded = onboarded ?? _onboarded;
  AppRouterScope.of(context).refresh();
}

/// Marks the onboarding done and puts [route] on screen in [mainSession].
///
/// The state and the session switch in one step, so the router does not show
/// the main session's default route in between.
void completeOnboarding(BuildContext context, FoldableRoute route) {
  _onboarded = true;
  AppRouterScope.of(context).replaceSession(mainSession, route: route);
}

/// What the last button did, shown on the Home tab.
final lastAction = ValueNotifier<String>('Nothing yet. Try a button below.');

void logAction(String message) => lastAction.value = message;
