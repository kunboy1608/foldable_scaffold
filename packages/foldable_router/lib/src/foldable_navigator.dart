import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:foldable_core/foldable_core.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_navigator_controller.dart';
import 'foldable_page.dart';

export 'foldable_navigator_controller.dart';
export 'foldable_page.dart';

part 'foldable_split_navigator.dart';
part 'foldable_stack_navigator.dart';

/// Builds the scaffold around the two panes of a [FoldableSplitNavigator].
typedef FoldableNavigatorBuilder =
    Widget Function(BuildContext context, Widget body, Widget? secondaryBody);

/// Shows the pages of a [FoldableNavigatorController].
///
/// There are two implementations:
///
/// * [FoldableSplitNavigator], created by `FoldableNavigator(...)`, keeps one
///   page stack per branch (tab) and shows the second-to-top page in the body
///   and the top page in the secondary body. Every page stays mounted
///   offstage, so switching branches keeps their state.
/// * [FoldableStackNavigator], created by [FoldableNavigator.stack], mounts
///   only the top page of the current branch, full screen, and ignores the
///   other branches. It fits flows without tabs, like sign in or onboarding.
///
/// Both share the navigation of [FoldableNavigatorController] (push, pop, back
/// buttons and swipe back) and the static lookup methods below.
///
/// ```dart
/// // One stack per tab, two panes.
/// FoldableNavigator(
///   controller: router.controller,
///   builder: (context, body, secondaryBody) => FoldableScaffold(
///     bodyBuilder: (_, _) => body,
///     secondaryBodyBuilder: (_, _) => secondaryBody,
///     hasSecondaryBody: secondaryBody != null,
///   ),
/// );
///
/// // Top page only, no branches, no scaffold.
/// FoldableNavigator.stack(controller: router.controller);
///
/// // In any page:
/// FoldableNavigator.of(context).push(FoldablePage(child: DetailsScreen()));
/// FoldableNavigator.of(context).pop();
/// ```
abstract class FoldableNavigator extends StatefulWidget {
  /// Base constructor for the implementations.
  const FoldableNavigator.base({required this.controller, super.key});

  /// One page stack per branch, shown in the body and the secondary body.
  factory FoldableNavigator({
    required FoldableNavigatorController controller,
    required FoldableNavigatorBuilder builder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve transitionCurve = Curves.fastOutSlowIn,
    Key? key,
  }) {
    return FoldableSplitNavigator(
      controller: controller,
      builder: builder,
      transitionDuration: transitionDuration,
      transitionCurve: transitionCurve,
      key: key,
    );
  }

  /// Only the top page of the current branch, full screen.
  ///
  /// The pages below the top one and the pages of the other branches are not
  /// mounted at all, so their state is thrown away when they leave the screen.
  /// Use it for flows without tabs, like sign in or onboarding.
  ///
  /// The [controller] may start empty (see [FoldableNavigatorController.empty]):
  /// the navigator shows nothing until the first page arrives.
  factory FoldableNavigator.stack({
    required FoldableNavigatorController controller,
    Duration transitionDuration = const Duration(milliseconds: 300),
    Curve transitionCurve = Curves.fastOutSlowIn,
    Key? key,
  }) {
    return FoldableStackNavigator(
      controller: controller,
      transitionDuration: transitionDuration,
      transitionCurve: transitionCurve,
      key: key,
    );
  }

  /// The stacks to show.
  final FoldableNavigatorController controller;

  /// The controller of the closest [FoldableNavigator].
  ///
  /// By default this does not rebuild [context] on navigation changes, which
  /// is what you want for calling `push`/`pop`. Pass `listen: true` to read
  /// state such as `currentIndex` or `canPop` during build.
  static FoldableNavigatorController of(
    BuildContext context, {
    bool listen = false,
  }) {
    final controller = maybeOf(context, listen: listen);
    assert(controller != null, 'No FoldableNavigator found in context.');
    return controller!;
  }

