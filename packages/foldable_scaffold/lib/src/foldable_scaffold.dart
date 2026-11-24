import 'dart:ui' show DisplayFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/rendering.dart'
    show PaintingContext, RenderObject, RenderProxyBox;
import 'package:foldable_core/foldable_core.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_breakpoints.dart';
import 'foldable_fold.dart';
import 'foldable_navigation.dart';
import 'foldable_scaffold_controller.dart';
import 'foldable_scaffold_divider.dart';
import 'foldable_scaffold_layout.dart';
import 'foldable_scaffold_theme.dart';

/// A [Scaffold] with two panes: a body and a secondary body.
///
/// The scaffold only takes care of the layout. Who fills the panes is up to
/// you: `FoldableNavigator` in `foldable_router` puts a page stack in them,
/// but any two widgets work.
///
/// Layout, by available width (the numbers are [breakpoints], shown here for a
/// desktop; see [FoldableBreakpoints] for handhelds):
///
/// * Below 600: one pane at a time, no navigation rail.
/// * From 600: the primary navigation is shown sideways, one pane at a time.
/// * From 1200 on desktop, or from 600 on the inner screen of a foldable or a
///   tablet (a window at least 600 on its short side, so never a phone): the
///   body and the secondary body are shown side by side, with a divider that
///   can be dragged to resize them. The divider stops where either pane would
///   get narrower than [minBodySize].
///
/// When only one pane is shown, the secondary body replaces the body, unless
/// [focusOnPrimaryBody] is true. A pane narrower than [minBodySize] collapses
/// into the other one, which happens when the available width cannot hold two
/// panes of that size.
///
/// ### The hidden pane
///
/// A pane that is not shown is never taken out of the tree: its widgets keep
/// their state (a `FoldableNavigator` page stack, a scroll position, text being
/// typed) and are shown again instantly with nothing lost. It is only laid out
/// at zero width. To make sure nothing of it is seen or reached while it has no
/// width, the hidden pane does not take focus (keyboard or screen reader), is
/// left out of the semantics tree, does not take pointer events, and its
/// tickers (animations) are muted. This applies once the pane has actually
/// collapsed to zero width: a pane that is sliding in or out still has a
/// non-zero width and stays fully live, so the slide of `FoldableNavigator` is
/// never cut short.
///
/// The navigation goes where [navigationPlacement] says: below the panes
/// (the usual bottom bar), above them, or beside them on either side (a rail).
/// By default that is [defaultNavigationPlacement], by platform and width, and
/// a device that wants its bars on a side (iPhone Duo) says so with
/// [FoldableVerticalBarScope]. [navigationBuilder] builds it for any placement;
/// [primaryNavigation] and [bottomNavigationBar] are the shorthand.
///
/// A device with a fold or hinge (see [followFold]) gets the panes placed
/// around it, whatever the width, when the fold separates the screen (a hinge,
/// or a fold that is half open):
///
/// * around a **vertical** fold the body is on one side and the secondary body
///   on the other, left and right (mirrored in right-to-left text);
/// * around a **horizontal** one the panes are **stacked**: the body above the
///   fold and the secondary body below it, whatever the text direction (it only
///   changes the horizontal order). Each half needs [minBodySize] of *height*
///   there, and a secondary body to show. The navigation and the app bar stay
///   where they are, outside the panes: the fold is in window coordinates, and
///   the scaffold measures where the pane area really is to put it inside.
///
/// The area of the fold is the divider, empty and not a handle, in both cases.
/// A flat vertical fold only decides where the divider starts, and a flat
/// horizontal fold is ignored like a cutout: only a separating one stacks the
/// panes.
///
/// The divider can snap to set widths when it is released ([snapWidths]).
///
/// The divider is themed by the closest [FoldableScaffoldThemeData] that the
/// [ThemeData] carries, overridden by [theme], and its handle can be replaced
/// by [dividerBuilder]. It takes the keyboard focus, moves with the arrow keys
/// ([dividerKeyboardStep], four times as far with Shift, Home and End to the
/// edges), and is a slider for screen readers ([dividerSemanticLabel]). Its
/// position and whether the user placed it are restored with [restorationId],
/// under an id of their own so they do not collide with the [Scaffold]'s.
/// [controller] and [FoldableScaffold.maybeOf] read and move it from outside.
///
/// The usual [Scaffold] slots are forwarded: [appBar], [bottomNavigationBar],
/// [floatingActionButton], [floatingActionButtonAnimator],
/// [persistentFooterButtons], [persistentFooterAlignment],
/// [persistentFooterDecoration], [drawer], [onDrawerChanged],
/// [endDrawer], [onEndDrawerChanged], [bottomSheet], [backgroundColor],
/// [resizeToAvoidBottomInset], [primary], [drawerDragStartBehavior],
/// [drawerScrimColor], [drawerEdgeDragWidth], [drawerEnableOpenDragGesture],
/// [endDrawerEnableOpenDragGesture], [restorationId] and
/// [drawerBarrierDismissible]. [extendBody] defaults to `false`, like
/// [Scaffold].
///
/// `bottomSheetScrimBuilder` is not forwarded: `Scaffold`'s default for it is
/// private, so there is nothing to default to. `body` is not forwarded either:
/// it is the first pane of this scaffold.
///
/// Text direction follows [Directionality]: in [TextDirection.rtl] the rail
/// is on the right edge, the secondary body is on the left and the body on
/// the right, and the divider drags in the mirrored direction. The fold or
/// hinge coordinates keep their physical meaning and are mirrored at the
/// scaffold level.
///
/// Each pane slot takes a widget, as [Scaffold] does, or a builder for the
/// widgets that need the pane constraints: [body] or [bodyBuilder],
/// [secondaryBody] or [secondaryBodyBuilder], [appBar] or [appBarBuilder],
/// [primaryNavigation] or [primaryNavigationBuilder], [bottomNavigationBar] or
/// [bottomNavigationBarBuilder]. A slot takes one or the other, not both.
///
/// Switching the one visible pane is instant while [paneTransition] is true,
/// so a page slide (`FoldableNavigator`) does not run a pane resize on top of
/// it. [FoldablePaneTransitionScope] provides the same signal automatically
/// when the scaffold is built inside a `FoldableNavigator`.
class FoldableScaffold extends StatefulWidget {
  const FoldableScaffold({
    super.key,
    this.body,
    this.bodyBuilder,
    this.secondaryBody,
    this.secondaryBodyBuilder,
    this.appBar,
    this.appBarBuilder,
    this.primaryNavigation,
    this.primaryNavigationBuilder,
    this.bottomNavigationBar,
    this.bottomNavigationBarBuilder,
    this.navigationBuilder,
    this.navigationPlacement,
    this.hasSecondaryBody,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.focusOnPrimaryBody = false,
    this.breakpoints,
    this.followFold = true,
    this.minWidthNavigation = 72.0,
    this.maxWidthNavigation = 192.0,
    this.minBodySize = 200.0,
    this.dividerSize = 24.0,
    this.dividerKeyboardStep = 16.0,
    this.dividerSemanticLabel = 'Resize panes',
    this.theme,
    this.dividerBuilder,
    this.controller,
    this.snapWidths = const [],
    this.snapThreshold = 32.0,
    this.paneAnimationDuration = const Duration(milliseconds: 250),
    this.paneTransition,
    this.onSecondBodyClose,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,

    // Slots the underlying [Scaffold] manages itself.
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.persistentFooterAlignment = AlignmentDirectional.centerEnd,
    this.persistentFooterDecoration,
    this.onDrawerChanged,
    this.onEndDrawerChanged,
    this.drawerDragStartBehavior = DragStartBehavior.start,
    this.drawerScrimColor,
    this.drawerEdgeDragWidth,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    this.restorationId,
    this.drawerBarrierDismissible = true,
  }) : assert(
         body != null || bodyBuilder != null,
         'A FoldableScaffold needs a body or a bodyBuilder.',
       ),
       assert(
         body == null || bodyBuilder == null,
         'Pass a body or a bodyBuilder, not both.',
       ),
       assert(
         secondaryBody == null || secondaryBodyBuilder == null,
         'Pass a secondaryBody or a secondaryBodyBuilder, not both.',
       ),
       assert(
         appBar == null || appBarBuilder == null,
         'Pass an appBar or an appBarBuilder, not both.',
       ),
       assert(
         primaryNavigation == null || primaryNavigationBuilder == null,
         'Pass a primaryNavigation or a primaryNavigationBuilder, not both.',
       ),
       assert(
         bottomNavigationBar == null || bottomNavigationBarBuilder == null,
         'Pass a bottomNavigationBar or a bottomNavigationBarBuilder, not '
         'both.',
       ),
       assert(
         navigationBuilder == null ||
             (primaryNavigation == null &&
                 primaryNavigationBuilder == null &&
                 bottomNavigationBar == null &&
                 bottomNavigationBarBuilder == null),
         'Pass a navigationBuilder or the primaryNavigation and '
         'bottomNavigationBar slots, not both.',
       );

