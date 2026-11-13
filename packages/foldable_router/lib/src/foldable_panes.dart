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

  /// Whether the missing frame error was already reported for the current
  /// configuration, to avoid reporting it every frame.
  bool reportedMissing = false;

  /// The area that lays out this branch's panes right now, or `null` when the
  /// branch is not on screen.
  ///
  /// A frame reads it to ask for another layout when it moves without its
  /// area laying out (see [FoldablePanes]): the area then re-measures every
  /// frame and lays the pages out again on the new rectangles, so the screen
  /// never lags behind the data.
  _RawPaneArea? _area;

  /// The page slots currently in the tree for this branch.
  ///
  /// They are re-laid-out when a frame rectangle changes without the pages
  /// being rebuilt, so a page can never keep a stale rectangle on screen.
  final Set<_RenderPaneSlot> _slots = <_RenderPaneSlot>{};

  void _registerSlot(_RenderPaneSlot slot) => _slots.add(slot);

  void _unregisterSlot(_RenderPaneSlot slot) => _slots.remove(slot);

  void _markSlotsNeedingLayout() {
    for (final _RenderPaneSlot slot in _slots.toList()) {
      if (slot.attached) slot.markNeedsLayout();
    }
  }

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

  /// Records the rectangle of [pane].
  ///
  /// Called by the area during its own layout, right after the whole panes
  /// subtree laid out and before the navigators lay out. The slots then read
  /// the final rectangle in the same layout pass, so a page is never drawn on
  /// a placeholder position and never lags a frame behind its frame.
  ///
  /// When a rectangle changes while the area is *not* laying out — a frame
  /// moved on its own, say an animation inside `buildPanes` — the affected
  /// slots are marked for layout so the pages catch up in the same frame; a
  /// stale page is never left on screen.
  void publish(FoldablePane pane, Rect rect) {
    final Rect? old = rectFor(pane);
    if (pane == FoldablePane.primary) {
      primaryRect = rect;
    } else {
      secondaryRect = rect;
    }
    if (old == rect || identical(old, rect)) return;
    final _RawPaneArea? current = _area;
    if (current != null && current.isLayingOut) {
      // The area is laying out: the slots lay out on the new rectangle right
      // after this call, in the same pass.
      return;
    }
    _markSlotsNeedingLayout();
  }

  /// Releases the observables of these metrics.
  void dispose() {
    twoPane.dispose();
    _area = null;
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
/// layout, then places it in [_PaneArea] *below* the navigators of the
/// branches. [_PaneArea] lays the panes out first, reads the frames'
/// rectangles, and only then lays the pages out on them — so a page is never
/// positioned on a placeholder rectangle, not even for one frame.
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
  int _epoch = 0;

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
          child: _PaneArea(
            metrics: widget.metrics,
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

/// Stacks the panes layout under the navigators of the branches and measures
/// the pane frames in the same layout pass, *before* the pages lay out.
///
/// This replaces a plain [Stack]. The first child is the layout returned by
/// [FoldableShellRoute.buildPanes]; right after it lays out, the frames'
/// rectangles are read relative to this area and published, and only then the
/// second child (the navigators) lays out, positioning the pages on the final
/// rectangles. The pages therefore never see a placeholder position — not even
/// for one frame — and can never be drawn in the wrong place.
class _PaneArea extends MultiChildRenderObjectWidget {
  const _PaneArea({required this.metrics, super.children});

  /// The metrics of the branch shown by this area.
  final PaneMetrics metrics;

  @override
  _RawPaneArea createRenderObject(BuildContext context) =>
      _RawPaneArea(metrics);

  @override
  void updateRenderObject(BuildContext context, _RawPaneArea renderObject) {
    renderObject.metrics = metrics;
    // The panes (and so their frames) were rebuilt: re-measure the
    // rectangles and lay the pages out again on them, in this frame.
    renderObject.markNeedsLayout();
  }
}

class _PaneAreaParentData extends ContainerBoxParentData<RenderBox> {}

class _RawPaneArea extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PaneAreaParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PaneAreaParentData> {
  _RawPaneArea(this._metrics) {
    _metrics._area = this;
  }

  PaneMetrics _metrics;

  /// The metrics of the branch this area currently draws.
  PaneMetrics get metrics => _metrics;

  set metrics(PaneMetrics value) {
    if (identical(value, _metrics)) return;
    if (identical(_metrics._area, this)) _metrics._area = null;
    _metrics = value;
    value._area = this;
    markNeedsLayout();
  }

  /// Whether this area is running its own [performLayout].
  ///
  /// A frame laying out while this is `true` is driven by the area, which
  /// re-reads the rectangles right after the subtree; it must not ask for
  /// another layout then (that would loop). When a frame lays out on its own
  /// (say, an animation inside the layout returned by `buildPanes`), it is
  /// `false` and the frame asks the area to re-run.
  bool get isLayingOut => _layingOut;
  bool _layingOut = false;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'The tab area of a two-pane shell has unbounded constraints.',
        ),
        ErrorDescription(
          'The two-pane area fills the space its shell body gives it, so it '
          'needs bounded constraints on both axes.',
        ),
        DiagnosticsProperty<BoxConstraints>('The constraints were', constraints),
      ]);
    }
    return constraints.biggest;
  }

  @override
  void performLayout() {
    _layingOut = true;
    final BoxConstraints inner = BoxConstraints.tight(size);
    RenderBox? child = firstChild;
    if (child != null) {
      // 1. The panes layout: its frames take room and report their sizes.
      child.layout(inner);
      (child.parentData! as _PaneAreaParentData).offset = Offset.zero;
      // 2. Read the frames' rectangles now, while the subtree offsets are
      //    final, and publish them. The pages pick them up in step 3, in this
      //    same layout pass.
      _publishFrames(child, Offset.zero);
      child = childAfter(child);
    }
    // 3. The navigators of the branches: their pages lay out on the final
    //    rectangles just published.
    while (child != null) {
      child.layout(inner);
      (child.parentData! as ContainerBoxParentData<RenderBox>).offset =
          Offset.zero;
      child = childAfter(child);
    }
    _layingOut = false;
  }

  void _publishFrames(RenderObject node, Offset offset) {
    if (node is _RenderPaneFrame) {
      _metrics.publish(node.pane, offset & node.measuredSize);
    }
    node.visitChildren((RenderObject child) {
      final ParentData? data = child.parentData;
      final Offset childOffset = data is BoxParentData
          ? data.offset
          : Offset.zero;
      _publishFrames(child, offset + childOffset);
    });
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void setupParentData(covariant RenderObject child) {
    if (child.parentData is! BoxParentData) {
      child.parentData = _PaneAreaParentData();
    }
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _metrics._area = this;
  }

  @override
  void detach() {
    if (identical(_metrics._area, this)) _metrics._area = null;
    super.detach();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('branch', _metrics.branchIndex));
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
    renderObject.updateMetrics(metrics, pane);
    // The area was rebuilt: measure again, even if the widget is unchanged.
    renderObject.markNeedsLayout();
  }
}