  /// The controller of the closest [FoldableNavigator], if any.
  static FoldableNavigatorController? maybeOf(
    BuildContext context, {
    bool listen = false,
  }) {
    return _scopeOf(context, listen: listen)?.controller;
  }

  /// The page that [context] is inside of, if any.
  static Page<Object?>? pageOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_FoldablePageScope>()?.page;
  }

  /// Whether the closest [FoldableNavigator] has a page to pop.
  ///
  /// Useful in an app bar: unlike [isTransitioning], this resubscribes
  /// [context] when navigation changes, so the bar can show or hide its back
  /// button. Pass `listen: false` to read the value without subscribing.
  static bool canPop(BuildContext context, {bool listen = true}) {
    return maybeOf(context, listen: listen)?.canPop ?? false;
  }

  /// Removes the page that [context] is inside of, together with the pages
  /// above it in its branch.
  ///
  /// [FoldableNavigatorController.pop] always removes the top page of the
  /// current branch, which is the wrong page when the back button lives on the
  /// body page of a split view. This pops the page that owns [context]
  /// instead, so each pane pops itself.
  ///
  /// Returns whether a page was removed. When [context] is not inside a page,
  /// it falls back to popping the top page of the current branch.
  static bool popPageOf(BuildContext context, {Object? result}) {
    final controller = of(context);
    final page = pageOf(context);
    return page == null
        ? controller.pop(result)
        : controller.popPage(page, result);
  }

  /// Whether the closest [FoldableNavigator] is running a push/pop slide.
  static bool isTransitioning(BuildContext context) {
    return _scopeOf(context, listen: false)?.transitioning.value ?? false;
  }

  /// The signal the closest [FoldableNavigator] uses for [isTransitioning],
  /// for widgets that need to listen to it instead of being rebuilt.
  static ValueListenable<bool>? transitioningOf(BuildContext context) {
    return _scopeOf(context, listen: false)?.transitioning;
  }

  static _FoldableNavigatorScope? _scopeOf(
    BuildContext context, {
    required bool listen,
  }) {
    return listen
        ? context.dependOnInheritedWidgetOfExactType<_FoldableNavigatorScope>()
        : context.getInheritedWidgetOfExactType<_FoldableNavigatorScope>();
  }
}

/// Back button for a page inside a [FoldableNavigator].
///
/// Shown on every page that is on screen while the stack can be popped, in
/// the primary body and in the secondary body of a [FoldableSplitNavigator].
/// Tapping it removes the page it belongs to, together with the pages above it
/// in the branch, so in a split view each pane pops itself instead of the page
/// above it (see [FoldableNavigator.popPageOf]). Use it as `AppBar.leading`.
///
/// Outside a page, as in the app bar of a shell around the navigator, it
/// follows whether the closest [FoldableNavigator] can pop and removes the top
/// page of the current branch when tapped.
class FoldableBackButton extends StatelessWidget {
  const FoldableBackButton({super.key, this.color, this.style, this.onPressed});

  /// Color of the icon.
  final Color? color;

  /// Called before the page is popped.
  final VoidCallback? onPressed;

  /// Customizes this button's appearance.
  ///
  /// Like [BackButton.style].
  final ButtonStyle? style;

  /// Whether a [FoldableBackButton] would be shown at [context]. Rebuilds
  /// [context] when that changes.
  ///
  /// Inside a page it follows the page's position in the stack. Outside one,
  /// as in the app bar of a shell that wraps the navigator, it follows
  /// [FoldableNavigator.canPop].
  static bool isVisible(BuildContext context) {
    final page = context
        .dependOnInheritedWidgetOfExactType<_FoldablePageScope>();
    return page?.canGoBack ?? FoldableNavigator.canPop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible(context)) return const SizedBox.shrink();
    return BackButton(
      color: color,
      style: style,
      onPressed: onPressed ?? () => FoldableNavigator.popPageOf(context),
    );
  }
}

