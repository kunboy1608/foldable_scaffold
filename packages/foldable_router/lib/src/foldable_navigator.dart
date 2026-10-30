// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:foldable_core/foldable_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_navigator_controller.dart';
import 'foldable_page.dart';

export 'foldable_navigator_controller.dart';
export 'foldable_page.dart';

/// Builds the scaffold around the two panes of a [FoldableNavigator].
typedef FoldableNavigatorBuilder =
    Widget Function(BuildContext context, Widget body, Widget? secondaryBody);

/// Page stacks for a two-pane scaffold, driven by a
/// [FoldableNavigatorController].
///
/// Only the branch at [FoldableNavigatorController.currentIndex] is shown:
///
/// * With 1 page, it is the body and there is no secondary body.
/// * With 2+ pages, the second-to-top page is the body and the top page is
///   the secondary body.
/// * Every other page, including all pages of other branches, stays mounted
///   offstage (no paint, no tickers, no relayout when panes resize), so
///   switching branches keeps their state. A page also keeps its state when
///   it moves from one pane to another.
/// * Back (system back, predictive back or
///   `FoldableNavigator.of(context).pop()`) removes the top page of the
///   current branch. When the current branch has only 1 page, back falls
///   through to the enclosing route. [FoldableBackButton] shows in the primary
///   body and in the secondary body while the branch can be popped, and
///   removes the page it is in together with the pages above it, so in a
///   split view the two panes pop themselves (see
///   [FoldableNavigator.popPageOf]).
/// * Pages slide like a Cupertino page push/pop (see [transitionDuration]):
///   the new page slides in from the right over the old one, which only
///   gives way a third and lets the new page cast a shadow. Each pane only
///   slides if its own page changed. In a layout with two panes, a change
///   that only touches the secondary page does not slide; the page just
///   appears while the scaffold animates the pane open. With a single pane,
///   pushing the first page that has a secondary body (1 → 2 pages) and
///   popping back down to one page slide the old and new pages inside that
///   pane, instead of resizing the panes. Switching branches does not
///   animate.
/// * On a single-pane layout, dragging from the left edge follows the finger
///   and, when released past half the width (or with enough speed), pops the
///   top page like a Cupertino swipe-back; otherwise the page snaps back.
///
/// Pages are identified by [Page.key], or by the page object when it has no
/// key.
///
/// ```dart
/// FoldableNavigator(
///   controller: _controller,
///   builder: (context, body, secondaryBody) => FoldableScaffold(
///     bodyBuilder: (_, _) => body,
///     secondaryBodyBuilder: (_, _) => secondaryBody,
///     primaryNavigationBuilder: (context, constraints, padding) =>
///         NavigationRail(
///           selectedIndex: _controller.currentIndex,
///           onDestinationSelected: _controller.goBranch,
///           ...
///         ),
///   ),
/// )
///
/// // In any page:
/// FoldableNavigator.of(context).push(FoldablePage(child: DetailsScreen()));
/// FoldableNavigator.of(context).pop();
/// ```
class FoldableNavigator extends StatefulWidget {
  const FoldableNavigator({
    required this.controller,
    required this.builder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.transitionCurve = Curves.fastOutSlowIn,
    super.key,
  });

  /// The stacks to show.
  final FoldableNavigatorController controller;

  /// Builds the scaffold. Pass [body] to `bodyBuilder` and [secondaryBody]
  /// to `secondaryBodyBuilder` of [FoldableScaffold]. Called again on every
  /// controller change.
  final FoldableNavigatorBuilder builder;

  /// Duration of the push/pop slide. [Duration.zero] disables it, and the
  /// swipe-back gesture with it.
  final Duration transitionDuration;

  /// Curve of the push/pop slide.
  final Curve transitionCurve;

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
    return _scopeOf(context, listen: listen)?.state.widget.controller;
  }

  /// The page that [context] is inside of, if any.
  static Page<Object?>? pageOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_FoldablePageScope>()?.page;
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
    return _scopeOf(context, listen: false)?.state._transition != null;
  }

  /// The signal the closest [FoldableNavigator] uses for [isTransitioning],
  /// for widgets that need to listen to it instead of being rebuilt.
  static ValueListenable<bool>? transitioningOf(BuildContext context) {
    return _scopeOf(context, listen: false)?.state._transitioning;
  }

  static _FoldableNavigatorScope? _scopeOf(
    BuildContext context, {
    required bool listen,
  }) {
    return listen
        ? context.dependOnInheritedWidgetOfExactType<_FoldableNavigatorScope>()
        : context.getInheritedWidgetOfExactType<_FoldableNavigatorScope>();
  }

  @override
  State<FoldableNavigator> createState() => _FoldableNavigatorState();
}

