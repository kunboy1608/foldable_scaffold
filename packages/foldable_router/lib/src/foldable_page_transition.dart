import 'package:material_ui/material_ui.dart';

/// What a page is doing in a push/pop transition.
enum FoldableTransitionRole {
  /// Not part of a running transition: at rest, shown or hidden.
  steady,

  /// Appears: the new top page of a push, or the page a pop reveals.
  incoming,

  /// Goes away: the page below a push, or the page a pop removes.
  outgoing,
}

/// What a [FoldablePageTransition] needs to animate one page.
@immutable
class FoldableTransitionInfo {
  const FoldableTransitionInfo({
    required this.animation,
    required this.role,
    required this.isPush,
  });

  /// Progress of the transition, 0 to 1, for both pages of the transition and
  /// in both directions: it always runs from 0 when the transition starts to 1
  /// when it ends, so a page leaving the screen ends at 1 too.
  ///
  /// It is already curved, except while a swipe back follows the finger, when
  /// it is the raw progress of the drag. It stays at 1 for a [steady] page.
  final Animation<double> animation;

  /// What this page does in the transition.
  final FoldableTransitionRole role;

  /// Whether the transition is a push (the new page covers the old one) or a
  /// pop (the page on top is removed). Meaningless for a [steady] page.
  final bool isPush;

  /// Whether this page is drawn above the other page of the transition: the
  /// incoming page of a push and the outgoing page of a pop.
  bool get isOnTop =>
      role != FoldableTransitionRole.steady &&
      (role == FoldableTransitionRole.incoming) == isPush;
}

/// Builds the widget that animates a page in a push/pop transition.
typedef FoldablePageTransitionBuilder =
    Widget Function(
      BuildContext context,
      FoldableTransitionInfo info,
      Widget child,
    );

/// How a page animates when it is pushed or popped in a [FoldableNavigator].
///
/// Set it for all pages on the navigator (`transition:`), or for one page with
/// [FoldablePage.transition] or `FoldableRoute.transition`. The transition of
/// the page that is pushed (the incoming page) animates a push, and the one of
/// the page that is removed animates a pop; both pages of the transition are
/// animated by that transition.
///
/// The navigators call [build] for every page they show, including pages at
/// rest ([FoldableTransitionRole.steady]) and pages that are hidden, so the
/// widgets returned for each role must be of the same types and differ only in
/// their properties. A page that is wrapped in other widget types when its role
/// changes has its render objects re-created and loses focus. Its state is
/// kept, as the navigator holds the page under a `GlobalKey`.
///
/// ```dart
/// FoldableNavigator.stack(
///   controller: controller,
///   transition: FoldablePageTransition.fade,
/// );
///
/// FoldablePage(
///   transition: FoldablePageTransition.none,
///   child: const SettingsScreen(),
/// );
///
/// const grow = FoldablePageTransition.custom(_grow);
/// Widget _grow(BuildContext context, FoldableTransitionInfo info, Widget child) {
///   return ScaleTransition(scale: info.animation, child: child);
/// }
/// ```
@immutable
abstract class FoldablePageTransition {
  const FoldablePageTransition();

  /// The page on top slides in from the right while the page below gives way a
  /// third and the top page casts a shadow, like an iOS push. Supports swipe
  /// back. This is the default.
  static const FoldablePageTransition cupertino = _CupertinoTransition();

  /// The page on top fades in on a push and out on a pop, over the page below
  /// that stays still. No swipe back.
  static const FoldablePageTransition fade = _FadeTransition();

  /// No animation: the page appears or disappears at once, without starting
  /// the navigator's animation. No swipe back.
  static const FoldablePageTransition none = _NoTransition();

  /// A transition built by [builder], for both roles and every call.
  ///
  /// [builder] must follow the rule of [FoldablePageTransition]: the same widget
  /// types whatever the role. Set [supportsSwipeBack] to offer the left-edge
  /// swipe back on pages that use it; then [FoldableTransitionInfo.animation]
  /// follows the finger.
  const factory FoldablePageTransition.custom(
    FoldablePageTransitionBuilder builder, {
    bool supportsSwipeBack,
  }) = _CustomTransition;

  /// Whether a left-edge swipe can pop a page that uses this transition.
  bool get supportsSwipeBack => false;

  /// Whether this transition does not animate. A navigator skips its animation
  /// and does not report a running transition for it.
  bool get isInstant => false;

  /// Wraps [child], the page, for the state described by [info].
  Widget build(BuildContext context, FoldableTransitionInfo info, Widget child);
}

/// The shadow the page on top casts while it slides over the one below, like
/// a Cupertino page transition.
const _pageShadow = BoxDecoration(
  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
);

class _CupertinoTransition extends FoldablePageTransition {
  const _CupertinoTransition();

  @override
  bool get supportsSwipeBack => true;

  @override
  Widget build(
    BuildContext context,
    FoldableTransitionInfo info,
    Widget child,
  ) {
    // The page on top slides all the way in while the page below only gives
    // way a third, and the top page casts a shadow while it moves.
    const parallax = 1 / 3;
    Animation<Offset> position = const AlwaysStoppedAnimation(Offset.zero);
    if (info.role != FoldableTransitionRole.steady) {
      final entering = info.role == FoldableTransitionRole.incoming;
      final begin = entering
          ? (info.isPush ? const Offset(1, 0) : const Offset(-parallax, 0))
          : Offset.zero;
      final end = entering
          ? Offset.zero
          : (info.isPush ? const Offset(-parallax, 0) : const Offset(1, 0));
      position = info.animation.drive(Tween(begin: begin, end: end));
    }
    return SlideTransition(
      position: position,
      // The wrapper stays the same whatever the role, so only properties
      // change when the page starts or stops moving.
      child: DecoratedBox(
        decoration: info.isOnTop ? _pageShadow : const BoxDecoration(),
        child: child,
      ),
    );
  }
}

class _FadeTransition extends FoldablePageTransition {
  const _FadeTransition();

  @override
  Widget build(
    BuildContext context,
    FoldableTransitionInfo info,
    Widget child,
  ) {
    final Animation<double> opacity = info.isOnTop
        ? info.animation.drive(
            Tween<double>(begin: info.isPush ? 0 : 1, end: info.isPush ? 1 : 0),
          )
        : kAlwaysCompleteAnimation;
    return FadeTransition(opacity: opacity, child: child);
  }
}

class _NoTransition extends FoldablePageTransition {
  const _NoTransition();

  @override
  bool get isInstant => true;

  @override
  Widget build(
    BuildContext context,
    FoldableTransitionInfo info,
    Widget child,
  ) => child;
}

class _CustomTransition extends FoldablePageTransition {
  const _CustomTransition(this.builder, {this.supportsSwipeBack = false});

  final FoldablePageTransitionBuilder builder;

  @override
  final bool supportsSwipeBack;

  @override
  Widget build(
    BuildContext context,
    FoldableTransitionInfo info,
    Widget child,
  ) => builder(context, info, child);
}
