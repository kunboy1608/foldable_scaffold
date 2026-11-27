import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:foldable_core/foldable_core.dart';

import 'foldable_route.dart';

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
    required this.metrics,
    required this.shell,
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

  /// The mutable layout state of the tab.
  final PaneMetrics metrics;

  /// Trạng thái shell chứa panes này, có sẵn `currentIndex`/`goBranch` để
  /// layout được trả về từ `buildPanes` (ví dụ `FoldableScaffold`) có thể
  /// dựng navigation theo chi nhánh hiện tại.
  final FoldableShellState shell;

  /// The frame of the left pane. Must be placed by the app.
  ///
  /// See the class documentation for what a frame is (and is not).
  late final Widget primary = PaneFrame(
    metrics: metrics,
    pane: FoldablePane.primary,
  );

  /// The frame of the right pane, required when [hasSecondary] is `true`.
  late final Widget secondary = PaneFrame(
    metrics: metrics,
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

  /// Trang sẽ luôn được đặt vào hình chữ nhật của frame, bất kể stack có
  /// bao nhiêu trang: true khi `buildPanes` trả về một layout (ví dụ
  /// `FoldableScaffold`), false khi `buildPanes` trả về `null` (stack cổ
  /// điển, trang lấp đầy vùng tab).
  bool frameMode = false;

  /// Thông tin bố cục pane do layout bên trong tab gửi về
  /// (`FoldableScaffold` khi dùng), hoặc `PaneSignals.none` khi tab không
  /// có layout bên trong. Router đọc thông tin này để đồng bộ `twoPane`
  /// (hai pane chỉ khi cả hai đều hiển thị), trọng số trang và để trang
  /// đọc được MediaQuery của pane.
  final ValueNotifier<PaneSignals> signals = ValueNotifier<PaneSignals>(
    PaneSignals.none,
  );

  /// Thông tin pane đang chờ áp dụng sau khung hiện tại (xem
  /// [publishScaffold]).
  PaneSignals? _pendingSignals;
  bool _signalsPending = false;
  bool _disposed = false;

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

  /// The frame of each pane currently in the tree, to measure what of it is
  /// visible.
  final Map<FoldablePane, _RenderPaneFrame> _frames =
      <FoldablePane, _RenderPaneFrame>{};

  /// What of each frame the slots last painted, to repaint them when it
  /// changes on its own (see [_RenderPaneFrame._checkFrames]).
  final Map<FoldablePane, Rect?> _paintedVisible = <FoldablePane, Rect?>{};

  /// The part of the frame of [pane] that is visible, in the coordinates of
  /// the tab area: its rectangle cut by the clips of the layout above it (a
  /// `FoldableScaffold` clips its panes). Null when there is no frame to
  /// measure. Only valid outside layout (the slots read it when they paint).
  Rect? visibleRectFor(FoldablePane pane) {
    final _RenderPaneFrame? frame = _frames[pane];
    if (frame == null || !frame.attached) return null;
    return frame._visibleRect();
  }

  void _markSlotsNeedingPaint() {
    for (final _RenderPaneSlot slot in _slots.toList()) {
      if (slot.attached) slot.markNeedsPaint();
    }
  }

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
    _scheduleSlotsRelayout();
  }

  /// Whether a post-frame relayout of the slots is already scheduled.
  bool _slotsPending = false;

  /// Đánh thức các slot trên hình chữ nhật mới sau khung hiện tại.
  ///
  /// Không đánh thức ngay: [publish] có thể chạy giữa lượt layout của một
  /// nút render khác (frame tự layout khi vùng tab không chạy), và gọi
  /// `markNeedsLayout` trên một slot nằm ngoài cây đang layout là lỗi.
  void _scheduleSlotsRelayout() {
    if (_slotsPending || _disposed) return;
    _slotsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slotsPending = false;
      if (!_disposed) _markSlotsNeedingLayout();
    });
  }

  /// Releases the observables of these metrics.
  void dispose() {
    twoPane.dispose();
    signals.dispose();
    _area = null;
    _disposed = true;
  }

  /// Ghi nhận thông tin pane từ một frame vừa build.
  ///
  /// Không làm gì khi thông tin không đổi. Thông tin được áp dụng (và các
  /// trang được xếp lại) sau khung hiện tại, tránh đánh thức widget giữa lúc
  /// build/layout đang chạy.
  void publishScaffold(PaneSignals value) {
    final PaneSignals old = signals.value;
    if (identical(old, value)) return;
    final bool changed =
        old.hasScaffold != value.hasScaffold ||
        old.primaryVisible != value.primaryVisible ||
        old.secondaryVisible != value.secondaryVisible ||
        old.axis != value.axis ||
        old.canSplit != value.canSplit ||
        old.primaryMedia != value.primaryMedia ||
        old.secondaryMedia != value.secondaryMedia;
    if (!changed) return;
    if (_disposed) return;
    _pendingSignals = value;
    if (_signalsPending) return;
    _signalsPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _signalsPending = false;
      if (_disposed) return;
      signals.value = _pendingSignals!;
      // Một pane đổi trạng thái hiển thị: xếp lại trang trên hình chữ nhật
      // mới ngay trong khung sau.
      _markSlotsNeedingLayout();
    });
  }

  /// Xóa thông tin pane khi tab không còn layout bên trong (`null` từ
  /// `buildPanes`).
  void resetScaffoldSignals() => publishScaffold(PaneSignals.none);
}

