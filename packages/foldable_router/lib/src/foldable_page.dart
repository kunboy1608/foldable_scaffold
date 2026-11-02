import 'package:material_ui/material_ui.dart';

import 'foldable_page_transition.dart';

/// A [Page] that exposes the widget it shows, so a [FoldableNavigator] can
/// show it.
///
/// This is the extension point for custom page types. A [FoldableNavigator]
/// mounts the [child] of a page itself and does not call [Page.createRoute],
/// so a custom [Page] subclass that implements this interface is shown by the
/// navigators, while its own [Page.createRoute] still serves a normal
/// [Navigator].
///
/// ```dart
/// class FadePage<T> extends Page<T> implements FoldablePageContent {
///   const FadePage({required this.child, super.key, super.name});
///
///   @override
///   final Widget child;
///
///   @override
///   Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
///     settings: this,
///     pageBuilder: (_, _, _) => child,
///     transitionsBuilder: (_, animation, _, child) =>
///         FadeTransition(opacity: animation, child: child),
///   );
/// }
/// ```
///
/// `FoldableNavigator` also shows [MaterialPage] and `CupertinoPage` without
/// this interface.
abstract interface class FoldablePageContent {
  /// The widget shown for this page.
  Widget get child;
}

/// A [Page] that can be shown inside a [FoldableNavigator].
///
/// It is a regular [Page], so the same page can also be handed to a normal
/// [Navigator] (it creates a [MaterialPageRoute]).
///
/// A [restorationId] gives the page its own `RestorationScope` in a
/// [FoldableNavigator], so the restorable state inside it (scroll positions,
/// text fields with a `restorationId`) is restored with the app. Ids must be
/// unique among the pages of a navigator.
class FoldablePage<T> extends Page<T> implements FoldablePageContent {
  const FoldablePage({
    required this.child,
    this.transition,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.canPop,
    super.onPopInvoked,
  });

  /// The widget shown for this page.
  @override
  final Widget child;

  /// How this page animates when it is pushed or popped in a
  /// [FoldableNavigator], or null for the transition of the navigator.
  ///
  /// A normal [Navigator] ignores it.
  final FoldablePageTransition? transition;

  @override
  Route<T> createRoute(BuildContext context) {
    return MaterialPageRoute<T>(settings: this, builder: (_) => child);
  }
}
