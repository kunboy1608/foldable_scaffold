import 'package:foldable_router/foldable_router.dart';
import 'package:material_ui/material_ui.dart';

import '../app_state.dart';
import 'app_route.dart';

/// First screen of [checkoutSession], opened over [mainSession].
class CheckoutRoute extends AppRoute {
  const CheckoutRoute();

  @override
  String? get session => checkoutSession;

  @override
  String get path => '/checkout';

  @override
  Widget build(BuildContext context) {
    final router = FoldableRouterScope.of(context);
    return Scaffold(
      appBar: AppBar(
        // Shown because another session is open below; closes this one.
        leading: const FoldableSessionBackButton(),
        title: const Text('Checkout'),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text('A session on top of main'),
            subtitle: Text(
              'The tabs below keep their pages. The back button, and the '
              'system back at this root, close the session.',
            ),
          ),
          ListTile(
            title: const Text('Pay'),
            subtitle: const Text('closeSession("paid") completes openSession.'),
            onTap: () => router.closeSession('paid'),
          ),
          ListTile(
            title: const Text('Next step (a page of this session)'),
            subtitle: const Text('Pages of the session still pop first.'),
            onTap: () => const CheckoutReviewRoute().push<void>(context),
          ),
        ],
      ),
    );
  }
}

class CheckoutReviewRoute extends AppRoute {
  const CheckoutReviewRoute();

  @override
  String? get session => checkoutSession;

  @override
  String get path => '/checkout/review';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: const Center(child: Text('Back pops this page, not the session.')),
    );
  }
}