class _RenderPaneFrame extends RenderBox {
  _RenderPaneFrame(this.metrics, this.pane);

  PaneMetrics metrics;
  FoldablePane pane;

  /// Points this frame at [value], moving its frame-count registration.
  ///
  /// Switching tabs rebuilds the panes with the new tab's metrics while the
  /// render object (same position in the tree) is reused; without this the
  /// frame would keep counting against the previous tab.
  void updateMetrics(PaneMetrics value, FoldablePane paneValue) {
    if (identical(value, metrics) && paneValue == pane) return;
    if (attached) {
      if (pane == FoldablePane.primary) {
        metrics.primaryFrames--;
      } else {
        metrics.secondaryFrames--;
      }
      if (paneValue == FoldablePane.primary) {
        value.primaryFrames++;
      } else {
        value.secondaryFrames++;
      }
    }
    metrics = value;
    pane = paneValue;
    value.reportedMissing = false;
  }

  /// The size this frame had at its last layout.
  ///
  /// Recorded here (a box may always read its own size), so that the area can
  /// publish the rectangle without reading the size of a grand-child, which
  /// the layout protocol forbids.
  Size measuredSize = Size.zero;

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
    // sizedByParent: the size was set by performResize from computeDryLayout.
    measuredSize = size;
    //
    // The rectangle is normally published by [_RawPaneArea], which reads it
    // right after the whole panes subtree laid out and before the navigators
    // lay out; a frame must never publish a placeholder position itself.
    //
    // When this frame lays out on its own — an animation inside the layout
    // returned by buildPanes moved it, say, and this frame is a relayout
    // boundary so the area did not run — the area will not see the move. The
    // offsets up to the area are final here (the area and every node between
    // are clean, otherwise they would be laying us out), so publish the real
    // rectangle now and let the affected pages catch up in this same frame.
    final _RawPaneArea? area = metrics._area;
    if (area == null || !area.attached || area.isLayingOut) return;
    Offset offset = Offset.zero;
    RenderObject? node = this;
    while (node != null && !identical(node, area)) {
      final ParentData? parentData = node.parentData;
      if (parentData is BoxParentData) offset += parentData.offset;
      node = node.parent;
    }
    if (!identical(node, area)) return; // Not under the area (detaching).
    metrics.publish(pane, offset & size);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Frames paint nothing: the rectangle was published during layout.
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

/// Draws the content of one page and gates it while it is hidden.
///
/// One of these wraps the content of every page of a tab, *inside* the page
/// transition: the transition itself is wrapped by [PaneSlot] in the route,
/// so that everything the transition paints stays in the pane.
///
/// In one-pane tabs the content is laid out full-area, exactly like the pages
/// of the root navigator. In two-pane tabs the page slots move it to the
/// frame; this widget hides the pages deeper than the second one without
/// unmounting them.
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
          return Listener(
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

/// Places the page — transition included — in the rectangle of its frame.
///
/// In a two-pane tab the page transition is the slot's child, so the
/// transition is laid out on the pane rectangle and everything it paints
/// (scrim, background, snapshot, scale, slide, fade) is clipped to it. In a
/// one-pane tab the slot is transparent (full area, origin, no clip), exactly
/// like drawing the page without a slot.
class PaneSlot extends StatelessWidget {
  /// Creates the slot of one page.
  const PaneSlot({
    super.key,
    required this.metrics,
    required this.entry,
    required this.child,
    this.clip = false,
  });

  /// The metrics of the tab.
  final PaneMetrics metrics;

  /// The page drawn in this slot.
  final PaneEntryRef entry;

  /// The content of the page (in a tab, the page transition).
  final Widget child;

  /// Whether the page is clipped to its pane rectangle. Only two-pane tabs
  /// need it; one-pane tabs keep the exact behavior of a page without a slot.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    // Lays out again whenever the shell body (and so the panes) rebuilt.
    context.dependOnInheritedWidgetOfExactType<PaneEpoch>();
    return _RawPaneSlot(
      metrics: metrics,
      entry: entry,
      clip: clip,
      child: child,
    );
  }
}

class _RawPaneSlot extends SingleChildRenderObjectWidget {
  const _RawPaneSlot({
    required this.metrics,
    required this.entry,
    required this.clip,
    required super.child,
  });

