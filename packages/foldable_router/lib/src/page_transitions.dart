import 'package:flutter/widgets.dart';
import 'package:foldable_core/foldable_core.dart';

/// Picks the [PageTransitionsBuilder] used for the page transitions of a
/// [FoldableRouter], given the context of the route being built.
///
/// `PageTransitionsBuilder` lives in the `widgets` library, so it is shared by
/// every Material library (`package:flutter/material.dart` and
/// `package:material_ui/material_ui.dart`): a resolver is how an app tells the
/// router which theme to read the transitions from.
typedef FoldablePageTransitionsResolver =
    PageTransitionsBuilder Function(BuildContext context);

/// The behaviour of `MaterialRouteTransitionMixin` rebuilt on the `widgets`
/// library only, so that no `Theme` of a particular Material library is read
/// unless the app's [pageTransitionsResolver] reads it.
///
/// The Material mixin of the SDK reads `Theme.of(context).pageTransitionsTheme`
/// of `package:flutter/material.dart`. In an app built on `material_ui` that
/// theme is never in the tree, so the lookup silently falls back to the
/// default light theme (white transition background, app's own
/// `pageTransitionsTheme` ignored).
mixin FoldablePageRouteMixin<T> on PageRoute<T> {
  /// Builds the primary contents of the route.
  @protected
  Widget buildContent(BuildContext context);

  /// Resolves the transitions builder from the navigator's context (durations,
  /// delegated transition) or the route's context (transitions).
  FoldablePageTransitionsResolver get pageTransitionsResolver;

  @override
  Duration get transitionDuration => FoldableMotion.readOf(
    navigator!.context,
    pageTransitionsResolver(navigator!.context).transitionDuration,
  );

  @override
  Duration get reverseTransitionDuration => FoldableMotion.readOf(
    navigator!.context,
    pageTransitionsResolver(navigator!.context).reverseTransitionDuration,
  );

  // The controller is created once with the durations of the first builder;
  // refresh them when the builder changes (theme or platform change).
  @override
  TickerFuture didPush() {
    controller?.duration = transitionDuration;
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    controller?.reverseDuration = reverseTransitionDuration;
    return super.didPop(result);
  }

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => _delegated;

  DelegatedTransitionBuilder? get _delegated =>
      (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        bool allowSnapshotting,
        Widget? child,
      ) {
        final DelegatedTransitionBuilder? builder = pageTransitionsResolver(
          context,
        ).delegatedTransition;
        return builder?.call(
          context,
          animation,
          secondaryAnimation,
          allowSnapshotting,
          child,
        );
      };

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    final bool nextRouteIsNotFullscreen =
        nextRoute is! PageRoute<dynamic> || !nextRoute.fullscreenDialog;
    final bool nextRouteHasDelegatedTransition =
        nextRoute is ModalRoute<dynamic> &&
        nextRoute.delegatedTransition != null;
    return nextRouteIsNotFullscreen &&
        (nextRoute is FoldablePageRouteMixin ||
            nextRouteHasDelegatedTransition);
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      previousRoute is PageRoute && !fullscreenDialog;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: buildContent(context),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => pageTransitionsResolver(
    context,
  ).buildTransitions<T>(this, context, animation, secondaryAnimation, child);
}

/// A page whose route draws [child] with the transitions of
/// [pageTransitionsResolver]: the `widgets`-only counterpart of
/// `MaterialPage`.
class FoldableContentPage<T> extends Page<T> {
  /// Creates a page.
  const FoldableContentPage({
    required this.child,
    required this.pageTransitionsResolver,
    super.key,
    super.canPop,
    super.onPopInvoked,
    super.name,
    super.arguments,
    super.restorationId,
  });

  /// The content of the route.
  final Widget child;

  /// Where the transitions come from.
  final FoldablePageTransitionsResolver pageTransitionsResolver;

  @override
  Route<T> createRoute(BuildContext context) =>
      _ContentRoute<T>(this, pageTransitionsResolver);
}

class _ContentRoute<T> extends PageRoute<T> with FoldablePageRouteMixin<T> {
  _ContentRoute(FoldableContentPage<T> page, this.pageTransitionsResolver)
    : super(settings: page);

  @override
  final FoldablePageTransitionsResolver pageTransitionsResolver;

  FoldableContentPage<T> get _page => settings as FoldableContentPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';
}
