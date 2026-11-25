import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable_core/foldable_core.dart';

/// Mutable state needed by the page hosts of one branch.
///
/// This deliberately contains no layout measurements. Pane rectangles are
/// supplied as [FoldablePaneRects] data by the host layout.
class PaneMetrics {
  /// Creates branch state.
  PaneMetrics(this.branchIndex, this.transitions);

  /// The branch index owning this state.
  final int branchIndex;

  /// The shell transition signal shared by all branches.
  final FoldablePaneTransitions transitions;

  /// Whether the current host supplied two visible pane rectangles.
  final ValueNotifier<bool> twoPane = ValueNotifier<bool>(false);

  /// Number of pages in the branch stack.
  int stackLength = 0;

  /// The pane where the last pointer-down landed.
  FoldablePane? pointerPane;

  /// Releases this state.
  void dispose() => twoPane.dispose();
}

/// Internal owner attached to a page's [FoldablePaneScope].
abstract class PaneEntryRef implements FoldablePaneOwner {
  /// The pane assigned to the page.
  ValueNotifier<FoldablePane> get pane;

  /// Distance from the top of the stack: zero is the top page.
  ValueNotifier<int> get position;

  /// Whether the page is leaving its stack and keeps its old pane.
  bool get paneFrozen;

  /// The pane retained while [paneFrozen].
  FoldablePane? get frozenPane;

  /// Whether the retained page is hidden.
  bool get frozenHidden;
}

/// Draws one page and keeps deeper pages mounted but inactive.
class PanePageView extends StatelessWidget {
  /// Creates a page view.
  const PanePageView({
    super.key,
    required this.metrics,
    required this.entry,
    required this.popGate,
    required this.contentBuilder,
  });

  /// Branch layout state.
  final PaneMetrics metrics;

  /// Page entry state.
  final PaneEntryRef entry;

  /// Page builder.
  final WidgetBuilder contentBuilder;

  /// Optional back gesture gate.
  final ValueListenable<bool>? popGate;

