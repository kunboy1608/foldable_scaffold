import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'foldable_shell_route.dart';

/// Which pane of a two-pane tab the calling page is shown in.
///
/// Pages read it with `FoldableRouter.paneOf(context)`; the calling widget is
/// rebuilt when the answer changes.
enum FoldablePane {
  /// The tab shows one pane (the default): the page, if visible, fills the
  /// whole area of the tab.
  single,

  /// The left pane of a tab whose shell returned two panes from
  /// [FoldableShellRoute.buildPanes].
  ///
  /// With a stack of two pages or more this is the page right below the top
  /// one. With a single page it is the page itself: a lone page of a
  /// two-pane tab sits on the left, and the right pane is empty.
  primary,

  /// The right pane of a tab whose shell returned two panes: this is the top
  /// page of the tab, shown when the stack has at least two pages.
  secondary,
}

/// The material a shell gets to draw the two-pane layout of one tab.
///
/// [FoldableShellRoute.buildPanes] receives an instance for the tab being
/// shown and either returns `null` (the tab uses one pane, the classic
/// full-screen stack) or a widget tree that places [primary] and, when
/// [hasSecondary], [secondary]. For example:
///
/// ```dart
/// @override
/// Widget? buildPanes(BuildContext context, FoldablePanes panes) {
///   if (panes.constraints.maxWidth < 840) return null; // one pane
///   return Row(
///     children: [
///       Expanded(flex: 2, child: panes.primary),
///       const VerticalDivider(width: 1),
///       Expanded(
///         flex: 3,
///         child: panes.hasSecondary
///             ? panes.secondary
///             : const Center(child: Text('Nothing selected')),
///       ),
///     ],
///   );
/// }
/// ```
///
/// [primary] and [secondary] are *placeholder frames*: they take room in the
/// layout and mark the rectangle the pages must be drawn in. The pages
/// themselves are still built, laid out and animated by the navigator of the
/// tab; the frame only says where. As a consequence:
///
/// * The pages are drawn *above* the layout returned by
///   [FoldableShellRoute.buildPanes]: the frames themselves paint nothing, so
///   anything the app draws on top of a frame (say, a divider or a background)
///   stays visible around it.
/// * Taps outside both frames go to the layout (the app's chrome); taps inside
///   a frame go to the page drawn in it.
/// * A frame must get bounded constraints (put it in a `SizedBox`, an
///   `Expanded`, a `Positioned.fill`, ...). Its rectangle is measured when it
///   is laid out, so it may not be under a scale transform.
/// * The rectangles are re-measured every time the shell body rebuilds (a
///   `MediaQuery` change, a size change, a different ratio returned by
///   [FoldableShellRoute.buildPanes]): the pages match their new frame on the
///   same frame. A layout that changes without any of those (say, an
///   animation *inside* the widget returned by
///   [FoldableShellRoute.buildPanes]) makes the pages catch up on the next
///   frame.
class FoldablePanes {
  /// Creates the panes of one tab. Only the router builds instances.
  FoldablePanes._({
    required this.branchIndex,
    required this.constraints,
    required this.hasSecondary,
    required this._metrics,
  });

  /// Index, in [FoldableShellRoute.branches], of the tab these panes are for.
  final int branchIndex;

  /// The constraints of the area of the tab, i.e. of the whole two-pane
  /// layout (frames included).
  final BoxConstraints constraints;

  /// Whether the stack of the tab has at least two pages, i.e. whether there
  /// is a top page to show in [secondary].
  ///
  /// When this is `false` the app may place something else in the right side
  /// (an empty state, for example) or leave it empty. When this is `true` the
  /// app must place [secondary]: the pages of a tab with two or more pages
  /// are laid out in both frames, and forgetting one is a bug the router
  /// reports with a [FlutterError] in debug builds.
  final bool hasSecondary;

  final PaneMetrics _metrics;

  /// The frame of the left pane. Must be placed by the app.
  ///
  /// See the class documentation for what a frame is (and is not).
  late final Widget primary = PaneFrame(
    metrics: _metrics,
    pane: FoldablePane.primary,
  );

  /// The frame of the right pane, required when [hasSecondary] is `true`.
  late final Widget secondary = PaneFrame(
    metrics: _metrics,
    pane: FoldablePane.secondary,
  );
}

/// The mutable layout state of the panes of one tab.
///
/// One instance per branch, created with the shell and kept while it lives.
/// The frames publish their rectangles in it when they lay out; the page
/// slots read them when they lay out, which happens later in the same frame
/// because the panes come first in the stack of the tab area.
class PaneMetrics {
  /// Creates the metrics of a branch. Only the router builds instances.
  PaneMetrics(this.branchIndex);

