part of 'foldable_navigator.dart';

/// A [FoldableNavigator] that shows only the top page of the current branch,
/// full screen.
///
/// Create it with [FoldableNavigator.stack]. Unlike [FoldableSplitNavigator],
/// it has no secondary body and does not keep pages around: the pages below
/// the top one, and every page of the other branches, are not mounted, so
/// their state is thrown away when they leave the screen.
///
/// Push, pop, [FoldableBackButton], the system back button and the left-edge
/// swipe back work like in [FoldableSplitNavigator], with the same Cupertino
/// slide. A stack may start empty: it shows nothing until the first page
/// arrives, then that page appears without a slide.
///
/// ```dart
/// FoldableNavigator.stack(controller: _controller);
/// ```
class FoldableStackNavigator extends FoldableNavigator {
  const FoldableStackNavigator({
    required FoldableNavigatorController controller,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.transitionCurve = Curves.fastOutSlowIn,
    Key? key,
  }) : super.base(controller: controller, key: key);

  /// Duration of the push/pop slide. [Duration.zero] disables it, and the
  /// swipe-back gesture with it.
  final Duration transitionDuration;

  /// Curve of the push/pop slide.
  final Curve transitionCurve;

  @override
  State<FoldableStackNavigator> createState() => _FoldableStackNavigatorState();
}