  final PaneMetrics metrics;
  final PaneEntryRef entry;
  final bool clip;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneSlot(metrics, entry, clip);

  @override
  _PaneSlotElement createElement() => _PaneSlotElement(this);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneSlot renderObject) {
    renderObject.clip = clip;
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
  _RenderPaneSlot(this.metrics, this.entry, this._clip) : super(null);

  final PaneMetrics metrics;
  final PaneEntryRef entry;
  bool _clip;

  /// Whether to clip the page (transition included) to its pane rectangle.
  bool get clip => _clip;

  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

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
    // _RawPaneArea published this rectangle during its own layout, before this
    // slot laid out, so it is the final value (never a placeholder). Paint
    // uses the same offset assigned here, so the page cannot drift between
    // layout and paint.
    child.layout(BoxConstraints.tight(rect.size));
    parentData.offset = rect.topLeft;
  }

  /// The offset of the page, as assigned during layout.
  ///
  /// Paint, hit testing and the paint transform all use the very offset the
  /// layout pass chose, so a page is always drawn exactly where it was laid
  /// out; the rectangle can never change between layout and paint without the
  /// slot being laid out again (see [PaneMetrics.publish]).
  Offset _childOrigin() {
    final RenderBox? child = this.child;
    if (child == null) return Offset.zero;
    final BoxParentData parentData = child.parentData! as BoxParentData;
    return parentData.offset;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_visible) return false;
    final RenderBox? child = this.child;
    if (child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOrigin(),
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
    final Offset origin = _childOrigin();
    transform.multiply(Matrix4.translationValues(origin.dx, origin.dy, 0));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible) return;
    final RenderBox? child = this.child;
    if (child == null) return;
    final Offset origin = _childOrigin();
    if (_clip) {
      // The pane rectangle, expressed in this slot's coordinates, is the
      // child's box: the transition is laid out on it. Clipping it keeps the
      // parts a transition moves outside (a slide, a scale, ...) from
      // reaching the other pane.
      final Rect clipRect = origin & child.size;
      context.pushClipRect(
        needsCompositing,
        offset,
        clipRect,
        (PaintingContext context, Offset offset) =>
            context.paintChild(child, origin + offset),
      );
      return;
    }
    context.paintChild(child, origin + offset);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    metrics._registerSlot(this);
  }

  @override
  void detach() {
    metrics._unregisterSlot(this);
    super.detach();
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
