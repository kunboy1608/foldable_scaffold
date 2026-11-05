import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app_router_scope.dart';
import '../app_state.dart';
import 'app_route.dart';
import 'checkout_routes.dart';
import 'details_routes.dart';
import 'guest_routes.dart';
import 'onboarding_routes.dart';
import 'tab_routes.dart';

/// What the platform opens first (`/`): sends the user to the first screen of
/// the session on screen.
class RootRoute extends AppRoute {
  const RootRoute();

  @override
  String get path => '/';

  @override
  FoldableRoute? redirect(BuildContext context, FoldableRouteState state) {
    return switch (AppRouterScope.of(context).activeSessionId) {
      guestSession => const SignInRoute(),
      onboardingSession => const WelcomeRoute(),
      _ => const HomeRoute(),
    };
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class NotFoundRoute extends FoldableRoute {
  const NotFoundRoute(this.uri);

  final Uri uri;

  @override
  String get path => uri.path;

  @override
  String get location => uri.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route for $uri')),
    );
  }
}

/// The tabs of [mainSession], in navigation rail / bar order.
const tabs = <TabRoute>[HomeRoute(), InboxRoute(), SettingsRoute()];

FoldableRoute? matchRoute(Uri uri) {
  return switch (uri.path) {
    '/' => const RootRoute(),
    '/sign-in' => const SignInRoute(),
    '/sign-up' => const SignUpRoute(),
    '/welcome' => const WelcomeRoute(),
    '/welcome/done' => const WelcomeDoneRoute(),
    '/home' => const HomeRoute(),
    '/inbox' => const InboxRoute(),
    '/settings' => const SettingsRoute(),
    '/details' => DetailsRoute(id: RouteQuery.fromUri(uri).string('id')),
    // Matched, but not deepLinkable: the router ignores it for URLs.
    '/checkout' => const CheckoutRoute(),
    '/checkout/review' => const CheckoutReviewRoute(),
    '/pick' => const PickRoute(),
    '/admin' => const AdminRoute(),
    '/forbidden' => const ForbiddenRoute(),
    _ => null,
  };
}