class _FoldableStackNavigatorState extends State<FoldableStackNavigator>
    with SingleTickerProviderStateMixin, _FoldableAppBarHistory {
  final Map<Key, GlobalKey> _subtreeKeys = {};
  final _transitioning = ValueNotifier<bool>(false);

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: widget.transitionDuration,
  )..addStatusListener(_onTransitionStatus);
  late CurvedAnimation _animation = CurvedAnimation(
    parent: _animationController,
    curve: widget.transitionCurve,
  );

  late int _branch;
  Page<Object?>? _top;
  late Set<Key> _ids;
  _StackTransition? _transition;

  /// Bumped on every controller change so listening widgets rebuild.
  int _revision = 0;

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
    _branch = _controller.currentIndex;
    _top = _controller.pages.isEmpty ? null : _controller.pages.last;
    _ids = {for (final page in _controller.pages) _idOf(page)};
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
  void didUpdateWidget(covariant FoldableStackNavigator oldWidget) {
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
      _branch = _controller.currentIndex;
      _top = _controller.pages.isEmpty ? null : _controller.pages.last;
      _ids = {for (final page in _controller.pages) _idOf(page)};
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

  Key? _idOfTop(Page<Object?>? page) => page == null ? null : _idOf(page);

  void _onControllerChanged() {
    final branch = _controller.currentIndex;
    final pages = _controller.pages;
    final top = pages.isEmpty ? null : pages.last;
    final ids = {for (final page in pages) _idOf(page)};
    final previousTop = _top;
    final previousIds = _ids;
    final branchChanged = branch != _branch;
    _branch = branch;
    _top = top;
    _ids = ids;

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
    final topChanged = _idOfTop(previousTop) != _idOfTop(top);
    if (top == null ||
        previousTop == null ||
        branchChanged ||
        widget.transitionDuration == Duration.zero ||
        !topChanged) {
      // The first page of a stack that started empty just appears: there is
      // nothing to slide over. The same when the stack empties.
      _transition = null;
      _animationController.value = 1;
    } else {
      // A new top page means push; one that was already below means pop.
      final isPush = !previousIds.contains(_idOf(top));
      _transition = _StackTransition(
        isPush: isPush,
        from: previousTop,
        to: top,
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

  /// Pages that are not on screen are not kept: only the top page and the
  /// pages of a running slide stay in [_subtreeKeys].
  void _cleanUpKeys() {
    final alive = <Key>{
      if (_top case final top?) _idOf(top),
      if (_transition case final t?) ...[_idOf(t.from), _idOf(t.to)],
    };
    _subtreeKeys.removeWhere((id, _) => !alive.contains(id));
  }

  /// Whether a swipe from the left edge can start a pop now.
  bool get _canStartBackSwipe =>
      widget.transitionDuration != Duration.zero &&
      _transition == null &&
      !_backSwipeDragging &&
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
    final from = _top;
    if (!mounted || !_canStartBackSwipe || from == null) return;
    final pages = _controller.pages;
    // What stays visible when the top page is gone.
    final nextTop = pages[pages.length - 2];
    _backSwipeDragging = true;
    setState(() {
      _transition = _StackTransition(
        isPush: false,
        from: from,
        to: nextTop,
        userDriven: true,
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

  Widget _pageChild(Page<Object?> page) {
    if (page is FoldablePage) return page.child;
    if (page is MaterialPage) return page.child;
    throw FlutterError(
      'FoldableNavigator only supports FoldablePage and MaterialPage, '
      'got ${page.runtimeType}.',
    );
  }

  /// Wraps a page with the same widget types whatever its role, so the page
  /// keeps its state while it slides in or out.
  Widget _frame(Page<Object?> page, _StackRole role) {
    final t = _transition;
    final outgoing = role == _StackRole.outgoing;
    // The page on screen shows the back button while the stack can be
    // popped. The page sliding out does not.
    final canGoBack = !outgoing && _controller.canPop;

    // Cupertino page transition: the page on top slides all the way in while
    // the page below only gives way a third, and the top page casts a shadow
    // while it moves.
    const parallax = 1 / 3;
    Animation<Offset> position = const AlwaysStoppedAnimation(Offset.zero);
    var onTop = false;
    if (t != null && role != _StackRole.steady) {
      final entering = role == _StackRole.incoming;
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
      page: page,
      canGoBack: canGoBack,
      // Slides repaint only the moving layers.
      child: RepaintBoundary(child: _pageChild(page)),
    );

    return KeyedSubtree(
      key: _subtreeKeys.putIfAbsent(_idOf(page), GlobalKey.new),
      child: Positioned(
        left: 0,
        top: 0,
        right: 0,
        bottom: 0,
        child: IgnorePointer(
          ignoring: outgoing,
          child: ExcludeFocus(
            excluding: outgoing,
            child: SlideTransition(
              position: position,
              child: DecoratedBox(
                decoration: onTop ? _pageShadow : const BoxDecoration(),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The pages to show: the top page, or the two pages of a running slide.
  /// Empty while a stack that started without roots waits for its first page.
  List<Widget> _frames() {
    final top = _top;
    final transition = _transition;
    if (transition == null) {
      return [if (top != null) _frame(top, _StackRole.steady)];
    }
    return transition.isPush
        ? [
            _frame(transition.from, _StackRole.outgoing),
            _frame(transition.to, _StackRole.incoming),
          ]
        : [
            _frame(transition.to, _StackRole.incoming),
            _frame(transition.from, _StackRole.outgoing),
          ];
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames();
    return _FoldableNavigatorScope(
      controller: _controller,
      transitioning: _transitioning,
      revision: _revision,
      child: PopScope(
        canPop: !_controller.canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _controller.pop(result);
        },
        child: Builder(
          builder: (context) {
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _handleBackPointerDown,
              child: frames.isEmpty
                  ? const SizedBox.expand()
                  : Stack(fit: StackFit.expand, children: frames),
            );
          },
        ),
      ),
    );
  }
}

/// A running push/pop slide between the top page before the change and the
/// top page after it.
class _StackTransition {
  const _StackTransition({
    required this.isPush,
    required this.from,
    required this.to,
    this.userDriven = false,
  });

  final bool isPush;
  final Page<Object?> from;
  final Page<Object?> to;

  /// Whether a swipe drives the transition, before the controller removed the
  /// page.
  final bool userDriven;
}

enum _StackRole { steady, incoming, outgoing }