  @override
  Widget build(BuildContext context) {
    final Widget content = popGate == null
        ? Builder(builder: contentBuilder)
        : PanePopGate(gate: popGate!, builder: contentBuilder);
    // The scope's value must follow the entry's pane, so it is rebuilt inside
    // a listener on that pane rather than built once with a stale value.
    return ListenableBuilder(
      listenable: entry.pane,
      builder: (BuildContext context, Widget? _) => FoldablePaneScope(
        pane: entry.pane.value,
        owner: entry,
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
              onPointerDown: (_) => metrics.pointerPane = entry.pane.value,
              onPointerUp: (_) => _clearPointer(metrics),
              onPointerCancel: (_) => _clearPointer(metrics),
              child: TickerMode(
                enabled: !hidden,
                child: ExcludeFocus(
                  excluding: hidden,
                  child: HeroMode(enabled: !twoPane, child: content!),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void _clearPointer(PaneMetrics metrics) {
    scheduleMicrotask(() => metrics.pointerPane = null);
  }
}

/// A [PopScope] driven by a router back gate.
class PanePopGate extends StatefulWidget {
  /// Creates a gate.
  const PanePopGate({super.key, required this.gate, required this.builder});

  /// Whether a user pop is allowed.
  final ValueListenable<bool> gate;

  /// Content builder.
  final WidgetBuilder builder;

  @override
  State<PanePopGate> createState() => _PanePopGateState();
}

class _PanePopGateState extends State<PanePopGate> {
  @override
  void initState() {
    super.initState();
    widget.gate.addListener(_changed);
  }

  @override
  void didUpdateWidget(PanePopGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) {
      oldWidget.gate.removeListener(_changed);
      widget.gate.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.gate.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.gate.value,
    child: Builder(builder: widget.builder),
  );
}

/// Positions a page transition in the rectangle assigned by the host scope.
class PaneSlot extends StatelessWidget {
  /// Creates a pane slot.
  const PaneSlot({
    super.key,
    required this.metrics,
    required this.entry,
    required this.child,
    this.clip = false,
  });

  /// Branch state.
  final PaneMetrics metrics;

  /// Page entry.
  final PaneEntryRef entry;

  /// Transition child.
  final Widget child;

  /// Whether to clip to the pane rectangle.
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final rects = FoldablePaneRectsScope.maybeOf(context)?.rects;
    return _RawPaneSlot(
      metrics: metrics,
      entry: entry,
      clip: clip,
      rects: rects,
      child: child,
    );
  }
}

class _RawPaneSlot extends SingleChildRenderObjectWidget {
  const _RawPaneSlot({
    required this.metrics,
    required this.entry,
    required this.clip,
    required this.rects,
    required super.child,
  });

  final PaneMetrics metrics;
  final PaneEntryRef entry;
  final bool clip;
  final FoldablePaneRects? rects;

  @override
  _RenderPaneSlot createRenderObject(BuildContext context) =>
      _RenderPaneSlot(metrics, entry, clip, rects);

  @override
  _PaneSlotElement createElement() => _PaneSlotElement(this);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneSlot renderObject) {
    renderObject
      ..clip = clip
      ..rects = rects
      ..markNeedsLayout();
  }
}

class _PaneSlotElement extends SingleChildRenderObjectElement {
  _PaneSlotElement(_RawPaneSlot super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final render = renderObject as _RenderPaneSlot;
    if (render.isVisible) super.debugVisitOnstageChildren(visitor);
  }
}

class _RenderPaneSlot extends RenderShiftedBox {
  _RenderPaneSlot(this.metrics, this.entry, this._clip, this.rects)
    : super(null);

  final PaneMetrics metrics;
  final PaneEntryRef entry;
  bool _clip;
  FoldablePaneRects? rects;
  bool _visible = false;

  bool get isVisible => _visible;
  bool get _twoPane => rects?.isSplit == true;

  Rect? _rectFor(FoldablePane pane) => switch (pane) {
    FoldablePane.primary => rects?.primary,
    FoldablePane.secondary => rects?.secondary,
    FoldablePane.single => null,
  };

  bool get clip => _clip;

  set clip(bool value) {
    if (value == _clip) return;
    _clip = value;
    markNeedsPaint();
  }

  FoldablePane? _resolvePane() {
    if (entry.paneFrozen) {
      return entry.frozenHidden ? null : entry.frozenPane;
    }
    if (!_twoPane) return FoldablePane.single;
    final position = entry.position.value;
    if (position == 0) {
      return metrics.stackLength >= 2
          ? FoldablePane.secondary
          : FoldablePane.primary;
    }
    if (position == 1) return FoldablePane.primary;
    return null;
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void performLayout() {
    final renderChild = child;
    if (renderChild == null) {
      _visible = false;
      return;
    }
    final parentData = renderChild.parentData! as BoxParentData;
    final pane = _resolvePane();
    _visible = pane != null;
    if (pane == null) {
      renderChild.layout(constraints);
      parentData.offset = Offset.zero;
      return;
    }
    final rect = pane == FoldablePane.single ? null : _rectFor(pane);
    if (rect == null || !rect.size.isFinite || rect.isEmpty) {
      renderChild.layout(constraints);
      parentData.offset = Offset.zero;
      return;
    }
    renderChild.layout(BoxConstraints.tight(rect.size));
    parentData.offset = rect.topLeft;
  }

  Offset _childOrigin() {
    final renderChild = child;
    if (renderChild == null) return Offset.zero;
    return (renderChild.parentData! as BoxParentData).offset;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!_visible || child == null) return false;
    return result.addWithPaintOffset(
      offset: _childOrigin(),
      position: position,
      hitTest: (result, transformed) =>
          child!.hitTest(result, position: transformed),
    );
  }

  @override
  bool paintsChild(RenderBox child) => _visible;

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(
      Matrix4.translationValues(_childOrigin().dx, _childOrigin().dy, 0),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_visible || child == null) return;
    final origin = _childOrigin();
    if (_clip) {
      context.pushClipRect(
        needsCompositing,
        offset,
        origin & child!.size,
        (context, offset) => context.paintChild(child!, origin + offset),
      );
    } else {
      context.paintChild(child!, origin + offset);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_visible) super.visitChildrenForSemantics(visitor);
  }
}