  /// The branch these metrics belong to.
  final int branchIndex;

  /// Whether the current tab is drawn with two panes.
  ///
  /// Updated by the shell body when it calls
  /// [FoldableShellRoute.buildPanes] (before the pages rebuild in the same
  /// frame), after the panes and before the pages.
  final ValueNotifier<bool> twoPane = ValueNotifier<bool>(false);

  /// Whether the stack of the tab has at least two pages, as of the last
  /// time the panes were built.
  bool hasSecondary = false;

  /// Length of the stack of the tab, as of the last time the panes were
  /// built.
  int stackLength = 0;

  /// Rectangle of the left frame, in the coordinates of the tab area.
  Rect? primaryRect;

  /// Rectangle of the right frame, in the coordinates of the tab area.
  Rect? secondaryRect;

  /// Number of left frames currently in the tree.
  int primaryFrames = 0;

  /// Number of right frames currently in the tree.
  int secondaryFrames = 0;

  /// Whether the shell body has already been built during the frame being
  /// laid out: its pages are rebuilt (and laid out again) by that build, so a
  /// rectangle change does not need to request another one.
  bool builtThisFrame = false;

  /// Whether the missing frame error was already reported for the current
  /// configuration, to avoid reporting it every frame.
  bool reportedMissing = false;

  /// Key of the widget that holds the tab area; frames measure themselves
  /// against it.
  GlobalKey? areaKey;

  /// Element of the shell body, used to rebuild it when a frame moves
  /// without the shell body being rebuilt (see [FoldablePanes]).
  Element? areaElement;

  /// The pane where the last pointer-down landed, consumed by the next
  /// user-triggered `Navigator.maybePop` (see `FoldableRouter` documentation
  /// about the back buttons).
  FoldablePane? pointerPane;

  /// The rectangle the frame of [pane] currently has, if measured.
  Rect? rectFor(FoldablePane pane) => switch (pane) {
    FoldablePane.primary => primaryRect,
    FoldablePane.secondary => secondaryRect,
    FoldablePane.single => null,
  };

  void publish(FoldablePane pane, Rect rect) {
    final Rect? old = rectFor(pane);
    if (pane == FoldablePane.primary) {
      primaryRect = rect;
    } else {
      secondaryRect = rect;
    }
    if (old == rect || identical(old, rect)) return;
    if (builtThisFrame) return;
    final Element? element = areaElement;
    if (element != null && element.mounted) {
      // Legal: this runs while the render tree lays out (the frames lay out
      // after the build phase), and it schedules the rebuild for the next
      // frame.
      element.markNeedsBuild();
    }
  }

  /// Releases the observables of these metrics.
  void dispose() {
    twoPane.dispose();
    areaElement = null;
    areaKey = null;
  }
}

/// What a page slot needs to know about the page it draws.
///
/// Implemented by the router for every entry of its stacks; the pane layout
/// only reads it (and never changes it).
abstract class PaneEntryRef {
  /// The pane the page is assigned to; `single` in one-pane tabs.
  ValueNotifier<FoldablePane> get pane;

  /// Distance from the top of the stack: `0` is the top page.
  ValueNotifier<int> get position;

  /// Whether the entry left its stack; its pane and visibility are then
  /// frozen at the values it had when it left, so that it keeps animating
  /// out of the pane it was shown in.
  bool get paneFrozen;

  /// The pane frozen by [paneFrozen].
  FoldablePane? get frozenPane;

  /// Whether the page was hidden (not drawn) when it left its stack.
  bool get frozenHidden;
}

/// Makes the pane of a page readable (and watchable) by its content.
///
/// [FoldableRouter.paneOf] and [FoldableRouter.close] look it up.
class PaneScope extends InheritedNotifier<ValueNotifier<FoldablePane>> {
  /// Creates a scope around the content of one page.
  const PaneScope({
    super.key,
    required this.entry,
    required ValueNotifier<FoldablePane> super.notifier,
    required super.child,
  });

  /// The page whose pane this scope reports.
  final PaneEntryRef entry;

  /// The scope above [context], if any, registering a dependency: the caller
  /// is rebuilt when the pane changes.
  static PaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneScope>();

  /// The scope above [context], if any, without registering a dependency.
  static PaneScope? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PaneScope>();
}

/// Tells the page slots that the shell body was built again, so that they
/// lay out again and pick up the current frame rectangles.
class PaneEpoch extends InheritedWidget {
  /// Creates the marker.
  const PaneEpoch({super.key, required this.epoch, required super.child});