/// The shadow the page on top casts while it slides over the one below, like
/// a Cupertino page transition.
const _pageShadow = BoxDecoration(
  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
);

/// Keeps a [LocalHistoryEntry] on the enclosing [ModalRoute] while the
/// navigator can pop.
///
/// [AppBar] shows its automatic back button when its route implies app bar
/// dismissal. A route with a single page does not, unless it has a local
/// history entry (this is how a nested [Navigator] gets one). The entry also
/// makes `Navigator.maybePop` — what that back button calls — pop one foldable
/// page.
mixin _FoldableAppBarHistory<T extends FoldableNavigator> on State<T> {
  LocalHistoryEntry? _historyEntry;
  ModalRoute<dynamic>? _historyRoute;
  bool _removingHistory = false;
  bool _historySyncScheduled = false;

  FoldableNavigatorController get historyController => widget.controller;

  @override
  void initState() {
    super.initState();
    historyController.addListener(_scheduleHistorySync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Catch the route becoming current, or a different one when the widget
    // moves inside a Navigator.
    _scheduleHistorySync();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_scheduleHistorySync);
      widget.controller.addListener(_scheduleHistorySync);
      _scheduleHistorySync();
    }
  }

  @override
  void dispose() {
    historyController.removeListener(_scheduleHistorySync);
    _detachHistory();
    super.dispose();
  }

  void _scheduleHistorySync() {
    if (!mounted || _historySyncScheduled) return;
    _historySyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historySyncScheduled = false;
      if (mounted) _syncHistory();
    });
  }

  void _syncHistory() {
    final route = ModalRoute.of<dynamic>(context);
    if (!identical(route, _historyRoute)) {
      _detachHistory();
      _historyRoute = route;
    }
    final wantsEntry =
        historyController.canPop && (route?.isCurrent ?? false);
    if (wantsEntry && _historyEntry == null && route != null) {
      final entry = LocalHistoryEntry(onRemove: _onHistoryRemoved);
      _historyEntry = entry;
      route.addLocalHistoryEntry(entry);
    } else if (!wantsEntry && _historyEntry != null) {
      _detachHistory();
    }
  }

  void _detachHistory() {
    final entry = _historyEntry;
    if (entry == null) return;
    _historyEntry = null;
    final route = _historyRoute;
    if (route == null) return;
    // Removing it ourselves must not pop a page: only a user back should.
    _removingHistory = true;
    try {
      route.removeLocalHistoryEntry(entry);
    } finally {
      _removingHistory = false;
    }
  }

  void _onHistoryRemoved() {
    if (_removingHistory) return;
    _historyEntry = null;
    historyController.pop();
  }
}

/// Width of the left edge strip where a drag starts a back swipe.
const double _kBackSwipeEdge = 20.0;

/// Speed, in logical pixels per second, a released swipe needs to pop the
/// page even when it has not moved past half the width.
const double _kBackSwipeMinFlingVelocity = 700.0;

class _FoldableNavigatorScope extends InheritedWidget {
  const _FoldableNavigatorScope({
    required this.controller,
    required this.transitioning,
    required this.revision,
    required super.child,
  });

  final FoldableNavigatorController controller;
  final ValueListenable<bool> transitioning;
  final int revision;

  @override
  bool updateShouldNotify(_FoldableNavigatorScope oldWidget) =>
      revision != oldWidget.revision ||
      controller != oldWidget.controller ||
      transitioning != oldWidget.transitioning;
}

class _FoldablePageScope extends InheritedWidget {
  const _FoldablePageScope({
    required this.page,
    required this.canGoBack,
    required super.child,
  });

  final Page<Object?> page;

  /// Whether the stack of the branch can be popped, so the page shows the
  /// back button.
  final bool canGoBack;

  @override
  bool updateShouldNotify(_FoldablePageScope oldWidget) =>
      canGoBack != oldWidget.canGoBack || page != oldWidget.page;
}
