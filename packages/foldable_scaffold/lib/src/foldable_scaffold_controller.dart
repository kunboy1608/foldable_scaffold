import 'package:meta/meta.dart' show internal;
import 'package:material_ui/material_ui.dart';

/// Talks to the divider of a [FoldableScaffold] from outside of it.
///
/// Pass one to `FoldableScaffold.controller` to read where the divider is,
/// move it, or put it back where it started; `FoldableScaffold.of(context)`
/// finds the controller of the closest scaffold, including the one the
/// scaffold made for itself:
///
/// ```dart
/// class _MailScreenState extends State<MailScreen> {
///   final _controller = FoldableScaffoldController();
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         Expanded(
///           child: FoldableScaffold(
///             controller: _controller,
///             body: const MessageList(),
///             secondaryBody: const Message(),
///           ),
///         ),
///         ListenableBuilder(
///           listenable: _controller,
///           builder: (context, _) => TextButton(
///             onPressed: _controller.resetDivider,
///             child: Text('${_controller.secondaryWidth ?? 0} wide'),
///           ),
///         ),
///       ],
///     );
///   }
/// }
/// ```
///
/// Like a [ScrollController] or a [TabController], a controller given to the
/// scaffold belongs to the widget that created it, which disposes it; the
/// scaffold only disposes the controller it made when none was passed.
///
/// The controller does not open or close the secondary body: whether there is
/// a second pane is decided by `secondaryBody`/`secondaryBodyBuilder` and
/// `hasSecondaryBody`, and by the width of the scaffold, not by the divider.
/// It only moves the divider of the panes that are already on screen.
class FoldableScaffoldController extends ChangeNotifier {
  double? _secondaryWidth;
  bool _isSplit = false;
  bool _isDraggingDivider = false;
  Axis? _axis;
  FoldableScaffoldControllerDelegate? _delegate;

  /// The width the secondary pane has right now, in logical pixels, or null
  /// before the first layout and whenever the scaffold is not showing two
  /// panes.
  ///
  /// The width is the one the layout is heading for; it does not change on
  /// every frame of the pane animation. When the panes are stacked around a
  /// horizontal hinge ([isStacked]) it is the width of the pane area: the
  /// secondary pane is as wide as the area, and its height is what the hinge
  /// decides.
  double? get secondaryWidth => _secondaryWidth;

  /// Whether the scaffold is showing the body and the secondary body together:
  /// side by side, or stacked around a horizontal hinge ([isStacked]).
  bool get isSplit => _isSplit;

  /// The axis the two panes are laid out along: [Axis.horizontal] side by side,
  /// [Axis.vertical] stacked (the body above the secondary body, around a
  /// horizontal hinge or half-open fold). Null while the scaffold is not
  /// showing two panes.
  Axis? get axis => _axis;

  /// Whether the two panes are stacked, the body above the secondary body. The
  /// divider is then the hinge: [setSecondaryWidth] does nothing, as around a
  /// vertical hinge.
  bool get isStacked => _axis == Axis.vertical;

  /// Whether the user is dragging the divider.
  bool get isDraggingDivider => _isDraggingDivider;

  /// Moves the divider so that the secondary pane is [width] logical pixels
  /// wide, as if the user had dragged it there.
  ///
  /// The width is clamped to what the layout allows: no pane gets narrower
  /// than `FoldableScaffold.minBodySize`. With [snap], the width then snaps to
  /// one of `FoldableScaffold.snapWidths` when it is close enough to one, as
  /// it does when the divider is released. The divider now counts as placed
  /// by the user, so a fold no longer moves it back to the crease.
  ///
  /// Does nothing while the scaffold is not showing two panes, or while they are
  /// around a hinge (vertical or horizontal): those are not sized by the
  /// divider.
  void setSecondaryWidth(double width, {bool snap = false}) {
    _delegate?.setSecondaryWidth(width, snap: snap);
  }

  /// Puts the divider back where it starts: in the middle, or on the crease of
  /// a flat fold when the device has one.
  void resetDivider() => _delegate?.resetDivider();

  /// Called by the scaffold when it is built; the delegate is the scaffold
  /// state, which does the layout work.
  @internal
  void attach(FoldableScaffoldControllerDelegate delegate) {
    _delegate = delegate;
  }

  /// Called by the scaffold when it goes away, or when it is given another
  /// controller.
  @internal
  void detach(FoldableScaffoldControllerDelegate delegate) {
    if (identical(_delegate, delegate)) _delegate = null;
  }

  /// Called by the scaffold after a layout, to publish what changed. Listeners
  /// hear about it only when something really changed.
  @internal
  void update({
    required double? secondaryWidth,
    required bool isSplit,
    required bool isDragging,
    Axis? axis,
  }) {
    final newAxis = isSplit ? (axis ?? Axis.horizontal) : null;
    final changed =
        _secondaryWidth != secondaryWidth ||
        _isSplit != isSplit ||
        _isDraggingDivider != isDragging ||
        _axis != newAxis;
    _secondaryWidth = secondaryWidth;
    _isSplit = isSplit;
    _isDraggingDivider = isDragging;
    _axis = newAxis;
    if (changed) notifyListeners();
  }
}

/// What a [FoldableScaffoldController] asks of the scaffold it is attached to.
///
/// Implemented by the scaffold; not meant to be implemented by an app.
abstract class FoldableScaffoldControllerDelegate {
  /// See [FoldableScaffoldController.setSecondaryWidth].
  void setSecondaryWidth(double width, {required bool snap});

  /// See [FoldableScaffoldController.resetDivider].
  void resetDivider();
}

/// Makes the controller of a [FoldableScaffold] available to its panes, the
/// way `Scaffold` exposes its state.
///
/// Used by `FoldableScaffold.maybeOf` and `FoldableScaffold.of`; not meant to
/// be built by an app.
class FoldableScaffoldControllerScope extends InheritedWidget {
  /// Publishes [controller] to the widgets below.
  const FoldableScaffoldControllerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The controller of the closest scaffold.
  final FoldableScaffoldController controller;

  /// The controller of the closest scaffold, or null when there is none.
  static FoldableScaffoldController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FoldableScaffoldControllerScope>()
      ?.controller;

  @override
  bool updateShouldNotify(FoldableScaffoldControllerScope oldWidget) =>
      oldWidget.controller != controller;
}