  /// A counter bumped on every build of the shell body.
  final int epoch;

  @override
  bool updateShouldNotify(PaneEpoch oldWidget) => oldWidget.epoch != epoch;
}

/// Builds the two-pane layout of the current tab around the navigators.
///
/// The tab area is a [LayoutBuilder]: every time it lays out (or the shell
/// body rebuilds) the builder asks [FoldableShellRoute.buildPanes] for the
/// layout, then places it in a stack *below* the navigators of the branches.
/// The frames of the layout measure themselves when they lay out; the pages,
/// laid out later in the same frame, position themselves on those rectangles.
class BranchArea extends StatefulWidget {
  /// Creates the tab area.
  const BranchArea({
    super.key,
    required this.route,
    required this.metrics,
    required this.stackLength,
    required this.child,
    required this.onBuilt,
  });

  /// The shell that decides the layout of the tab.
  final FoldableShellRoute route;

  /// The metrics of the current branch.
  final PaneMetrics metrics;

  /// Length of the stack of the current branch.
  final int stackLength;

  /// The navigators of the branches (the pages are drawn above the panes).
  final Widget child;

  /// Called during the build with the panes of the tab and whether the shell
  /// returned two panes.
  final void Function(FoldablePanes panes, bool twoPane) onBuilt;

  @override
  State<BranchArea> createState() => _BranchAreaState();
}

class _BranchAreaState extends State<BranchArea> {
  final GlobalKey _areaKey = GlobalKey(debugLabel: 'foldable pane area');
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(BranchArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.metrics, widget.metrics)) {
      oldWidget.metrics.areaElement = null;
      oldWidget.metrics.areaKey = null;
      _attach();
    }
  }

  void _attach() {
    widget.metrics
      ..areaElement = context as Element
      ..areaKey = _areaKey;
  }

  @override
  void dispose() {
    widget.metrics
      ..areaElement = null
      ..areaKey = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild the panes when the window metrics change, even if the
    // constraints of the tab do not.
    MediaQuery.maybeOf(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final FoldablePanes panes = FoldablePanes._(
          branchIndex: widget.metrics.branchIndex,
          constraints: constraints,
          hasSecondary: widget.stackLength >= 2,
          metrics: widget.metrics,
        );
        final Widget? layout = widget.route.buildPanes(context, panes);
        widget.onBuilt(panes, layout != null);
        _epoch++;
        return PaneEpoch(
          epoch: _epoch,
          child: Stack(
            key: _areaKey,
            fit: StackFit.expand,
            children: <Widget>[
              if (layout != null) layout else const SizedBox.shrink(),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

/// The placeholder of one pane: takes room, paints nothing, and remembers
/// its rectangle.
class PaneFrame extends StatelessWidget {
  /// Creates a frame. Apps get frames from [FoldablePanes].
  const PaneFrame({super.key, required this.metrics, required this.pane});

  /// The metrics of the tab.
  final PaneMetrics metrics;

  /// The pane this frame is for.
  final FoldablePane pane;

  @override
  Widget build(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<PaneEpoch>();
    return _RawPaneFrame(metrics: metrics, pane: pane);
  }
}

class _RawPaneFrame extends LeafRenderObjectWidget {
  const _RawPaneFrame({required this.metrics, required this.pane});

  final PaneMetrics metrics;
  final FoldablePane pane;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneFrame(metrics, pane);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneFrame renderObject) {
    // The area was rebuilt: measure again, even if the widget is unchanged.
    renderObject.markNeedsLayout();
  }
}

class _RenderPaneFrame extends RenderBox {
  _RenderPaneFrame(this.metrics, this.pane);

  final PaneMetrics metrics;
  final FoldablePane pane;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'The ${pane.name} frame of a two-pane shell has unbounded constraints.',
        ),
        ErrorDescription(
          'A frame only reserves room and marks the rectangle the pages are '
          'drawn in, so it needs bounded constraints on both axes.',
        ),
        ErrorHint(
          'Put FoldablePanes.primary (and FoldablePanes.secondary) inside '
          'something that bounds them, for example an Expanded inside a Row '
          'or a Column, a SizedBox or a Positioned.fill.',
        ),
        DiagnosticsProperty<BoxConstraints>(
          'The constraints were',
          constraints,
        ),
      ]);
    }
    return constraints.biggest;
  }

  @override
  void performLayout() {
    // sizedByParent: size was set by performResize from computeDryLayout.
    // Publish the size now: the position (offsets above) may still be stale,
    // it is refreshed in paint below.
    _publishSizeOnly();
  }

  void _publishSizeOnly() {
    metrics.publish(pane, Offset.zero & size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Frames paint nothing; paint happens after layout, so every offset above
    // is final now: publish the live rectangle.
    _publish();
  }

  void _publish() {
    final BuildContext? areaContext = metrics.areaKey?.currentContext;
    final RenderObject? area = areaContext?.findRenderObject();
    if (area is! RenderBox || !area.attached) return;
    // The transform only covers the panes subtree (we stop at the tab area),
    // so it is made of paint offsets: reading sizes above the area is not
    // allowed during layout.
    final Matrix4 transform = getTransformTo(area);
    metrics.publish(
      pane,
      MatrixUtils.transformRect(transform, Offset.zero & size),
    );
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    if (pane == FoldablePane.primary) {
      metrics.primaryFrames++;
    } else {
      metrics.secondaryFrames++;
    }
    metrics.reportedMissing = false;
  }

  @override
  void detach() {
    if (pane == FoldablePane.primary) {
      metrics.primaryFrames--;
    } else {
      metrics.secondaryFrames--;
    }
    super.detach();
  }

  // A frame is invisible and transparent to taps: it is only a measurement.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<FoldablePane>('pane', pane));
  }
}

