import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'app_route.dart';
import 'tab_routes.dart';

class WelcomeRoute extends AppRoute {
  const WelcomeRoute();

  @override
  String get session => onboardingSession;

  @override
  String get path => '/welcome';

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'Welcome',
      body: 'Signed in, not onboarded. Still no navigation rail or bar.',
      actions: [
        FilledButton(
          onPressed: () =>
              AppRouterScope.of(context).push(const WelcomeDoneRoute()),
          child: const Text('Next'),
        ),
        TextButton(
          // Mark the state first, then put the session on screen yourself,
          // with a route to start on.
          onPressed: () => completeOnboarding(context, const HomeRoute()),
          child: const Text('Skip (replaceSession)'),
        ),
      ],
    );
  }
}

class WelcomeDoneRoute extends AppRoute {
  const WelcomeDoneRoute();

  @override
  String get session => onboardingSession;

  @override
  String get path => '/welcome/done';

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'All set',
      body: 'Finishing flips the state; the router follows it.',
      actions: [
        FilledButton(
          onPressed: () => updateSession(context, onboarded: true),
          child: const Text('Open the app'),
        ),
      ],
    );
  }
}