class _FoldableNavigatorState extends State<FoldableNavigator>
    with SingleTickerProviderStateMixin {
  final Map<(int, Key), GlobalKey> _subtreeKeys = {};

  /// Tells [FoldableScaffold] that pages are sliding, so it snaps pane
  /// changes instead of animating a resize on top of the slide.
  final _transitioning = ValueNotifier<bool>(false);

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: widget.transitionDuration,
  )..addStatusListener(_onTransitionStatus);
  late CurvedAnimation _animation = CurvedAnimation(
    parent: _animationController,
    curve: widget.transitionCurve,
  );

  /// What is visible now, to detect push/pop on the next change.
  late _Visible _visible = _currentVisible();
  _Transition? _transition;

  /// Bumped on every controller change so listening widgets rebuild.
  int _revision = 0;

  /// The pane layout the scaffold produced last, and whether it was wide
  /// enough to show two panes, recorded while the bodies build.
  FoldablePaneLayout? _lastLayout;
  bool _lastCanSplit = false;

  /// The active swipe-back recognizer of the left edge gesture.
  HorizontalDragGestureRecognizer? _backRecognizer;

  /// Whether a swipe-back drag is moving the pages right now.
  bool _backSwipeDragging = false;

  /// Whether a released or cancelled swipe-back is sliding back to rest.
  bool _backSwipeSettling = false;

  /// Whether the released swipe-back is popping the top page right now.
  bool _backSwipeCompleting = false;

  FoldableNavigatorController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationController.duration = FoldableMotion.readOf(
      context,
      widget.transitionDuration,
    );
  }

  @override
  void didUpdateWidget(covariant FoldableNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animationController.duration = FoldableMotion.readOf(
      context,
      widget.transitionDuration,
    );
    if (widget.transitionCurve != oldWidget.transitionCurve) {
      _animation.dispose();
      _animation = CurvedAnimation(
        parent: _animationController,
        curve: widget.transitionCurve,
      );
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
      _transition = null;
      _transitioning.value = false;
      _backSwipeDragging = false;
      _backSwipeSettling = false;
      _animationController.value = 1;
      _visible = _currentVisible();
      _subtreeKeys.clear();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _backRecognizer?.dispose();
    _backRecognizer = null;
    _transitioning.dispose();
    _animation.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Key _idOf(Page<Object?> page) => page.key ?? ObjectKey(page);

  _Entry _entry(int branch, Page<Object?> page) =>
      _Entry(branch, _idOf(page), page);

  _Visible _currentVisible() {
    final branch = _controller.currentIndex;
    final pages = _controller.pages;
    final count = pages.length;
    return _Visible(
      branch: branch,
      ids: {for (final page in pages) _idOf(page)},
      body: _entry(branch, pages[count > 1 ? count - 2 : 0]),
      secondary: count > 1 ? _entry(branch, pages.last) : null,
    );
  }

  void _onControllerChanged() {
    final previous = _visible;
    final next = _currentVisible();
    _visible = next;

    // Only a change of the body page slides, so a change that only touches
    // the secondary page does not duplicate or rebuild the body for a slide.
    final bodyChanged = previous.body.id != next.body.id;
    // A new top page means push; otherwise pages were removed: pop.
    final isPush = !previous.ids.contains(next.top.id);
    // Popping down to one page closes the secondary body.
    final closesSecondary = !isPush && next.secondary == null;
    // Crossing 1↔2 pages switches the visible pane of a single-pane layout
    // (phones, narrow windows): the page on screen gives way to the new top
    // page inside the pane that is shown now, so it slides like a page
    // push/pop. With two panes to show, the scaffold just opens or closes
    // the second pane instead.
    final changesPageCount =
        (previous.secondary == null) != (next.secondary == null);
    final switchesPane = changesPageCount && !_lastCanSplit;
    if (_backSwipeCompleting) {
      // The swipe was released far enough to pop: keep its transition, the
      // release slides it to the end.
      _cleanUpKeys();
      setState(() => _revision++);
      return;
    }
    if (_backSwipeDragging || _transition?.userDriven == true) {
      // The stack changed under a swipe, so drop the swipe and animate this
      // change like any other.
      _backSwipeDragging = false;
      _backSwipeSettling = false;
      _transition = null;
    }
    if (previous.branch != next.branch ||
        widget.transitionDuration == Duration.zero ||
        (!bodyChanged && !switchesPane) ||
        (closesSecondary && !switchesPane)) {
      _transition = null;
      _animationController.value = 1;
    } else {
      _transition = _Transition(
        isPush: isPush,
        body: previous.body,
        secondary: previous.secondary,
        switchesPane: switchesPane,
        // The page on screen before the change: the secondary body when the
        // last build showed it, the body otherwise.
        visibleBefore: (_lastLayout?.secondaryVisible ?? false)
            ? (previous.secondary ?? previous.body)
            : previous.body,
      );
      _animationController.forward(from: 0);
    }
    _transitioning.value = _transition != null;
    _cleanUpKeys();
    setState(() => _revision++);
  }

  void _onTransitionStatus(AnimationStatus status) {
    if (!mounted || _transition == null) return;
    if (status.isCompleted) {
      setState(() => _transition = null);
      _transitioning.value = false;
      _cleanUpKeys();
    } else if (status.isDismissed && _backSwipeSettling) {
      // A cancelled swipe slid back to rest.
      _backSwipeSettling = false;
      setState(() => _transition = null);
      _transitioning.value = false;
      _cleanUpKeys();
    }
  }

  void _cleanUpKeys() {
    final alive = {
      for (var b = 0; b < _controller.branchCount; b++)
        for (final page in _controller.pagesOf(b)) (b, _idOf(page)),
      if (_transition case final t?) ...[
        t.body.key,
        if (t.secondary case final s?) s.key,
      ],
    };
    _subtreeKeys.removeWhere((id, _) => !alive.contains(id));
  }

  /// Whether a swipe from the left edge can start a pop now.
  bool get _canStartBackSwipe =>
      widget.transitionDuration != Duration.zero &&
      _transition == null &&
      !_backSwipeDragging &&
      !_lastCanSplit &&
      _controller.canPop &&
      _controller.pages.last.canPop;

  void _handleBackPointerDown(PointerDownEvent event) {
    // One swipe at a time.
    final previous = _backRecognizer;
    _backRecognizer = null;
    if (previous != null) _disposeLater(previous);
    if (event.kind == PointerDeviceKind.mouse) return;
    if (event.localPosition.dx > _kBackSwipeEdge) return;
    if (!_canStartBackSwipe) return;
    final recognizer = HorizontalDragGestureRecognizer(debugOwner: this);
    recognizer.onStart = (_) => _startBackSwipe();
    recognizer.onUpdate = _updateBackSwipe;
    recognizer.onEnd = _endBackSwipe;
    recognizer.onCancel = _cancelBackSwipe;
    recognizer.addPointer(event);
    _backRecognizer = recognizer;
  }

  /// Recognizers are not safe to dispose from their own callbacks.
  void _disposeLater(GestureRecognizer recognizer) {
    WidgetsBinding.instance.addPostFrameCallback((_) => recognizer.dispose());
  }

  /// Shows the pop a rightward drag would do, before the page is removed.
  void _startBackSwipe() {
    if (!mounted || !_canStartBackSwipe) return;
    final branch = _controller.currentIndex;
    final pages = _controller.pages;
    // What stays visible when the top page is gone.
    final count = pages.length - 1;
    _backSwipeDragging = true;
    setState(() {
      _transition = _Transition(
        isPush: false,
        body: _visible.body,
        secondary: _visible.secondary,
        switchesPane:
            !_lastCanSplit &&
            count == 1, // only the body page is left: back to the body pane
        visibleBefore: (_lastLayout?.secondaryVisible ?? false)
            ? (_visible.secondary ?? _visible.body)
            : _visible.body,
        userDriven: true,
        nextBody: _entry(branch, pages[count > 1 ? count - 2 : 0]),
        nextSecondary: count > 1 ? _entry(branch, pages[count - 1]) : null,
      );
    });
    _transitioning.value = true;
    _animationController.value = 0;
  }

  void _updateBackSwipe(DragUpdateDetails details) {
    if (_transition?.userDriven != true) return;
    final width = context.size?.width ?? 0;
    if (width <= 0) return;
    final value =
        (_animationController.value + (details.primaryDelta ?? 0) / width)
            .clamp(0.0, 1.0);
    _animationController.value = value;
  }

  void _endBackSwipe(DragEndDetails details) {
    _backSwipeDragging = false;
    final recognizer = _backRecognizer;
    _backRecognizer = null;
    if (recognizer != null) _disposeLater(recognizer);
    if (_transition?.userDriven != true) return;
    final velocity = details.primaryVelocity ?? 0;
    final goBack =
        velocity > _kBackSwipeMinFlingVelocity ||
        (velocity > -_kBackSwipeMinFlingVelocity &&
            _animationController.value > 0.5);
    if (!goBack) {
      _settleBackSwipe(complete: false);
      return;
    }
    _backSwipeCompleting = true;
    final didPop = _controller.pop();
    _backSwipeCompleting = false;
    _settleBackSwipe(complete: didPop);
  }

  void _cancelBackSwipe() {
    _backSwipeDragging = false;
    final recognizer = _backRecognizer;
    _backRecognizer = null;
    if (recognizer != null) _disposeLater(recognizer);
    if (_transition?.userDriven != true) return;
    _settleBackSwipe(complete: false);
  }

  void _settleBackSwipe({required bool complete}) {
    if (complete) {
      _animationController.forward();
    } else {
      _backSwipeSettling = true;
      _animationController.reverse();
    }
  }

  /// Decides which page goes in which pane. Each page must be placed at most
  /// once because it is moved between panes with a [GlobalKey].
  _Placement _placement(FoldablePaneLayout? layout) {
    final now = _visible;
    final t = _transition;
    // A swipe back shows the state it lands on before the page is popped.
    final nextBody = t != null && t.userDriven ? t.nextBody! : now.body;
    final nextSecondary = t != null && t.userDriven
        ? t.nextSecondary
        : now.secondary;
    final body = <_Slot>[];
    final secondary = <_Slot>[];

    if (t == null) {
      body.add(_Slot(nextBody, _Role.steady));
      if (nextSecondary case final s?) secondary.add(_Slot(s, _Role.steady));
    } else if (layout == null ||
        (layout.primaryVisible && layout.secondaryVisible)) {
      // Split view: each pane slides from its old page to its new page. A
      // page moving to the other pane is shown only in its new pane.
      void slide(List<_Slot> pane, _Entry? from, _Entry? to) {
        if (from?.id == to?.id) {
          if (to != null) pane.add(_Slot(to, _Role.steady));
          return;
        }
        if (from != null &&
            from.id != nextBody.id &&
            from.id != nextSecondary?.id) {
          pane.add(_Slot(from, _Role.outgoing));
        }
        if (to != null) pane.add(_Slot(to, _Role.incoming));
      }

      slide(body, t.body, nextBody);
      slide(secondary, t.secondary, nextSecondary);
    } else {
      // Single pane: the visible pane slides from the page it showed to the
      // page that replaces it. A pane whose page did not change stays still,
      // so only the pane that actually changed animates. The hidden pane gets
      // its page only if it is not used above.
      final showsSecondary = layout.secondaryVisible;
      final visible = showsSecondary ? secondary : body;
      final hidden = showsSecondary ? body : secondary;
      // The visible pane used to show the top page when it is the second one,
      // and the body itself when it is the primary one. When the pane
      // switched (1↔2 pages), the page on screen came from the other pane.
      final from = t.switchesPane
          ? t.visibleBefore
          : showsSecondary
          ? (t.secondary ?? t.body)
          : t.body;
      final to = showsSecondary ? (nextSecondary ?? nextBody) : nextBody;

      if (from.id == to.id) {
        visible.add(_Slot(to, _Role.steady));
      } else {
        visible
          ..add(_Slot(from, _Role.outgoing))
          ..add(_Slot(to, _Role.incoming));
      }
      final hiddenEntry = showsSecondary ? nextBody : nextSecondary;
      if (hiddenEntry != null &&
          hiddenEntry.id != from.id &&
          hiddenEntry.id != to.id) {
        hidden.add(_Slot(hiddenEntry, _Role.steady));
      }
    }

    // Incoming slides over outgoing on push, and the other way on pop.
    int order(_Slot slot) {
      final rank = switch (slot.role) {
        _Role.steady => 0,
        _Role.outgoing => 1,
        _Role.incoming => 2,
      };
      return t != null && !t.isPush && rank > 0 ? 3 - rank : rank;
    }

    body.sort((a, b) => order(a).compareTo(order(b)));
    secondary.sort((a, b) => order(a).compareTo(order(b)));
    return _Placement(body: body, secondary: secondary);
  }

  Widget _pageChild(Page<Object?> page) {
    if (page is FoldablePage) return page.child;
    if (page is MaterialPage) return page.child;
    throw FlutterError(
      'FoldableNavigator only supports FoldablePage and MaterialPage, '
      'got ${page.runtimeType}.',
    );
  }

  /// Wraps a page with the same widget types whatever its role, so hiding,
  /// showing or sliding a page only updates properties. Changing the wrapper
  /// types would move the page to a new parent, which rebuilds everything in
  /// it.
  Widget _frame(_Entry entry, _Role? role, {Size? hiddenSize}) {
    final hidden = role == null;
    final t = _transition;
    final outgoing = role == _Role.outgoing;
    // Every page that is on screen gets the back button while the stack can
    // be popped, in the primary body and in the secondary body: both pop the
    // top page of the branch. Pages that are hidden or sliding out do not.
    final canGoBack = !hidden && !outgoing && _controller.canPop;

    // Cupertino page transition: the page on top slides all the way in while
    // the page below only gives way a third, and the top page casts a shadow
    // while it moves.
    const parallax = 1 / 3;
    Animation<Offset> position = const AlwaysStoppedAnimation(Offset.zero);
    var onTop = false;
    if (t != null && role != null && role != _Role.steady) {
      final entering = role == _Role.incoming;
      onTop = entering == t.isPush;
      final begin = entering
          ? (t.isPush ? const Offset(1, 0) : const Offset(-parallax, 0))
          : Offset.zero;
      final end = entering
          ? Offset.zero
          : (t.isPush ? const Offset(-parallax, 0) : const Offset(1, 0));
      // A swipe back follows the finger: the curve only applies when the
      // animation runs on its own.
      position = (t.userDriven ? _animationController : _animation).drive(
        Tween(begin: begin, end: end),
      );
    }

    final child = _FoldablePageScope(
      page: entry.page,
      canGoBack: canGoBack,
      // Slides and pane resizes repaint only the moving layers.
      child: RepaintBoundary(child: _pageChild(entry.page)),
    );

    return KeyedSubtree(
      key: _subtreeKeys.putIfAbsent(entry.key, GlobalKey.new),
      // Hidden pages get a fixed size so resizing the panes (dragging the
      // divider, pane animations) does not lay them out again.
      child: Positioned(
        left: 0,
        top: 0,
        right: hidden ? null : 0,
        bottom: hidden ? null : 0,
        width: hidden ? hiddenSize!.width : null,
        height: hidden ? hiddenSize!.height : null,
        child: Offstage(
          offstage: hidden,
          child: TickerMode(
            enabled: !hidden,
            child: IgnorePointer(
              ignoring: hidden || outgoing,
              child: ExcludeFocus(
                excluding: hidden || outgoing,
                child: SlideTransition(
                  position: position,
                  // The wrapper stays the same whatever the role, so only
                  // properties change when the page starts or stops moving.
                  child: DecoratedBox(
                    decoration: onTop ? _pageShadow : const BoxDecoration(),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final layout = FoldablePaneLayout.maybeOf(context);
    // The next page change decides how to animate from this layout, and the
    // controller notifies before this build runs.
    _lastLayout = layout;
    _lastCanSplit = FoldableScaffoldScope.maybeOf(context)?.canSplit ?? false;
    final placement = _placement(layout);
    final placed = {
      for (final slot in [...placement.body, ...placement.secondary])
        slot.entry.key,
    };
    final hiddenSize = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        // Pages that are not shown stay alive but hidden, like a Navigator.
        for (var b = 0; b < _controller.branchCount; b++)
          for (final page in _controller.pagesOf(b))
            if (_entry(b, page) case final e when !placed.contains(e.key))
              _frame(e, null, hiddenSize: hiddenSize),
        for (final slot in placement.body) _frame(slot.entry, slot.role),
      ],
    );
  }

  Widget _buildSecondaryBody(BuildContext context) {
    final placement = _placement(FoldablePaneLayout.maybeOf(context));
    return Stack(
      children: [
        for (final slot in placement.secondary) _frame(slot.entry, slot.role),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final transition = _transition;
    // Keep the secondary pane while its old page slides out, unless the
    // slide already shows the pages in the pane that is shown now.
    final bool hasSecondary;
    if (transition != null && transition.userDriven) {
      hasSecondary = transition.nextSecondary != null;
    } else {
      hasSecondary =
          _visible.secondary != null ||
          (transition != null &&
              !transition.switchesPane &&
              transition.secondary != null);
    }

    return _FoldableNavigatorScope(
      state: this,
      revision: _revision,
      child: PopScope(
        canPop: !_controller.canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _controller.pop(result);
        },
        child: Builder(
          builder: (context) {
            final scaffold = widget.builder(
              context,
              Builder(builder: _buildBody),
              hasSecondary ? Builder(builder: _buildSecondaryBody) : null,
            );
            // Tells the scaffold that a page slide is running, so a pane
            // switch would not animate a resize on top of it.
            return FoldablePaneTransitionScope(
              transition: _transitioning,
              // A [Listener] sits on the hit path without taking the pointer
              // from the page, so taps and scrolls still reach it while a drag
              // that started at the left edge becomes a back swipe.
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleBackPointerDown,
                child: scaffold,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Back button for a page inside a [FoldableNavigator].
///
/// Shown on every page that is on screen while the stack can be popped, in
/// the primary body and in the secondary body. Tapping it removes the page it
/// belongs to, together with the pages above it in the branch, so in a split
/// view each pane pops itself instead of the page above it (see
/// [FoldableNavigator.popPageOf]). Use it as `AppBar.leading`.
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
  static bool isVisible(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_FoldablePageScope>()
            ?.canGoBack ??
        false;
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

/// A page and its id in [_FoldableNavigatorState._subtreeKeys].
class _Entry {
  const _Entry(this.branch, this.id, this.page);

  final int branch;
  final Key id;
  final Page<Object?> page;

  (int, Key) get key => (branch, id);
}

class _Visible {
  const _Visible({
    required this.branch,
    required this.ids,
    required this.body,
    required this.secondary,
  });

  final int branch;
  final Set<Key> ids;
  final _Entry body;
  final _Entry? secondary;

  _Entry get top => secondary ?? body;
}

/// A running push/pop slide, holding what was visible before it.
class _Transition {
  const _Transition({
    required this.isPush,
    required this.body,
    required this.secondary,
    required this.switchesPane,
    required this.visibleBefore,
    this.userDriven = false,
    this.nextBody,
    this.nextSecondary,
  });

  final bool isPush;
  final _Entry body;
  final _Entry? secondary;

  /// Whether a single-pane layout switched the visible pane (1↔2 pages), so
  /// the page that was on screen and the new top page both slide in the
  /// pane that is shown now.
  final bool switchesPane;

  /// The page on screen when the transition started, in a single-pane
  /// layout.
  final _Entry visibleBefore;

  /// Whether a swipe drives the transition, before the controller removed
  /// the page. The pages it lands on are [nextBody] and [nextSecondary].
  final bool userDriven;
  final _Entry? nextBody;
  final _Entry? nextSecondary;
}

enum _Role { steady, incoming, outgoing }

/// The shadow the page on top casts while it slides over the one below, like
/// a Cupertino page transition.
const _pageShadow = BoxDecoration(
  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
);

/// Width of the left edge strip where a drag starts a back swipe.
const double _kBackSwipeEdge = 20.0;

/// Speed, in logical pixels per second, a released swipe needs to pop the
/// page even when it has not moved past half the width.
const double _kBackSwipeMinFlingVelocity = 700.0;

class _Slot {
  const _Slot(this.entry, this.role);

  final _Entry entry;
  final _Role role;
}

class _Placement {
  const _Placement({required this.body, required this.secondary});

  final List<_Slot> body;
  final List<_Slot> secondary;
}

class _FoldableNavigatorScope extends InheritedWidget {
  const _FoldableNavigatorScope({
    required this.state,
    required this.revision,
    required super.child,
  });

  final _FoldableNavigatorState state;
  final int revision;

  @override
  bool updateShouldNotify(_FoldableNavigatorScope oldWidget) =>
      revision != oldWidget.revision;
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