/// Draws the content of one page into the rectangle of its pane.
///
/// One of these wraps the content of every page of a tab. In one-pane tabs it
/// draws the content full-area, exactly like the pages of the root navigator:
/// the navigator itself decides what to paint (the page below an opaque page
/// stays out of the screen but is still laid out, as with a
/// `MaterialPageRoute`). In two-pane tabs it moves the content to its frame
/// and hides the pages deeper than the second one without unmounting them.
class PanePageView extends StatelessWidget {
  /// Creates the view of one page.
  const PanePageView({
    super.key,
    required this.metrics,
    required this.entry,
    required this.popGate,
    required this.contentBuilder,
  });

  /// The metrics of the tab.
  final PaneMetrics metrics;

  /// The page drawn by this view.
  final PaneEntryRef entry;

  /// Builds the content of the page.
  final WidgetBuilder contentBuilder;

  /// Optional gate that enables or disables the back gesture of the page
  /// (see the delegate), the way `_EntryPage` does for the root navigator.
  final ValueListenable<bool>? popGate;

  @override
  Widget build(BuildContext context) {
    final Widget content = popGate == null
        ? Builder(builder: contentBuilder)
        : PanePopGate(gate: popGate!, builder: contentBuilder);
    return PaneScope(
      entry: entry,
      notifier: entry.pane,
      child: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          entry.position,
          metrics.twoPane,
        ]),
        child: content,
        builder: (BuildContext context, Widget? content) {
          final bool twoPane = metrics.twoPane.value;
          final bool hidden =
              twoPane && !entry.paneFrozen && entry.position.value > 1;
          return PaneSlot(
            metrics: metrics,
            entry: entry,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent event) =>
                  metrics.pointerPane = entry.pane.value,
              onPointerUp: (PointerEvent event) => _clearPointer(metrics),
              onPointerCancel: (PointerEvent event) => _clearPointer(metrics),
              child: TickerMode(
                enabled: !hidden,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: HeroMode(
                    // Heroes only fly in one-pane tabs; in a two-pane tab the
                    // page below stays visible, so a flight would double it.
                    enabled: !twoPane,
                    child: content!,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static void _clearPointer(PaneMetrics metrics) {
    // Cleared after the tap handlers of this event have run: a BackButton
    // calls maybePop from the tap callback, before this microtask.
    scheduleMicrotask(() => metrics.pointerPane = null);
  }
}

/// A [PopScope] whose `canPop` follows [gate] (moved from the delegate, kept
/// unchanged).
class PanePopGate extends StatefulWidget {
  /// Creates the gate.
  const PanePopGate({super.key, required this.gate, required this.builder});

  /// Whether a user-initiated pop may pop the page.
  final ValueListenable<bool> gate;

  /// The content of the page.
  final WidgetBuilder builder;

  @override
  State<PanePopGate> createState() => _PanePopGateState();
}

class _PanePopGateState extends State<PanePopGate> {
  @override
  void initState() {
    super.initState();
    widget.gate.addListener(_onGateChanged);
  }

  @override
  void didUpdateWidget(PanePopGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) {
      oldWidget.gate.removeListener(_onGateChanged);
      widget.gate.addListener(_onGateChanged);
    }
  }

  @override
  void dispose() {
    widget.gate.removeListener(_onGateChanged);
    super.dispose();
  }

  void _onGateChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.gate.value,
    child: Builder(builder: widget.builder),
  );
}

/// Places the content of one page in the rectangle of its frame.
class PaneSlot extends StatelessWidget {
  /// Creates the slot of one page.
  const PaneSlot({
    super.key,
    required this.metrics,
    required this.entry,
    required this.child,
  });