/// The frame a page of a one-pane tab is drawn in when the tab has a layout
/// ([PaneMetrics.frameMode]): the top page of a stack of two or more pages in
/// the secondary frame, every other page in the primary one.
FoldablePane singleFrameFor(int position, PaneMetrics metrics) =>
    position == 0 && metrics.stackLength >= 2
    ? FoldablePane.secondary
    : FoldablePane.primary;

/// Thông tin bố cục pane do layout bên trong tab gửi về, và qua đó router
/// biết khi nào một hoặc hai pane đang thực sự hiển thị.
///
/// Được tạo bởi các frame ([PaneFrame]) từ `FoldablePaneLayout` và
/// `FoldableScaffoldScope` (trong `foldable_core`) mà `FoldableScaffold`
/// cung cấp quanh các pane của nó. Khi tab không dùng một layout có khai báo
/// (một `Row` tự viết, hay `null`), [none] được dùng và router chạy theo quy
/// tắc cổ điển (hai pane khi `buildPanes` trả về layout).
@immutable
class PaneSignals {
  const PaneSignals._({
    required this.hasScaffold,
    required this.primaryVisible,
    required this.secondaryVisible,
    required this.axis,
    required this.canSplit,
    this.primaryMedia,
    this.secondaryMedia,
  });

  /// Layout bên trong không khai báo pane (không có `FoldableScaffold`).
  static const PaneSignals none = PaneSignals._(
    hasScaffold: false,
    primaryVisible: true,
    secondaryVisible: false,
    axis: Axis.horizontal,
    canSplit: false,
  );

  /// Tạo thông tin từ một layout có khai báo pane.
  factory PaneSignals.fromScaffold({
    required bool primaryVisible,
    required bool secondaryVisible,
    required Axis axis,
    required bool canSplit,
    required MediaQueryData? primaryMedia,
    required MediaQueryData? secondaryMedia,
  }) {
    return PaneSignals._(
      hasScaffold: true,
      primaryVisible: primaryVisible,
      secondaryVisible: secondaryVisible,
      axis: axis,
      canSplit: canSplit,
      primaryMedia: primaryMedia,
      secondaryMedia: secondaryMedia,
    );
  }

  /// Whether the layout declared its panes (`FoldableScaffold` above the
  /// frames).
  final bool hasScaffold;

  /// Whether the body pane is shown.
  final bool primaryVisible;

  /// Whether the secondary body pane is shown.
  final bool secondaryVisible;

  /// The axis the panes are laid out along.
  final Axis axis;

  /// Whether the layout may split into two panes.
  final bool canSplit;

  /// The MediaQuery the layout gives the body pane, if any.
  final MediaQueryData? primaryMedia;

  /// The MediaQuery the layout gives the secondary body pane, if any.
  final MediaQueryData? secondaryMedia;
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
// ignore: must_be_immutable
class BranchArea extends StatefulWidget {
  /// Creates the tab area.
  BranchArea({
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

  /// Trạng thái shell chứa tab này, có sẵn cho layout qua
  /// `FoldablePanes.shell`. Do [BranchArea] là con trực tiếp của
  /// [FoldableShellState.child], không thể tham chiếu state trong initializer
  /// list, nên gán sau khi state được tạo.
  // ignore: must_be_immutable
  FoldableShellState? shell;

  /// The navigators of the branches (the pages are drawn above the panes).
  final Widget child;

  /// Called during the build with the panes of the tab and whether the shell
  /// returned a layout (`true` means pages will be slotted into frames,
  /// `false` means the classic full-screen stack).
  final void Function(FoldablePanes panes, bool hasLayout) onBuilt;

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
          shell: widget.shell!,
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
    // Thông tin do layout bên trong tab khai báo (FoldableScaffold), nếu có:
    // pane nào đang hiển thị, axis, và MediaQuery mà layout dành cho pane.
    final FoldablePaneLayout? layout = FoldablePaneLayout.maybeOf(context);
    final FoldableScaffoldScope? scope = FoldableScaffoldScope.maybeOf(context);
    final MediaQueryData? media = MediaQuery.maybeOf(context);
    final PaneSignals signals = layout == null
        ? PaneSignals.none
        : PaneSignals.fromScaffold(
            primaryVisible: layout.primaryVisible,
            secondaryVisible: layout.secondaryVisible,
            axis: layout.axis,
            canSplit: scope?.canSplit ?? false,
            primaryMedia: pane == FoldablePane.primary ? media : null,
            secondaryMedia: pane == FoldablePane.secondary ? media : null,
          );
    return _RawPaneFrame(metrics: metrics, pane: pane, signals: signals);
  }
}

class _RawPaneFrame extends LeafRenderObjectWidget {
  const _RawPaneFrame({
    required this.metrics,
    required this.pane,
    required this.signals,
  });

