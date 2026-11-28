import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Lays its [child] out where it is in the tree, and paints and hit tests it
/// from the closest [Overlay] while [overPanes] is true: right above the
/// [OverlayEntry] that holds this widget (usually the route of the scaffold),
/// and below the entries that come after it (dialogs, routes pushed later).
///
/// This is how a [FoldableScaffold] with `extendBody` draws its navigation
/// over the panes when something fills the panes from above the scaffold, as
/// `foldable_router` does: its pages are painted after the layout that holds
/// the scaffold, so a navigation painted in place would be under them.
///
/// Only the painting and the hit testing move. The child is built, laid out
/// and given its semantics in place: its slot takes the same room as before
/// (a bottom bar still gives its height to the [Scaffold]), it depends on the
/// inherited widgets of its own context (theme, media query, directionality)
/// and its animations run as usual. The [OverlayPortal] only puts a painter
/// in the overlay, which draws the child with the paint transform the child
/// has there, measured when it paints, so the child is drawn exactly where it
/// is laid out, even while the slot or the route is animating.
///
/// The plain [OverlayPortal] is used rather than
/// [OverlayPortal.overlayChildLayoutBuilder]: the latter marks its overlay
/// child for layout on every frame, and a [GlobalKey] that moves the subtree
/// during the layout of a [LayoutBuilder] (the [Scaffold] does that with its
/// body when `extendBody` changes) then fails an assertion when the overlay
/// child is attached again.
///
/// Without an [Overlay] above it, or while the tickers are muted around it (an
/// [Offstage], an [IndexedStack] or a [Visibility] that hides it keeps its
/// state that way), the child is painted in place, as any other widget.
///
/// Not part of the public API.
class NavigationOverPanes extends StatefulWidget {
  /// Creates the wrapper of a navigation slot.
  const NavigationOverPanes({
    super.key,
    required this.overPanes,
    required this.child,
  });

  /// Whether the child is painted from the overlay, over the panes.
  final bool overPanes;

  /// The navigation, laid out in place.
  final Widget child;

  @override
  State<NavigationOverPanes> createState() => _NavigationOverPanesState();
}

class _NavigationOverPanesState extends State<NavigationOverPanes> {
  final _controller = OverlayPortalController(
    debugLabel: 'FoldableScaffold navigation',
  );
  final _link = _NavigationPaintLink();

  @override
  void initState() {
    super.initState();
    // Before the portal attaches, so this is not a show() during a build: the
    // portal picks it up when it is created. It is never hidden: whether
    // anything is painted from the overlay is the painter's business.
    _controller.show();
  }

  @override
  Widget build(BuildContext context) {
    final hasOverlay = Overlay.maybeOf(context) != null;
    final overPanes =
        widget.overPanes && hasOverlay && TickerMode.valuesOf(context).enabled;
    final host = _NavigationHost(
      link: _link,
      overPanes: overPanes,
      // Its own layer, which the painter appends to the overlay.
      child: RepaintBoundary(child: widget.child),
    );
    if (!hasOverlay) return host;
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) =>
          _NavigationPainter(link: _link, overPanes: overPanes),
      child: host,
    );
  }
}

/// What the host and the painter of one navigation know of each other.
class _NavigationPaintLink {
  _RenderNavigationHost? host;
  _RenderNavigationPainter? painter;

  /// The render object of the navigation, when it can be painted.
  RenderBox? get child {
    final child = host?.child;
    if (child == null || !child.attached || !child.hasSize) return null;
    return child;
  }
}

/// Lays the navigation out in place, and paints it in place only when it is
/// not painted from the overlay.
class _NavigationHost extends SingleChildRenderObjectWidget {
  const _NavigationHost({
    required this.link,
    required this.overPanes,
    required super.child,
  });

  final _NavigationPaintLink link;
  final bool overPanes;

  @override
  _RenderNavigationHost createRenderObject(BuildContext context) =>
      _RenderNavigationHost(link, overPanes);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNavigationHost renderObject,
  ) {
    renderObject.overPanes = overPanes;
  }
}

class _RenderNavigationHost extends RenderProxyBox {
  _RenderNavigationHost(this._link, this._overPanes);

  final _NavigationPaintLink _link;

  bool get overPanes => _overPanes;
  bool _overPanes;
  set overPanes(bool value) {
    if (value == _overPanes) return;
    _overPanes = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.host = this;
  }

  @override
  void detach() {
    if (identical(_link.host, this)) _link.host = null;
    super.detach();
  }

  // The painter paints the child: tell it when the child changes or moves.
  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    _link.painter?.markNeedsPaint();
  }

  @override
  void performLayout() {
    super.performLayout();
    _link.painter?.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_overPanes) return;
    super.paint(context, offset);
  }

  // From the overlay the painter is hit first, above the panes; a hit that
  // gets here missed the navigation.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_overPanes) return false;
    return super.hitTest(result, position: position);
  }
}

/// Fills the overlay and paints the navigation of [link] in it, with the paint
/// transform the navigation has in the overlay.
class _NavigationPainter extends LeafRenderObjectWidget {
  const _NavigationPainter({required this.link, required this.overPanes});

  final _NavigationPaintLink link;
  final bool overPanes;

  @override
  _RenderNavigationPainter createRenderObject(BuildContext context) =>
      _RenderNavigationPainter(link, overPanes);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderNavigationPainter renderObject,
  ) {
    renderObject.overPanes = overPanes;
  }
}

class _RenderNavigationPainter extends RenderBox {
  _RenderNavigationPainter(this._link, this._overPanes);

  final _NavigationPaintLink _link;

  bool _overPanes;
  set overPanes(bool value) {
    if (value == _overPanes) return;
    _overPanes = value;
    markNeedsPaint();
  }

  /// The frame callback that paints again on the next frame, if any.
  int? _repaintCallbackId;

  final LayerHandle<TransformLayer> _transformLayer =
      LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _link.painter = this;
  }

  @override
  void detach() {
    if (identical(_link.painter, this)) _link.painter = null;
    final id = _repaintCallbackId;
    if (id != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
      _repaintCallbackId = null;
    }
    super.detach();
  }

  /// Paints again on the next frame, whatever makes it: the navigation may be
  /// moved by an ancestor (a route that slides, the scaffold that resizes)
  /// without laying itself out or painting. Asks for no frame of its own.
  void _repaintOnNextFrame() {
    _repaintCallbackId ??= SchedulerBinding.instance.scheduleFrameCallback((_) {
      _repaintCallbackId = null;
      if (attached) markNeedsPaint();
    }, scheduleNewFrame: false);
  }

  /// The paint transform of [child] here, or null when it cannot be computed.
  Matrix4? _transformOf(RenderBox child) {
    final transform = child.getTransformTo(this);
    return transform.determinant() == 0 ? null : transform;
  }

  @override
  void dispose() {
    _transformLayer.layer = null;
    super.dispose();
  }

  // The child is appended as a layer (it is a repaint boundary), which needs a
  // layer of this object to go in.
  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = _overPanes ? _link.child : null;
    final transform = child == null ? null : _transformOf(child);
    if (child == null || transform == null) {
      _transformLayer.layer = null;
      return;
    }
    _repaintOnNextFrame();
    _transformLayer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _transformLayer.layer,
    );
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final child = _overPanes ? _link.child : null;
    final transform = child == null ? null : _transformOf(child);
    if (child == null || transform == null) return false;
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }
}