  /// The main pane, shown on its own or on the left of the secondary body.
  ///
  /// Either this or [bodyBuilder], not both. The builder variant passes the
  /// pane constraints, which change while the divider is dragged.
  final Widget? body;

  /// Builds [body] with the pane constraints.
  ///
  /// Called with the constraints of the pane, which change while the divider
  /// is dragged. Returning null shows an empty pane.
  final BoxConstraintsNullableWidgetBuilder? bodyBuilder;

  /// The second pane, shown on its own or on the right of [body].
  ///
  /// Either this or [secondaryBodyBuilder], not both. Without one of them
  /// there is no second pane, and the scaffold is a single-pane [Scaffold].
  final Widget? secondaryBody;

  /// Builds [secondaryBody] with the pane constraints.
  ///
  /// Called once per layout, to build the pane. It is never called to find out
  /// whether there is a secondary body: [hasSecondaryBody] decides that.
  /// Returning null leaves the pane empty, which does not change the layout
  /// nor whether the back gesture is blocked.
  final BoxConstraintsNullableWidgetBuilder? secondaryBodyBuilder;

  /// The app bar, forwarded to [Scaffold.appBar].
  ///
  /// Either this or [appBarBuilder], not both.
  final PreferredSizeWidget? appBar;

  /// Builds [appBar] with the scaffold width and [kToolbarHeight].
  final PreferredSizeBoxConstraintsWidgetBuilder? appBarBuilder;

  /// The navigation shown beside the panes, usually a [NavigationRail], when
  /// [navigationPlacement] puts it on a side (the start side from
  /// [FoldableBreakpoints.rail] wide, by default).
  ///
  /// Either this or [primaryNavigationBuilder], not both.
  final Widget? primaryNavigation;

  /// Builds [primaryNavigation] with the navigation constraints and the
  /// scaffold padding.
  final PrimaryNavigationBuilder? primaryNavigationBuilder;

  /// The bottom navigation, shown when [navigationPlacement] puts the
  /// navigation below the panes (below [FoldableBreakpoints.rail] wide, by
  /// default), or above them. The bottom one is given to
  /// [Scaffold.bottomNavigationBar].
  ///
  /// Either this or [bottomNavigationBarBuilder], not both.
  final Widget? bottomNavigationBar;

  /// Builds [bottomNavigationBar] with the bottom bar constraints.
  final BoxConstraintsNullableWidgetBuilder? bottomNavigationBarBuilder;

  /// Builds the navigation for wherever [navigationPlacement] puts it: one
  /// builder for a bar below the panes, a bar above them and a rail beside
  /// them.
  ///
  /// It gets the [FoldableNavigationPlacement], so it can return a
  /// `NavigationBar` for the horizontal edges and a `NavigationRail` for the
  /// sides. Use it instead of [primaryNavigation] and [bottomNavigationBar];
  /// passing both is an error. Those two slots remain for the usual case:
  /// [primaryNavigation] is shown when the placement is a side,
  /// [bottomNavigationBar] when it is the bottom or the top.
  ///
  /// The navigation is a different widget for each edge, so its state does not
  /// move with it from one edge to another: keep what matters (the selected
  /// tab) in your own state, or give the widget a `GlobalKey`.
  final FoldableNavigationBuilder? navigationBuilder;

  /// Decides where the navigation goes: below, above or beside the panes, and
  /// how wide a side navigation is.
  ///
  /// Defaults to [defaultNavigationPlacement], which depends on the platform
  /// (see [FoldableNavigationPlacements]) and on [FoldableVerticalBarScope],
  /// the way iPhone Duo asks for its bars to go on the side. Called on every
  /// layout with the facts of the scaffold ([FoldableLayoutInfo]), so it must be
  /// pure and cheap. Fall back to [defaultNavigationPlacement] for the cases
  /// you do not care about.
  final FoldableNavigationPlacementResolver? navigationPlacement;

  /// Whether the secondary body is shown, when there is one.
  ///
  /// Defaults to true: [secondaryBody] or [secondaryBodyBuilder] is enough to
  /// get the second pane. Set it to false to keep the widget but hide the
  /// pane, for example while what it shows is loading.
  ///
  /// The hidden pane stays in the tree, so its widgets keep their state; while
  /// it has no width it does not take focus, is left out of the semantics tree,
  /// does not take pointer events and does not run tickers.
  final bool? hasSecondaryBody;

  /// Whether this scaffold hosts the primary content of the app, forwarded to
  /// [Scaffold.primary].
  final bool primary;

  /// Forwarded to [Scaffold.extendBody].
  final bool extendBody;

  /// Forwarded to [Scaffold.extendBodyBehindAppBar].
  final bool extendBodyBehindAppBar;

  /// Whether the body stays on screen when the secondary body is opened in a
  /// single-pane layout.
  final bool focusOnPrimaryBody;

  /// The widths at which the layout changes.
  ///
  /// Defaults to [FoldableBreakpoints.forPlatform] for the platform of the
  /// closest [Theme]: two panes on the inner screen of a foldable or on a
  /// tablet for Android and iOS, from a window 1200 wide elsewhere.
  final FoldableBreakpoints? breakpoints;

  /// Whether the panes follow a fold or hinge of the device ([FoldableFold],
  /// from `MediaQuery.displayFeatures`).
  ///
  /// * A **vertical** fold that separates the screen (a hinge, or a fold that is
  ///   half open) gets one pane on each side, and the hinge area between them
  ///   stays empty. The divider cannot be dragged. This applies even where
  ///   [breakpoints] would show one pane, provided each side is at least
  ///   [minBodySize] wide.
  /// * A **horizontal** fold that separates the screen stacks the panes: the
  ///   body above it and the secondary body below it, with the hinge area
  ///   between them empty and not draggable, even where [breakpoints] would
  ///   show one pane. It needs a secondary body to show, and each half at least
  ///   [minBodySize] *tall* ([minBodySize] is the minimum height as well as the
  ///   minimum width); otherwise the usual rules apply.
  /// * A flat vertical fold is only a crease: the divider starts on it, and can
  ///   be dragged away. Two panes still need [breakpoints] to say so. A flat
  ///   horizontal fold is ignored, like a cutout: the width alone decides.
  ///
  /// With several folds, the first one of `displayFeatures` that applies wins
  /// (see [FoldableFold.fromFeatures]).
  ///
  /// The fold is in window coordinates, so a scaffold only follows a fold that
  /// runs across it: a vertical fold needs the scaffold to be as wide as the
  /// window, a horizontal one needs it to be as tall as the window. A scaffold
  /// inside something smaller (under an app bar of its own, in a padding)
  /// ignores the fold of that direction. For a horizontal fold the app bar, the
  /// navigation above or below the panes and the system insets are inside the
  /// scaffold, so the scaffold measures where the pane area is after layout and
  /// puts the fold inside it. The first frame of the app, before there is a
  /// measure, lays the panes out from an estimate and does not paint them; the
  /// measure comes with that frame and nothing is seen at a wrong place. A
  /// change of posture afterwards uses the last measure and shows the right
  /// layout at once. Devices without a fold are unaffected.
  final bool followFold;

