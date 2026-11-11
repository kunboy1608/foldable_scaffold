/// A small Navigation 2.0 router where every route is a plain Dart class.
///
/// See [FoldableRouter] for the entry point and [FoldableRoute] for how to
/// declare routes.
library;

export 'src/foldable_route.dart' show FoldableRoute;
export 'src/foldable_router.dart'
    show FoldableRouter, FoldableRouteFactory, FoldableNotFoundBuilder;
export 'src/redirect_resolver.dart'
    show
        FoldableRedirectException,
        RedirectLoopException,
        RedirectLimitException;
export 'src/route_state.dart' show RouteState;