  final PaneMetrics metrics;
  final FoldablePane pane;
  final PaneSignals signals;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneFrame(metrics, pane, signals);

  @override
  void updateRenderObject(BuildContext context, _RenderPaneFrame renderObject) {
    renderObject.updateMetrics(metrics, pane);
    // Công bố thông tin pane (visible, axis, media) cho router ngay khi
    // widget build, trước khi layout chạy, để trang biết ngay pane của mình.
    renderObject.metrics.publishScaffold(signals);
    // The area was rebuilt: measure again, even if the widget is unchanged.
    renderObject.markNeedsLayout();
  }
}

class _RenderPaneFrame extends RenderBox {
  _RenderPaneFrame(this.metrics, this.pane, this.signals);

  PaneMetrics metrics;
  FoldablePane pane;
  PaneSignals signals;

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
    if (attached) {
      _forgetFrame();
      metrics = value;
      pane = paneValue;
      metrics._frames[pane] = this;
    } else {
      metrics = value;
      pane = paneValue;
    }
    value.reportedMissing = false;
  }

  void _forgetFrame() {
    if (identical(metrics._frames[pane], this)) metrics._frames.remove(pane);
  }

  /// The visible part of this frame in the coordinates of the area: its box
  /// cut by every clip between it and the area. Read outside layout only (the
  /// clips are described from the sizes of the ancestors).
  Rect? _visibleRect() {
    final _RawPaneArea? area = metrics._area;
    if (area == null || !area.attached || !hasSize) return null;
    Rect visible = Offset.zero & size;
    RenderObject child = this;
    while (!identical(child, area)) {
      final RenderObject? parent = child.parent;
      if (parent == null) return null; // Not under the area (detaching).
      final Rect? clip = parent.describeApproximatePaintClip(child);
      if (clip != null) visible = visible.intersect(clip);
      final ParentData? parentData = child.parentData;
      if (parentData is BoxParentData) {
        visible = visible.shift(parentData.offset);
      }
      child = parent;
    }
    if (visible.width <= 0 || visible.height <= 0) {
      return Rect.fromLTWH(visible.left, visible.top, 0, 0);
    }
    return visible;
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
    _publishOwnRect();
  }

  /// Publishes the rectangle of this frame, measured from the layout offsets
  /// up to the area, unless the area is laying out (it publishes it then).
  void _publishOwnRect() {
    final _RawPaneArea? area = metrics._area;
    if (area == null || !area.attached || area.isLayingOut || !hasSize) return;
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
    _watch(this);
    metrics._frames[pane] = this;
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
    _attachedFrames.remove(this);
    _forgetFrame();
    super.detach();
  }

  /// The frames in the tree, checked after every frame by [_checkFrames].
  static final Set<_RenderPaneFrame> _attachedFrames = <_RenderPaneFrame>{};
  static bool _checkInstalled = false;

  static void _watch(_RenderPaneFrame frame) {
    _attachedFrames.add(frame);
    if (_checkInstalled) return;
    _checkInstalled = true;
    WidgetsBinding.instance.addPersistentFrameCallback(_checkFrames);
  }

