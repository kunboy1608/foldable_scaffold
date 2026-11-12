/// A small Navigation 2.0 router where every route is a plain Dart class.
///
/// See [FoldableRouter] for the entry point, [FoldableRoute] for how to
/// declare routes and [FoldableShellRoute] for a persistent frame (tabs,
/// rail, ...) with one stack per branch.
library;

export 'src/foldable_route.dart' show FoldableRoute;
export 'src/foldable_router.dart'
    show FoldableRouter, FoldableRouteFactory, FoldableNotFoundBuilder;
export 'src/foldable_shell_route.dart'
    show FoldableShellRoute, FoldableShellState;
export 'src/redirect_resolver.dart'
    show
        FoldableRedirectException,
        RedirectLoopException,
        RedirectLimitException;
export 'src/route_state.dart' show RouteState;