  /// Width of the primary navigation when it is shown sideways.
  final double minWidthNavigation;

  /// Width of the primary navigation when the scaffold is wide
  /// ([FoldableBreakpoints.wideRail]).
  final double maxWidthNavigation;

  /// A pane narrower than this collapses into the other one.
  ///
  /// It is also the minimum *height* of each half around a horizontal hinge,
  /// where the panes are stacked.
  final double minBodySize;

  /// Width of the drag handle between the two panes.
  final double dividerSize;

  /// How far the divider moves, in logical pixels, for one arrow key press
  /// while it has the focus.
  ///
  /// Holding Shift makes a step four times longer; Home and End put the
  /// divider at the smallest and the largest the secondary pane can be. The
  /// step is the same one a screen reader uses when it increases or decreases
  /// the divider.
  ///
  /// Defaults to 16.
  final double dividerKeyboardStep;

  /// What a screen reader reads for the divider, which it presents as a
  /// slider: "Resize panes" by default.
  final String dividerSemanticLabel;

  /// The look of the divider, over the [FoldableScaffoldThemeData] that the
  /// [ThemeData] carries.
  ///
  /// A field left null falls back to the inherited [FoldableScaffoldThemeData],
  /// then to the default taken from the [ThemeData], so an empty instance
  /// changes nothing that is seen. Its counterpart, to theme every divider of
  /// the app at once, is a [FoldableScaffoldThemeData] in `ThemeData.extensions`.
  final FoldableScaffoldThemeData? theme;

  /// Builds the handle of the divider, replacing the default one.
  ///
  /// Only the look changes: the scaffold keeps dragging the divider, sets the
  /// resize cursor, runs the keyboard shortcuts, and gives the divider its
  /// focus and its semantics, so a custom handle does not have to do any of
  /// it. Not called around a hinge or a fold that separates the screen, where
  /// there is no handle to draw.
  final FoldableDividerBuilder? dividerBuilder;

  /// The controller of the divider, to read and move it from outside.
  ///
  /// Optional: without one the scaffold makes its own, which
  /// [FoldableScaffold.maybeOf] finds as well. A controller that is passed
  /// belongs to the widget that created it, which disposes it; the scaffold
  /// only disposes the one it made.
  final FoldableScaffoldController? controller;

  /// The controller of the closest [FoldableScaffold] above the context, be it
  /// the one passed to [controller] or the one the scaffold made for itself.
  ///
  /// Returns null when there is no scaffold above the context. See [of] for
  /// the version that insists on finding one.
  static FoldableScaffoldController? maybeOf(BuildContext context) =>
      FoldableScaffoldControllerScope.maybeOf(context);

  /// The controller of the closest [FoldableScaffold] above the context, the
  /// way [Scaffold.of] finds the state of a [Scaffold].
  ///
  /// Throws an assertion with a message saying how to fix it when no
  /// [FoldableScaffold] is above the context, for example because the context
  /// is the one that builds the scaffold instead of one inside it.
  static FoldableScaffoldController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'FoldableScaffold.of() called with a context that does not contain a '
      'FoldableScaffold.\n'
      'No FoldableScaffold ancestor could be found starting from the context '
      'that was passed to FoldableScaffold.of(). This can happen because the '
      'context comes from a widget that builds the FoldableScaffold, instead '
      'of from a widget inside one of its panes.',
    );
    return controller!;
  }

  /// Widths a pane snaps to when the divider is released, for example
  /// `[360, 412]`. Either pane snaps, whichever is nearest to one of the widths.
  ///
  /// Empty by default: the divider stays where it is released.
  final List<double> snapWidths;

  /// How close, in logical pixels, a pane must be to one of the [snapWidths]
  /// when the divider is released to snap to it.
  final double snapThreshold;

  /// Duration of the pane animations, scaled by [FoldableMotion].
  final Duration paneAnimationDuration;

  /// Whether pages are sliding right now.
  ///
  /// While true, switching the one visible pane is instant. Both the body and
  /// the secondary body still build; only the pane geometry stops animating.
  ///
  /// Defaults to the closest [FoldablePaneTransitionScope], which
  /// `FoldableNavigator` provides.
  final ValueListenable<bool>? paneTransition;

  /// Called when the system back press is refused because the secondary body
  /// is open.
  final PopInvokedWithResultCallback<dynamic>? onSecondBodyClose;

  /// Forwarded to [Scaffold.floatingActionButton].
  final Widget? floatingActionButton;

  /// Forwarded to [Scaffold.floatingActionButtonLocation].
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Forwarded to [Scaffold.drawer].
  final Widget? drawer;

  /// Forwarded to [Scaffold.endDrawer].
  final Widget? endDrawer;

  /// Forwarded to [Scaffold.bottomSheet].
  final Widget? bottomSheet;

  /// Forwarded to [Scaffold.backgroundColor].
  final Color? backgroundColor;

  /// Forwarded to [Scaffold.resizeToAvoidBottomInset].
  final bool? resizeToAvoidBottomInset;

  /// Forwarded to [Scaffold.floatingActionButtonAnimator].
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;

  /// Forwarded to [Scaffold.persistentFooterButtons].
  ///
  /// They sit above [bottomNavigationBar], as in a [Scaffold]: the two do not
  /// compete for the same slot.
  final List<Widget>? persistentFooterButtons;

  /// Forwarded to [Scaffold.persistentFooterAlignment].
  final AlignmentDirectional persistentFooterAlignment;

  /// Forwarded to [Scaffold.persistentFooterDecoration].
  final BoxDecoration? persistentFooterDecoration;

  /// Forwarded to [Scaffold.onDrawerChanged].
  final DrawerCallback? onDrawerChanged;

  /// Forwarded to [Scaffold.onEndDrawerChanged].
  final DrawerCallback? onEndDrawerChanged;

  /// Forwarded to [Scaffold.drawerDragStartBehavior].
  final DragStartBehavior drawerDragStartBehavior;

  /// Forwarded to [Scaffold.drawerScrimColor].
  final Color? drawerScrimColor;

  /// Forwarded to [Scaffold.drawerEdgeDragWidth].
  final double? drawerEdgeDragWidth;

  /// Forwarded to [Scaffold.drawerEnableOpenDragGesture].
  final bool drawerEnableOpenDragGesture;

  /// Forwarded to [Scaffold.endDrawerEnableOpenDragGesture].
  final bool endDrawerEnableOpenDragGesture;

  /// Forwarded to [Scaffold.restorationId].
  final String? restorationId;

  /// Forwarded to [Scaffold.drawerBarrierDismissible].
  final bool drawerBarrierDismissible;

  @override
  State<FoldableScaffold> createState() => _FoldableScaffoldState();
}