  /// The metrics of the tab.
  final PaneMetrics metrics;

  /// The page drawn in this slot.
  final PaneEntryRef entry;

  /// The content of the page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Lays out again whenever the shell body (and so the panes) rebuilt.
    context.dependOnInheritedWidgetOfExactType<PaneEpoch>();
    return _RawPaneSlot(metrics: metrics, entry: entry, child: child);
  }
}

class _RawPaneSlot extends SingleChildRenderObjectWidget {
  const _RawPaneSlot({
    required this.metrics,
    required this.entry,
    required super.child,
  });

  final PaneMetrics metrics;
  final PaneEntryRef entry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneSlot(metrics, entry);

  @override
  _PaneSlotElement createElement() => _PaneSlotElement(this);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneSlot renderObject) {
    renderObject.markNeedsLayout();
  }
}

class _PaneSlotElement extends SingleChildRenderObjectElement {
  _PaneSlotElement(_RawPaneSlot super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final _RenderPaneSlot render = renderObject as _RenderPaneSlot;
    if (render.isVisible) super.debugVisitOnstageChildren(visitor);
  }
}

class _RenderPaneSlot extends RenderShiftedBox {
  _RenderPaneSlot(this.metrics, this.entry) : super(null);

  final PaneMetrics metrics;
  final PaneEntryRef entry;
  bool _visible = false;

  /// Whether the page is actually painted (and reachable) right now.
  bool get isVisible => _visible;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  /// The pane the page is drawn in, or `null` when it is hidden (a two-pane
  /// tab only draws two pages: the deeper ones stay alive, laid out, out of
  /// the screen).
  FoldablePane? _resolvePane() {
    if (entry.paneFrozen) {
      return entry.frozenHidden ? null : entry.frozenPane;
    }
    if (!metrics.twoPane.value) return FoldablePane.single;
    final int position = entry.position.value;
    if (position == 0) {
      // A lone page of a two-pane tab sits on the left.
      return metrics.stackLength >= 2
          ? FoldablePane.secondary
          : FoldablePane.primary;
    }
    if (position == 1) return FoldablePane.primary;
    return null;
  }

  @override
  void performLayout() {
    // sizedByParent: size was set by performResize from computeDryLayout.
    final RenderBox? child = this.child;
    if (child == null) {
      _visible = false;
      return;
    }
    final BoxParentData parentData = child.parentData! as BoxParentData;
    final FoldablePane? pane = _resolvePane();
    _visible = pane != null;
    if (pane == null) {
      // Kept alive (and laid out) like a maintained route: it may come back
      // when a page above it pops. It is not painted, not hit-tested, out of
      // semantics and its tickers are stopped (see PanePageView).
      child.layout(constraints, parentUsesSize: false);
      parentData.offset = Offset.zero;
      return;
    }
    final Rect? rect = pane == FoldablePane.single
        ? null
        : metrics.rectFor(pane);
    if (rect == null || !rect.size.isFinite || rect.isEmpty) {
      // No rectangle (yet): the page takes the whole area. This happens for
      // one frame if the app did not place the frame it needs (reported as an
      // error in debug) and while a page animates out of a pane whose frame
      // is gone.
      child.layout(constraints);
      parentData.offset = Offset.zero;
      return;
    }
    // The position may be stale (offsets above are assigned after children
    // lay out); paint() corrects it once they are final. The size is exact.
    child.layout(BoxConstraints.tight(rect.size));
    parentData.offset = rect.topLeft;
  }

  /// The rectangle of the page right now: live offsets during paint and hit
  /// testing, last-published size during layout.
  Offset _liveOrigin() {
    final FoldablePane? pane = _resolvePane();
    if (pane == null) return Offset.zero;
    final Rect? rect = pane == FoldablePane.single
        ? null
        : metrics.rectFor(pane);
    return rect?.topLeft ?? Offset.zero;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_visible) return false;
    final RenderBox? child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _liveOrigin(),
      position: position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  bool paintsChild(RenderBox child) {
    assert(child.parent == this);
    return _visible;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(
      Matrix4.translationValues(_liveOrigin().dx, _liveOrigin().dy, 0),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible) return;
    final RenderBox? child = this.child;
    if (child == null) return;
    context.paintChild(child, _liveOrigin() + offset);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (!_visible) return;
    super.visitChildrenForSemantics(visitor);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('visible', _visible));
  }
}
