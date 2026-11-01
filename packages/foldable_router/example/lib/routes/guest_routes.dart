import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import '../widgets.dart';
import 'app_route.dart';

class SignInRoute extends AppRoute {
  const SignInRoute();

  @override
  String get session => guestSession;

  @override
  String get path => '/sign-in';

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'Sign in',
      body: 'Signed out. This session has no navigation rail or bar.',
      actions: [
        FilledButton(
          // State changes; the router swaps the whole shell.
          onPressed: () => updateSession(context, loggedIn: true),
          child: const Text('Sign in'),
        ),
        TextButton(
          // push: the next page goes on top, back returns here.
          onPressed: () => AppRouterScope.of(context).push(const SignUpRoute()),
          child: const Text('Create an account'),
        ),
      ],
    );
  }
}

class SignUpRoute extends AppRoute {
  const SignUpRoute();

  @override
  String get session => guestSession;

  @override
  String get path => '/sign-up';

  @override
  Widget build(BuildContext context) {
    return FullScreenPage(
      title: 'Sign up',
      body: 'A new account goes straight to the onboarding.',
      actions: [
        FilledButton(
          onPressed: () => updateSession(context, loggedIn: true),
          child: const Text('Create account'),
        ),
        TextButton(
          onPressed: () => AppRouterScope.of(context).back(),
          child: const Text('I already have one'),
        ),
      ],
    );
  }
}