class _FoldableScaffoldState extends State<FoldableScaffold>
    with RestorationMixin<FoldableScaffold>
    implements FoldableScaffoldControllerDelegate {
  /// Where the divider is, as a share of the scaffold width.
  ///
  /// Restorable: with a [FoldableScaffold.restorationId] the position of the
  /// divider survives the app being killed in the background.
  final _ratioSecondaryBody = RestorableDouble(0.5);

  /// Whether the user placed the divider since the fold last changed. Until
  /// then, a flat fold decides where the divider starts. Restored too.
  final _userResized = RestorableBool(false);

  final _isHoveringDivider = ValueNotifier(false);
  final _isDraggingDivider = ValueNotifier(false);
  final _dividerFocusNode = FocusNode(debugLabel: 'FoldableScaffold divider');

  late FoldableScaffoldController _controller;
  bool _ownsController = false;

  /// What the last layout lets the divider do, for the controller and the
  /// keyboard, which act outside of the build.
  _DividerMetrics? _dividerMetrics;

  /// What the controller was last told, so a frame that changes nothing queues
  /// no callback.
  bool _hasPublished = false;
  double? _publishedSecondaryWidth;
  bool _publishedIsSplit = false;
  bool _publishedIsDragging = false;

  Axis? _publishedAxis;

  bool _wasSinglePane = false;
  bool _wasPrimaryVisible = false;
  FoldableFold? _fold;

  /// Where the pane area is in the window, as the last layout left it. Always
  /// kept up to date (it is cheap), and used only when a horizontal hinge needs
  /// it: see [_PaneAreaProbe].
  Rect? _measuredPaneRect;

  /// Whether the last build followed a horizontal separating fold, which is
  /// the only case where a new measure rebuilds the scaffold.
  bool _needsPaneRect = false;

  /// Whether the last build followed a horizontal hinge before the pane area
  /// was measured once: the panes are laid out from an estimate and not shown
  /// until the measure confirms it.
  bool _paneAreaUnmeasured = false;

  /// Whether the build that follows a new measure lays the panes out at once:
  /// it corrects a guess or a stale value, so it must not slide the panes from
  /// the old place to the right one.
  bool _snapForMeasure = false;

  /// Whether [_fold] has been read once. The first read never counts as a
  /// change, so restored data survives it.
  bool _foldKnown = false;

  double get _minWidthNavigation => widget.minWidthNavigation;
  double get _maxWidthNavigation => widget.maxWidthNavigation;
  double get _minBodySize => widget.minBodySize;
  double get _dividerSize => widget.dividerSize;
  bool get _focusOnPrimaryBody => widget.focusOnPrimaryBody;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  /// The divider data goes in a scope of its own, because the [Scaffold] below
  /// claims [FoldableScaffold.restorationId] itself.
  @override
  String? get restorationId {
    final id = widget.restorationId;
    return id == null ? null : '${id}_panes';
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_ratioSecondaryBody, 'ratio');
    registerForRestoration(_userResized, 'user_resized');
  }

  @override
  void didUpdateWidget(FoldableScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachController();
      _attachController();
    }
  }

  /// Takes [FoldableScaffold.controller], or makes one the scaffold owns.
  void _attachController() {
    final controller = widget.controller;
    _ownsController = controller == null;
    _controller = controller ?? FoldableScaffoldController();
    _controller.attach(this);
    // A new controller has heard nothing yet.
    _hasPublished = false;
  }

  /// Lets go of the controller, and disposes it when the scaffold made it.
  void _detachController() {
    _controller.detach(this);
    if (_ownsController) _controller.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Folding or unfolding the device moves the crease: start over from it.
    // The first read does not, so state restoration is not lost to it.
    // Only a vertical fold has a crease to start the divider from: a horizontal
    // hinge does not move it, so it does not make the scaffold forget where the
    // user put it.
    final fold = FoldableFold.fromFeatures(
      MediaQuery.displayFeaturesOf(context),
      MediaQuery.sizeOf(context),
      horizontal: false,
    );
    if (!_foldKnown) {
      _foldKnown = true;
      _fold = fold;
    } else if (fold != _fold) {
      _fold = fold;
      _userResized.value = false;
    }
  }

  @override
  void dispose() {
    _detachController();
    _dividerFocusNode.dispose();
    _isHoveringDivider.dispose();
    _isDraggingDivider.dispose();
    _ratioSecondaryBody.dispose();
    _userResized.dispose();
    super.dispose();
  }

  @override
  void setSecondaryWidth(double width, {required bool snap}) {
    _setSecondaryWidth(width, snap: snap, metrics: _dividerMetrics);
  }

  @override
  void resetDivider() {
    _ratioSecondaryBody.value = _dividerMetrics?.resetRatio ?? 0.5;
    _userResized.value = false;
  }

  /// Puts the divider where the secondary pane is [width] wide, as a drag
  /// would, and remembers that the user placed it.
  void _setSecondaryWidth(
    double width, {
    required bool snap,
    required _DividerMetrics? metrics,
  }) {
    if (metrics == null || !metrics.canResize) return;
    var target = width.clamp(
      metrics.minSecondarySize,
      metrics.maxSecondarySize,
    );
    if (snap) {
      final best = computeSnapTarget(
        screenWidth: metrics.scaffoldWidth,
        splitWidth: metrics.splitWidth,
        minSecondarySize: metrics.minSecondarySize,
        maxSecondarySize: metrics.maxSecondarySize,
        currentSecondarySize: target,
        snapWidths: widget.snapWidths,
        snapThreshold: widget.snapThreshold,
      );
      if (best != null) target = best;
    }
    _ratioSecondaryBody.value = target / metrics.scaffoldWidth;
    _userResized.value = true;
  }

  /// One arrow key press: [direction] is -1 towards the start of the line and
  /// 1 towards the end, and [large] is a step with Shift held.
  void _resizeSecondaryByStep({
    required int direction,
    required bool large,
    required _DividerMetrics metrics,
  }) {
    _setSecondaryWidth(
      computeKeyboardSecondarySize(
        currentSecondarySize: metrics.currentSecondarySize,
        direction: direction,
        step: widget.dividerKeyboardStep * (large ? 4 : 1),
        isRtl: metrics.isRtl,
        minSecondarySize: metrics.minSecondarySize,
        maxSecondarySize: metrics.maxSecondarySize,
      ),
      snap: false,
      metrics: metrics,
    );
  }

  /// Home or End: the divider goes to the edge of its range, and then snaps
  /// like a released drag.
  void _moveSecondaryToEdge({
    required bool toEnd,
    required _DividerMetrics metrics,
  }) {
    _setSecondaryWidth(
      toEnd ? metrics.maxSecondarySize : metrics.minSecondarySize,
      snap: true,
      metrics: metrics,
    );
  }

  /// What a screen reader does when it increases the divider: the secondary
  /// pane grows by one keyboard step, whichever side it is on.
  void _growSecondary(_DividerMetrics metrics) => _resizeSecondaryByStep(
    direction: metrics.isRtl ? 1 : -1,
    large: false,
    metrics: metrics,
  );

  /// What a screen reader does when it decreases the divider.
  void _shrinkSecondary(_DividerMetrics metrics) => _resizeSecondaryByStep(
    direction: metrics.isRtl ? -1 : 1,
    large: false,
    metrics: metrics,
  );

  Widget _body() {
    return LayoutBuilder(
      key: const Key('body_builder'),
      builder: (context, constraints) =>
          widget.bodyBuilder?.call(context, constraints) ??
          widget.body ??
          const SizedBox.shrink(),
    );
  }

  Widget _secondaryBody() {
    return LayoutBuilder(
      key: const Key('secondary_body_builder'),
      builder: (context, constraints) =>
          widget.secondaryBodyBuilder?.call(context, constraints) ??
          widget.secondaryBody ??
          const SizedBox.shrink(),
    );
  }

  /// The app bar, from [FoldableScaffold.appBarBuilder] or
  /// [FoldableScaffold.appBar].
  PreferredSizeWidget? _appBar(BuildContext context, double scaffoldWidth) {
    return widget.appBarBuilder?.call(
          context,
          BoxConstraints(maxWidth: scaffoldWidth, maxHeight: kToolbarHeight),
        ) ??
        widget.appBar;
  }

  /// The bottom navigation, from
  /// [FoldableScaffold.bottomNavigationBarBuilder] or
  /// [FoldableScaffold.bottomNavigationBar].
  Widget _bottomNavigationBar(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    return widget.bottomNavigationBarBuilder?.call(context, constraints) ??
        widget.bottomNavigationBar ??
        const SizedBox.shrink();
  }

  /// Whether the user passed a bottom navigation, whichever way.
  bool get _hasBottomNavigation =>
      widget.bottomNavigationBar != null ||
      widget.bottomNavigationBarBuilder != null;

  /// Whether there is a navigation to show on [edge] (a physical one).
  bool _hasNavigationOn(FoldableNavigationEdge edge) {
    if (edge == FoldableNavigationEdge.none) return false;
    if (widget.navigationBuilder != null) return true;
    return edge.isSide ? _hasPrimaryNavigation : _hasBottomNavigation;
  }

  /// The navigation for [placement]: [FoldableScaffold.navigationBuilder], or
  /// the slot that goes with the edge.
  Widget _navigationFor(
    BuildContext context,
    FoldableNavigationPlacement placement,
    BoxConstraints constraints,
    EdgeInsets padding,
  ) {
    final builder = widget.navigationBuilder;
    if (builder != null) {
      return builder(context, placement, constraints, padding) ??
          const SizedBox.shrink();
    }
    if (placement.isSide) {
      return widget.primaryNavigationBuilder?.call(
            context,
            constraints,
            padding,
          ) ??
          widget.primaryNavigation ??
          const SizedBox.shrink();
    }
    return _bottomNavigationBar(context, constraints);
  }

  /// What the placement resolver decides on.
  FoldableLayoutInfo _layoutInfo({
    required BuildContext context,
    required Size scaffoldSize,
    required Size windowSize,
    required FoldableBreakpoints breakpoints,
    required TextDirection textDirection,
    required EdgeInsets padding,
    required List<DisplayFeature> displayFeatures,
  }) {
    return FoldableLayoutInfo(
      scaffoldSize: scaffoldSize,
      windowSize: windowSize,
      platform: Theme.of(context).platform,
      textDirection: textDirection,
      padding: padding,
      breakpoints: breakpoints,
      fold: resolveFold(
        scaffoldWidth: scaffoldSize.width,
        scaffoldHeight: scaffoldSize.height,
        windowSize: windowSize,
        displayFeatures: displayFeatures,
        followFold: widget.followFold,
      ),
      hasSecondaryBody: _hasSecondaryBody,
      verticalBarEdge: FoldableVerticalBarScope.maybeOf(context),
      minWidthNavigation: _minWidthNavigation,
      maxWidthNavigation: _maxWidthNavigation,
    );
  }

  /// Whether the user passed a primary navigation, whichever way.
  bool get _hasPrimaryNavigation =>
      widget.primaryNavigation != null ||
      widget.primaryNavigationBuilder != null;

  /// Whether there is a secondary body to show.
  ///
  /// An explicit [FoldableScaffold.hasSecondaryBody] turns the pane on or off;
  /// without it, passing a secondary body is enough. The builder is not called
  /// to find out.
  bool get _hasSecondaryBody =>
      (widget.secondaryBody != null || widget.secondaryBodyBuilder != null) &&
      (widget.hasSecondaryBody ?? true);

  /// Where the pane area is in the window, when a horizontal separating fold
  /// needs it to put the panes around the fold; null otherwise.
  ///
  /// The app bar, the navigation above the panes and the system insets are the
  /// user's widgets, so only a measure after layout ([_PaneAreaProbe]) knows
  /// where the pane area starts, and so where the fold is *inside* it. The
  /// measure of the last frame is used, which follows a change of pose without
  /// delay: the pane area does not depend on the fold. Before there is any
  /// measure (the first frame of the app) the scaffold lays the panes out from
  /// an estimate (below the app bar, nothing else above or under the panes)
  /// and keeps them invisible for that one frame, so a wrong guess is never
  /// seen; the measure of that frame then replaces it.
  Rect? _paneAreaRectFor({
    required BuildContext context,
    required double scaffoldWidth,
    required double scaffoldHeight,
    required Size windowSize,
    required EdgeInsets padding,
    required List<DisplayFeature> displayFeatures,
  }) {
    final fold = resolveFold(
      scaffoldWidth: scaffoldWidth,
      scaffoldHeight: scaffoldHeight,
      windowSize: windowSize,
      displayFeatures: displayFeatures,
      followFold: widget.followFold,
    );
    _needsPaneRect = fold != null && fold.isHorizontal && fold.isSeparating;
    final measured = _measuredPaneRect;
    _paneAreaUnmeasured = _needsPaneRect && measured == null;
    if (!_needsPaneRect) return null;
    if (measured != null) return measured;

    final appBar = _appBar(context, scaffoldWidth);
    final top = appBar == null
        ? 0.0
        : AppBar.preferredHeightFor(context, appBar.preferredSize) +
              (widget.primary ? padding.top : 0.0);
    return Rect.fromLTRB(0, top, scaffoldWidth, scaffoldHeight);
  }

  /// The [_PaneAreaProbe] saw the pane area somewhere new.
  void _paneAreaMeasured(Rect rect) {
    if (_measuredPaneRect == rect) return;
    _measuredPaneRect = rect;
    if (!mounted || !_needsPaneRect) return;
    _snapForMeasure = true;
    setState(() {});
    // The panes are laid out in the frame this asks for: it is over after that.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _snapForMeasure = false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final paneAnimationDuration = FoldableMotion.of(
      context,
      widget.paneAnimationDuration,
    );

    final breakpoints =
        widget.breakpoints ??
        FoldableBreakpoints.forPlatform(Theme.of(context).platform);
    // The window, not the scaffold, tells a phone held sideways (wide but
    // short) from a foldable or a tablet.
    final windowSize = MediaQuery.sizeOf(context);
    final displayFeatures = MediaQuery.displayFeaturesOf(context);

    return LayoutBuilder(
      builder: (context, scaffoldConstraints) {
        final padding = MediaQuery.paddingOf(context);
        final textDirection =
            Directionality.maybeOf(context) ?? TextDirection.ltr;
        // Where the navigation goes comes first: it decides how much room is
        // left for the panes, so it cannot depend on them.
        final placement =
            (widget.navigationPlacement ?? defaultNavigationPlacement)(
              _layoutInfo(
                context: context,
                scaffoldSize: scaffoldConstraints.biggest,
                windowSize: windowSize,
                breakpoints: breakpoints,
                textDirection: textDirection,
                padding: padding,
                displayFeatures: displayFeatures,
              ),
            );
        final scaffoldHeight = scaffoldConstraints.maxHeight;
        final paneAreaRect = _paneAreaRectFor(
          context: context,
          scaffoldWidth: scaffoldConstraints.maxWidth,
          scaffoldHeight: scaffoldHeight,
          windowSize: windowSize,
          padding: padding,
          displayFeatures: displayFeatures,
        );
        final frame = computeFrameGeometry(
          scaffoldWidth: scaffoldConstraints.maxWidth,
          scaffoldHeight: scaffoldHeight,
          paneAreaRect: paneAreaRect,
          windowSize: windowSize,
          breakpoints: breakpoints,
          textDirection: textDirection,
          padding: padding,
          displayFeatures: displayFeatures,
          followFold: widget.followFold,
          minBodySize: _minBodySize,
          dividerSize: _dividerSize,
          placement: placement,
          minWidthNavigation: _minWidthNavigation,
          maxWidthNavigation: _maxWidthNavigation,
          hasNavigation: _hasNavigationOn(
            placement.edge.resolve(textDirection),
          ),
          hasSecondaryBody: _hasSecondaryBody,
        );

        return PopScope(
          canPop: !frame.hasSecondaryBody,
          onPopInvokedWithResult: widget.onSecondBodyClose,
          child: FoldableScaffoldControllerScope(
            controller: _controller,
            child: FoldableScaffoldScope(
              canSplit: frame.canSplit,
              child: _buildScaffold(
                context: context,
                frame: frame,
                padding: padding,
                paneAnimationDuration: paneAnimationDuration,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScaffold({
    required BuildContext context,
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    return Scaffold(
      primary: widget.primary,
      extendBody: widget.extendBody,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      floatingActionButton: widget.floatingActionButton,
      floatingActionButtonLocation: widget.floatingActionButtonLocation,
      drawer: widget.drawer,
      endDrawer: widget.endDrawer,
      bottomSheet: widget.bottomSheet,
      backgroundColor: widget.backgroundColor,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      floatingActionButtonAnimator: widget.floatingActionButtonAnimator,
      persistentFooterButtons: widget.persistentFooterButtons,
      persistentFooterAlignment: widget.persistentFooterAlignment,
      persistentFooterDecoration: widget.persistentFooterDecoration,
      onDrawerChanged: widget.onDrawerChanged,
      onEndDrawerChanged: widget.onEndDrawerChanged,
      drawerDragStartBehavior: widget.drawerDragStartBehavior,
      drawerScrimColor: widget.drawerScrimColor,
      drawerEdgeDragWidth: widget.drawerEdgeDragWidth,
      drawerEnableOpenDragGesture: widget.drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: widget.endDrawerEnableOpenDragGesture,
      restorationId: widget.restorationId,
      drawerBarrierDismissible: widget.drawerBarrierDismissible,
      appBar: _appBar(context, frame.scaffoldWidth),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopNavigation(
            frame: frame,
            padding: padding,
            paneAnimationDuration: paneAnimationDuration,
          ),
          Expanded(
            child: _buildBodyRow(
              context: context,
              frame: frame,
              padding: padding,
              paneAnimationDuration: paneAnimationDuration,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(
        frame: frame,
        padding: padding,
        paneAnimationDuration: paneAnimationDuration,
      ),
    );
  }

  Widget _buildBodyRow({
    required BuildContext context,
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    // Physical order: the navigation is on the left or the right of the panes
    // whatever the text direction. Which side is the placement's business.
    return Row(
      textDirection: TextDirection.ltr,
      children: [
        _buildSideNavigation(
          edge: FoldableNavigationEdge.left,
          frame: frame,
          padding: padding,
          paneAnimationDuration: paneAnimationDuration,
        ),
        Expanded(
          child: _PaneAreaProbe(
            onMeasured: _paneAreaMeasured,
            child: LayoutBuilder(
              builder: (innerContext, constraints) {
                return _buildPanes(
                  context: innerContext,
                  constraints: constraints,
                  frame: frame,
                  padding: padding,
                  paneAnimationDuration: paneAnimationDuration,
                );
              },
            ),
          ),
        ),
        _buildSideNavigation(
          edge: FoldableNavigationEdge.right,
          frame: frame,
          padding: padding,
          paneAnimationDuration: paneAnimationDuration,
        ),
      ],
    );
  }

  /// The slot of the navigation on the physical [edge], [FoldableNavigationEdge.left]
  /// or [FoldableNavigationEdge.right]: as wide as the placement says when the
  /// navigation is on that edge, zero otherwise. Both slots are always in the
  /// tree, so the panes keep their state when the navigation changes sides.
  Widget _buildSideNavigation({
    required FoldableNavigationEdge edge,
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    final active = frame.navigationEdge == edge;
    // One slot carries the key, so a test or a driver finds the navigation in
    // the same place whichever side it is on.
    final keyed = edge == FoldableNavigationEdge.right
        ? frame.navigationEdge == FoldableNavigationEdge.right
        : frame.navigationEdge != FoldableNavigationEdge.right;
    const key = Key('primary_navigation_builder');
    // A slot that is shrinking because the navigation moved away still shows
    // it, as a side navigation of its own edge, until it is gone.
    final placement = active
        ? frame.placement
        : FoldableNavigationPlacement(edge);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: active ? frame.navigationWidth : 0.0),
      duration: paneAnimationDuration,
      curve: Curves.fastOutSlowIn,
      builder: (context, animatedWidth, _) {
        if (animatedWidth == 0 || !_hasNavigationOn(edge)) {
          return SizedBox.shrink(key: keyed ? key : null);
        }

        return SizedBox(
          width: animatedWidth,
          child: LayoutBuilder(
            key: keyed ? key : null,
            builder: (context, constraints) =>
                _navigationFor(context, placement, constraints, padding),
          ),
        );
      },
    );
  }

  /// The navigation above the panes, under the app bar, when the placement
  /// says so. [Scaffold] has no slot for it, so it is the first thing in the
  /// body.
  Widget _buildTopNavigation({
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    final shown =
        frame.navigationEdge == FoldableNavigationEdge.top &&
        _hasNavigationOn(FoldableNavigationEdge.top);
    return AnimatedSize(
      duration: paneAnimationDuration,
      curve: Curves.fastOutSlowIn,
      alignment: Alignment.topCenter,
      child: shown
          ? LayoutBuilder(
              key: const Key('top_navigation_builder'),
              builder: (context, constraints) => _navigationFor(
                context,
                frame.placement,
                constraints,
                padding,
              ),
            )
          : const SizedBox.shrink(key: Key('top_navigation_hidden')),
    );
  }

  /// The navigation below the panes, given to [Scaffold.bottomNavigationBar] so
  /// the floating action button, `extendBody` and the insets work as usual.
  Widget _buildBottomNavigationBar({
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    return AnimatedSwitcher(
      duration: paneAnimationDuration,
      switchInCurve: Curves.fastOutSlowIn,
      child: frame.navigationEdge != FoldableNavigationEdge.bottom
          ? const SizedBox.shrink(key: Key('bottom_navigation_hidden'))
          : LayoutBuilder(
              key: const Key('bottom_navigation_builder'),
              builder: (context, constraints) => _navigationFor(
                context,
                frame.placement,
                constraints,
                padding,
              ),
            ),
    );
  }

  Widget _buildPanes({
    required BuildContext context,
    required BoxConstraints constraints,
    required FrameGeometry frame,
    required EdgeInsets padding,
    required Duration paneAnimationDuration,
  }) {
    final totalWidth = constraints.maxWidth;
    // Side by side, the panes share the width; stacked around a horizontal
    // hinge they share the height.
    final axis = frame.paneAxis;
    final totalExtent = axis == Axis.horizontal
        ? constraints.maxWidth
        : constraints.maxHeight;
    final canSplitPanel = frame.canSplit && frame.hasSecondaryBody;

    // The panes share the width left by the navigation and the divider. Each
    // keeps at least minBodySize, or half of that width when it cannot hold two
    // of them.
    final splitWidth = (totalWidth - _dividerSize).clamp(0.0, double.infinity);
    final minPaneSize = _minBodySize < splitWidth / 2
        ? _minBodySize
        : splitWidth / 2;
    final minSecondarySize = minPaneSize;
    final maxSecondarySize = splitWidth - minPaneSize;

    // The panes see what the Scaffold made of the window for its body: the app
    // bar took the top inset, the keyboard resized the body, and with extendBody
    // the bottom padding is the height of the bottom bar.
    final bodyMedia = MediaQuery.of(context);
    // The Scaffold takes the bottom inset away from its body as soon as it has
    // a bottom bar, even a hidden one, and gives it back as the bar's height
    // (extendBody). With no bar on screen the inset is the system's.
    final hasBottomBar =
        frame.navigationEdge == FoldableNavigationEdge.bottom &&
        _hasNavigationOn(FoldableNavigationEdge.bottom);
    final hasTopBar =
        frame.navigationEdge == FoldableNavigationEdge.top &&
        _hasNavigationOn(FoldableNavigationEdge.top);

    final paneMedia = bodyMedia.copyWith(
      padding: bodyMedia.padding.copyWith(
        // A navigation beside the panes already took the inset on its side
        // of the window, and one above them the top one.
        left:
            frame.navigationWidth > 0 &&
                frame.navigationEdge == FoldableNavigationEdge.left
            ? 0
            : null,
        right:
            frame.navigationWidth > 0 &&
                frame.navigationEdge == FoldableNavigationEdge.right
            ? 0
            : null,
        top: hasTopBar ? 0 : null,
        bottom: hasBottomBar ? null : padding.bottom,
      ),
    );

    return MediaQuery(
      data: paneMedia,
      child: ListenableBuilder(
        listenable: Listenable.merge([_ratioSecondaryBody, _isDraggingDivider]),
        builder: (context, _) {
          final ratioSecondaryBody =
              _userResized.value || frame.foldSecondaryRatio == null
              ? _ratioSecondaryBody.value
              : frame.foldSecondaryRatio!;

          final paneLayout = computePaneLayout(
            axis: axis,
            totalExtent: totalExtent,
            scaffoldExtent: frame.scaffoldWidth,
            ratioSecondaryBody: ratioSecondaryBody,
            canSplitPanel: canSplitPanel,
            splitsAtFold: frame.splitsAtFold,
            foldStart: frame.foldStart,
            foldEnd: frame.foldEnd,
            isRtl: frame.isRtl,
            minBodySize: _minBodySize,
            dividerSize: _dividerSize,
            minSecondarySize: minSecondarySize,
            maxSecondarySize: maxSecondarySize,
            focusOnPrimaryBody: _focusOnPrimaryBody,
            hasSecondaryBody: frame.hasSecondaryBody,
            isHoveringDivider: _isDraggingDivider.value,
          );

          // Switching the one visible pane is instant so only the page slide is
          // seen: while pages slide, and when a single-pane layout switches
          // panes on its own (a cancelled swipe back).
          final snapPanes =
              paneLayout.isSinglePane &&
              _wasSinglePane &&
              (_isTransitioning(context) ||
                  paneLayout.primaryVisible != _wasPrimaryVisible);
          _wasSinglePane = paneLayout.isSinglePane;
          _wasPrimaryVisible = paneLayout.primaryVisible;

          final metrics = _DividerMetrics(
            scaffoldWidth: frame.scaffoldWidth,
            splitWidth: splitWidth,
            minSecondarySize: minSecondarySize,
            maxSecondarySize: maxSecondarySize,
            currentSecondarySize: (ratioSecondaryBody * frame.scaffoldWidth)
                .clamp(minSecondarySize, maxSecondarySize),
            resetRatio: frame.foldSecondaryRatio ?? 0.5,
            isRtl: frame.isRtl,
            canResize: canSplitPanel && !frame.splitsAtFold,
          );
          _publishToController(paneLayout, metrics, totalWidth);

          return TweenAnimationBuilder<PaneGeometry>(
            tween: PaneGeometryTween(end: paneLayout.geometry),
            duration: _isDraggingDivider.value || snapPanes || _snapForMeasure
                ? Duration.zero
                : paneAnimationDuration,
            curve: Curves.fastOutSlowIn,
            builder: (context, geometry, _) {
              return _buildPanesContent(
                geometry: geometry,
                paneLayout: paneLayout,
                frame: frame,
                constraints: constraints,
                currentRatio: ratioSecondaryBody,
                splitWidth: splitWidth,
                minSecondarySize: minSecondarySize,
                maxSecondarySize: maxSecondarySize,
                metrics: metrics,
                paneMedia: paneMedia,
              );
            },
          );
        },
      ),
    );
  }

  /// Tells [FoldableScaffold.controller] what the panes are after the frame,
  /// so one of its listeners may `setState` without being in a build, and
  /// keeps [_dividerMetrics] up to date for the controller and the keyboard.
  ///
  /// Nothing is queued when the frame changed none of it.
  void _publishToController(
    PaneLayout paneLayout,
    _DividerMetrics metrics,
    double paneAreaWidth,
  ) {
    final geometry = paneLayout.geometry;
    final isSplit = paneLayout.primaryVisible && paneLayout.secondaryVisible;
    // Stacked, the secondary pane is as wide as the pane area.
    final width = !isSplit
        ? null
        : geometry.axis == Axis.horizontal
        ? geometry.secondaryExtent
        : paneAreaWidth;
    final axis = isSplit ? geometry.axis : null;
    final isDragging = _isDraggingDivider.value;
    if (_hasPublished &&
        _publishedSecondaryWidth == width &&
        _publishedIsSplit == isSplit &&
        _publishedAxis == axis &&
        _publishedIsDragging == isDragging &&
        _dividerMetrics == metrics) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dividerMetrics = metrics;
      _hasPublished = true;
      _publishedSecondaryWidth = width;
      _publishedIsSplit = isSplit;
      _publishedAxis = axis;
      _publishedIsDragging = isDragging;
      _controller.update(
        secondaryWidth: width,
        isSplit: isSplit,
        isDragging: isDragging,
        axis: axis,
      );
    });
  }

  Widget _buildPanesContent({
    required PaneGeometry geometry,
    required PaneLayout paneLayout,
    required FrameGeometry frame,
    required BoxConstraints constraints,
    required double currentRatio,
    required double splitWidth,
    required double minSecondarySize,
    required double maxSecondarySize,
    required _DividerMetrics metrics,
    required MediaQueryData paneMedia,
  }) {
    final canSplitPanel = frame.canSplit && frame.hasSecondaryBody;
    // Stacked, the hinge is between the panes: the one above has no system
    // inset below it, and the one below none above it.
    final stacked =
        geometry.axis == Axis.vertical &&
        geometry.primaryVisible &&
        geometry.secondaryVisible;

    final panes = CustomMultiChildLayout(
      delegate: FoldablePaneLayoutDelegate(
        geometry: geometry,
        textDirection: frame.textDirection,
      ),
      children: [
        LayoutId(
          id: PaneSlot.primary,
          child: _buildPane(
            child: _body(),
            hidden: !geometry.primaryVisible,
            media: stacked
                ? paneMedia.copyWith(
                    padding: paneMedia.padding.copyWith(bottom: 0),
                  )
                : paneMedia,
          ),
        ),
        LayoutId(
          id: PaneSlot.divider,
          // The handle is the only part of the panes that follows the hover
          // and the focus of the divider, so nothing else rebuilds for them.
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _isHoveringDivider,
              _isDraggingDivider,
              _dividerFocusNode,
            ]),
            builder: (context, _) => _buildDivider(
              metrics: metrics,
              constraints: constraints,
              paneLayout: paneLayout,
              frame: frame,
              currentRatio: currentRatio,
              splitWidth: splitWidth,
              minSecondarySize: minSecondarySize,
              maxSecondarySize: maxSecondarySize,
              canSplitPanel: canSplitPanel,
            ),
          ),
        ),
        LayoutId(
          id: PaneSlot.secondary,
          child: _buildPane(
            child: _secondaryBody(),
            hidden: !geometry.secondaryVisible,
            media: stacked
                ? paneMedia.copyWith(
                    padding: paneMedia.padding.copyWith(top: 0),
                  )
                : paneMedia,
          ),
        ),
      ],
    );
    return FoldablePaneLayout(
      primaryVisible: paneLayout.primaryVisible,
      secondaryVisible: paneLayout.secondaryVisible,
      axis: paneLayout.geometry.axis,
      // Keep sliding pages off the navigation rail. The opacity is there all
      // the time, so the panes keep their state when it changes: it is zero
      // only for the one frame before a horizontal hinge has been measured.
      child: Opacity(
        opacity: _paneAreaUnmeasured ? 0.0 : 1.0,
        alwaysIncludeSemantics: true,
        child: ClipRect(child: panes),
      ),
    );
  }

  /// The divider: the handle the user drags, or the empty gap of a fold.
  Widget _buildDivider({
    required _DividerMetrics metrics,
    required BoxConstraints constraints,
    required PaneLayout paneLayout,
    required FrameGeometry frame,
    required double currentRatio,
    required double splitWidth,
    required double minSecondarySize,
    required double maxSecondarySize,
    required bool canSplitPanel,
  }) {
    final atFold = canSplitPanel && frame.splitsAtFold;

    final geometry = paneLayout.geometry;
    final semantics = _dividerSemantics(
      geometry: geometry,
      splitWidth: splitWidth,
      minSecondarySize: minSecondarySize,
      maxSecondarySize: maxSecondarySize,
      isRtl: frame.isRtl,
    );

    return PaneDivider(
      constraints: constraints,
      dividerSize: _dividerSize,
      atFold: atFold,
      visible: geometry.dividerExtent > 0,
      isHovering: _isHoveringDivider.value,
      isDragging: _isDraggingDivider.value,
      isFocused: _dividerFocusNode.hasFocus,
      textDirection: frame.textDirection,
      theme: widget.theme,
      dividerBuilder: widget.dividerBuilder,
      semanticLabel: widget.dividerSemanticLabel,
      semanticValue: semantics.$1,
      semanticIncreasedValue: semantics.$2,
      semanticDecreasedValue: semantics.$3,
      focusNode: _dividerFocusNode,
      onDragStart: () => _startDividerDrag(metrics, currentRatio),
      onDragUpdate: (update) => _updateDividerDrag(update, metrics),
      onDragEnd: () => _endDividerDrag(metrics),
      onHoverChanged: (hovering) => _isHoveringDivider.value = hovering,
      onKeyboardResize: (direction, {required bool large}) =>
          _resizeSecondaryByStep(
            direction: direction,
            large: large,
            metrics: metrics,
          ),
      onKeyboardEdge: ({required bool toEnd}) =>
          _moveSecondaryToEdge(toEnd: toEnd, metrics: metrics),
      onIncrease: () => _growSecondary(metrics),
      onDecrease: () => _shrinkSecondary(metrics),
    );
  }

  /// The divider starts where it is, which may be on the fold, and counts as
  /// placed by the user from now on.
  void _startDividerDrag(_DividerMetrics metrics, double currentRatio) {
    _ratioSecondaryBody.value = currentRatio;
    _userResized.value = true;
    _isDraggingDivider.value = true;
  }

  void _updateDividerDrag(DragUpdateDetails update, _DividerMetrics metrics) {
    // In RTL the secondary pane is on the left: a positive delta (pointer
    // moving right) grows it instead of shrinking it.
    final signedDelta = metrics.isRtl ? update.delta.dx : -update.delta.dx;
    // Keep the stored ratio in range, so dragging back after going past an edge
    // moves the divider right away.
    final currentSecondarySize =
        _ratioSecondaryBody.value * metrics.scaffoldWidth;
    final newSecondarySize = (currentSecondarySize + signedDelta).clamp(
      metrics.minSecondarySize,
      metrics.maxSecondarySize,
    );
    _ratioSecondaryBody.value = newSecondarySize / metrics.scaffoldWidth;
  }

  void _endDividerDrag(_DividerMetrics metrics) {
    final best = computeSnapTarget(
      screenWidth: metrics.scaffoldWidth,
      splitWidth: metrics.splitWidth,
      minSecondarySize: metrics.minSecondarySize,
      maxSecondarySize: metrics.maxSecondarySize,
      currentSecondarySize: _ratioSecondaryBody.value * metrics.scaffoldWidth,
      snapWidths: widget.snapWidths,
      snapThreshold: widget.snapThreshold,
    );
    if (best != null) {
      _ratioSecondaryBody.value = best / metrics.scaffoldWidth;
    }
    _isDraggingDivider.value = false;
  }

  /// What a screen reader reads for the divider: the share of the pane area
  /// the secondary pane takes, now and after one keyboard step each way.
  (String, String, String) _dividerSemantics({
    required PaneGeometry geometry,
    required double splitWidth,
    required double minSecondarySize,
    required double maxSecondarySize,
    required bool isRtl,
  }) {
    String percentAt(double size) =>
        '${computeSecondaryPanePercent(secondarySize: size, splitWidth: splitWidth)}%';
    double step(int direction) => computeKeyboardSecondarySize(
      currentSecondarySize: geometry.secondaryExtent,
      direction: direction,
      step: widget.dividerKeyboardStep,
      isRtl: isRtl,
      minSecondarySize: minSecondarySize,
      maxSecondarySize: maxSecondarySize,
    );
    return (
      percentAt(geometry.secondaryExtent),
      percentAt(step(isRtl ? 1 : -1)),
      percentAt(step(isRtl ? -1 : 1)),
    );
  }

  /// Wraps a pane that is [hidden] (its animated width is zero) so that,
  /// while nothing of it is visible, it does not take focus, is left out of
  /// the semantics tree, does not take pointer events and does not run
  /// tickers.
  ///
  /// The pane is never taken out of the tree: its widgets keep their state
  /// (a page stack, a scroll position, text being typed) and their
  /// constraints, so showing it again is instant and nothing jumps. The
  /// exclusion is keyed on the *animated* width: a pane that is sliding in or
  /// out still has a non-zero width and stays focusable, audible and tickable
  /// until the animation ends, so the slide of `FoldableNavigator` is never
  /// cut short.
  ///
  /// [media] is what the pane sees of the window: the same for both panes, except
  /// that stacked ones do not get a system inset on the side of the hinge. The
  /// [MediaQuery] is always there, so a pane keeps its state when the panes
  /// stack and unstack.
  Widget _buildPane({
    required Widget child,
    required bool hidden,
    required MediaQueryData media,
  }) {
    return TickerMode(
      enabled: !hidden,
      child: IgnorePointer(
        ignoring: hidden,
        child: ExcludeSemantics(
          excluding: hidden,
          child: ExcludeFocus(
            excluding: hidden,
            child: MediaQuery(data: media, child: child),
          ),
        ),
      ),
    );
  }

  /// Whether page transitions are running, from [FoldableScaffold.paneTransition]
  /// or the closest [FoldablePaneTransitionScope].
  bool _isTransitioning(BuildContext context) {
    final transition = widget.paneTransition;
    if (transition != null) return transition.value;
    return FoldablePaneTransitionScope.isTransitioningOf(context);
  }
}

/// Builds a widget with the constraints of a pane. Returning null shows an
/// empty pane.
typedef BoxConstraintsNullableWidgetBuilder =
    Widget? Function(BuildContext context, BoxConstraints constraints);

/// Builds the navigation shown at the start of the scaffold row.
typedef PrimaryNavigationBuilder =
    Widget Function(
      BuildContext context,
      BoxConstraints constraints,
      EdgeInsets padding,
    );

/// Builds a [PreferredSizeWidget] with the scaffold width.
typedef PreferredSizeBoxConstraintsWidgetBuilder =
    PreferredSizeWidget? Function(
      BuildContext context,
      BoxConstraints constraints,
    );

/// What the last layout lets the divider do: the range of the secondary pane,
/// the width it has now, and where it starts again after a reset.
class _DividerMetrics {
  const _DividerMetrics({
    required this.scaffoldWidth,
    required this.splitWidth,
    required this.minSecondarySize,
    required this.maxSecondarySize,
    required this.currentSecondarySize,
    required this.resetRatio,
    required this.isRtl,
    required this.canResize,
  });

  final double scaffoldWidth;
  final double splitWidth;
  final double minSecondarySize;
  final double maxSecondarySize;
  final double currentSecondarySize;

  /// Where [FoldableScaffoldController.resetDivider] puts the divider: the
  /// middle, or the crease of a flat fold.
  final double resetRatio;

  final bool isRtl;

  /// Whether the divider can be moved at all: two panes, and no hinge between
  /// them.
  final bool canResize;

  @override
  bool operator ==(Object other) =>
      other is _DividerMetrics &&
      other.scaffoldWidth == scaffoldWidth &&
      other.splitWidth == splitWidth &&
      other.minSecondarySize == minSecondarySize &&
      other.maxSecondarySize == maxSecondarySize &&
      other.currentSecondarySize == currentSecondarySize &&
      other.resetRatio == resetRatio &&
      other.isRtl == isRtl &&
      other.canResize == canResize;

  @override
  int get hashCode => Object.hash(
    scaffoldWidth,
    splitWidth,
    minSecondarySize,
    maxSecondarySize,
    currentSecondarySize,
    resetRatio,
    isRtl,
    canResize,
  );
}

/// Reports where its child is in the window, after layout.
///
/// The pane area of the [FoldableScaffold] starts below the app bar and the
/// navigation above the panes, whose heights are up to the user's widgets, so
/// the only way to put a horizontal hinge (in window coordinates) inside it is
/// to measure. The probe compares its rect in the window with the last one it
/// reported, when it paints, and calls [onMeasured] after the frame when it
/// differs: nothing is reported (and nothing rebuilds) for a frame that moves
/// nothing, so there is no loop.
class _PaneAreaProbe extends SingleChildRenderObjectWidget {
  const _PaneAreaProbe({required this.onMeasured, required super.child});

  final ValueChanged<Rect> onMeasured;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPaneAreaProbe(onMeasured);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPaneAreaProbe renderObject,
  ) {
    renderObject.onMeasured = onMeasured;
  }
}

class _RenderPaneAreaProbe extends RenderProxyBox {
  _RenderPaneAreaProbe(this.onMeasured);

  ValueChanged<Rect> onMeasured;

  Rect? _reported;
  bool _scheduled = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final rect = localToGlobal(Offset.zero) & size;
    if (rect == _reported || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached) return;
      // The rect may have moved again since it was painted: ask once more.
      final current = localToGlobal(Offset.zero) & size;
      _reported = current;
      onMeasured(current);
    });
  }
}