  /// Runs after the layout and paint of every frame.
  ///
  /// A frame publishes its rectangle when it lays out, or when its area does.
  /// An ancestor may still move it without laying either of them out: a
  /// layout that animates the position of a pane whose size stays the same
  /// (the panes of a `FoldableScaffold` sliding while its navigation moves
  /// from the side to the bottom) only changes an offset. Measuring the frames
  /// again here catches that move; the pages follow on the next frame instead
  /// of staying where the frame was.
  static void _checkFrames(Duration timeStamp) {
    for (final _RenderPaneFrame frame in _attachedFrames.toList()) {
      if (!frame.attached) continue;
      frame._publishOwnRect();
      // The clip of a frame can change without the frame moving (a pane
      // that slides under the edge of the layout): repaint the pages then.
      final PaneMetrics metrics = frame.metrics;
      if (!metrics._paintedVisible.containsKey(frame.pane)) continue;
      if (metrics._paintedVisible[frame.pane] != frame._visibleRect()) {
        metrics._markSlotsNeedingPaint();
      }
    }
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
          metrics.signals,
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
                  child: _wrapPaneEnvironment(context, content!),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Bọc nội dung trang bằng môi trường của pane mà trang đang nằm trong:
  /// MediaQuery mà layout (ví dụ `FoldableScaffold`) dành cho pane, và các
  /// scope `FoldablePaneLayout`/`FoldableScaffoldScope` để chính trang đọc
  /// được pane nào đang hiện, axis và `canSplit`.
  Widget _wrapPaneEnvironment(BuildContext context, Widget child) {
    final PaneSignals signals = metrics.signals.value;
    if (!signals.hasScaffold) return child;
    final MediaQueryData? media = switch (entry.pane.value) {
      FoldablePane.primary => signals.primaryMedia,
      FoldablePane.secondary => signals.secondaryMedia,
      FoldablePane.single =>
        singleFrameFor(entry.position.value, metrics) == FoldablePane.secondary
            ? signals.secondaryMedia ?? signals.primaryMedia
            : signals.primaryMedia ?? signals.secondaryMedia,
    };
    Widget page = child;
    if (media != null) page = MediaQuery(data: media, child: page);
    page = FoldablePaneLayout(
      primaryVisible: signals.primaryVisible,
      secondaryVisible: signals.secondaryVisible,
      axis: signals.axis,
      child: page,
    );
    return FoldableScaffoldScope(canSplit: signals.canSplit, child: page);
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
    final Rect? rect = _rectFor(pane);
    _framePane = rect == null ? null : _framePaneFor(pane);
    if (rect != null && rect.size.isFinite && rect.isEmpty) {
      // The frame is placed but collapsed: the layout hides that pane (a
      // FoldableScaffold showing only the secondary body in one pane). The
      // page is hidden like a page deeper in the stack, not spread over the
      // whole area, where it would cover the chrome (navigation, app bar)
      // and take its taps.
      _visible = false;
      child.layout(constraints, parentUsesSize: false);
      parentData.offset = Offset.zero;
      return;
    }
    if (rect == null || !rect.size.isFinite) {
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

  /// The rectangle [pane] is drawn in, or null for the whole area.
  ///
  /// A one-pane tab without a layout fills the whole area, like the pages of
  /// the root navigator. A one-pane tab drawn by a layout (`buildPanes`
  /// returned one, say a `FoldableScaffold` showing a single pane) still puts
  /// its pages in the frames, or they would cover the chrome of the layout:
  /// the top page of a stack of two or more sits in the secondary frame, the
  /// others in the primary one. A frame the layout collapsed hides its page.
  /// The frame whose rectangle the page was laid out on, or null when it
  /// fills the whole area. Its visible part clips the page when it paints.
  FoldablePane? _framePane;

  /// What the page was clipped to when it last painted, in the coordinates of
  /// this slot, for hit testing.
  Rect? _paintClip;

  FoldablePane _framePaneFor(FoldablePane pane) => pane != FoldablePane.single
      ? pane
      : singleFrameFor(entry.position.value, metrics);

  Rect? _rectFor(FoldablePane pane) {
    if (pane != FoldablePane.single) return metrics.rectFor(pane);
    if (!metrics.frameMode) return null;
    return metrics.rectFor(singleFrameFor(entry.position.value, metrics));
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
    // Only the part of the page that was painted takes taps.
    final Rect? clip = _paintClip;
    if (_clip && clip != null && !clip.contains(position)) return false;
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
      //
      // The page is also cut to the visible part of its frame: a layout that
      // clips its panes (a FoldableScaffold sliding a pane out under its
      // edge) keeps the page from showing over its chrome.
      Rect clipRect = origin & child.size;
      final FoldablePane? framePane = _framePane;
      if (framePane != null) {
        final Rect? visible = metrics.visibleRectFor(framePane);
        metrics._paintedVisible[framePane] = visible;
        if (visible != null) clipRect = clipRect.intersect(visible);
      }
      if (clipRect.width <= 0 || clipRect.height <= 0) {
        _paintClip = Rect.zero;
        return;
      }
      _paintClip = clipRect;
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
